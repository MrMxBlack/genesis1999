// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev The NFT contract exposes per-tier balances for mining weight.
interface INft1999 {
    function tierBalances(address account, uint8 tier) external view returns (uint256);
}

/// @title Mining1999 — Bitcoin-style token mining for NFT + token holders.
/// @notice The 34.5% mining bucket (34,496,550 tokens) is emitted at a fixed
///   rate that halves every epoch. Each miner's share of the emission is
///   their weight / total weight of all miners — the more miners join, the
///   smaller each slice (exactly the model the owner asked for).
///   Weight = free base power 1
///          + sum over tiers of (NFTs held x tier power 3/5/7/12)
///          + USD value of tokens held / usdPerPower (added last).
///   Promoters who share the project get a temporary % boost to their weight
///   (set by the owner after verifying their post link).
/// @dev Holdings-based mining cannot observe balance changes by itself, so a
///   miner's weight is (re)registered whenever they interact (poke / claim)
///   and applies from that moment on. The project website calls poke() when a
///   wallet connects, so in practice weights stay current.
contract Mining1999 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant SCALE = 1e18;

    IERC20 public immutable token;
    INft1999 public immutable nft;

    /// @notice Mining power per NFT by tier, as set by the project owner:
    ///         Common 3, Rare 5, Epic 7, Legendary 12 (free tier = 1).
    uint256[4] public ladder = [3, 5, 7, 12];
    /// @notice Weight per ladder point from NFTs. Kept at 1 so the ladder
    ///         reads directly as mining power. Tunable before start.
    uint256 public nftPointWeight = 1;
    /// @notice USD value of held tokens (x1e8) that buys 1 mining power.
    ///         Default $0.40 — above every NFT tier's price-per-power
    ///         (Rare $0.14, Epic ~$0.29, Legendary ~$0.33), so matching an
    ///         NFT's power by holding tokens costs more than the NFT.
    ///         Tunable before start.
    uint256 public usdPerPower = 40_000_000;
    /// @notice Reference price of one whole G1999 in USD (x1e8), set by the
    ///         owner — no market price exists until the liquidity pool does.
    ///         While 0, held tokens add no power. The owner may update it at
    ///         any time: it tracks an external price, it is not a rule.
    uint256 public tokenPriceUsd = 0;
    /// @notice Free mining power granted to every miner, even with no NFTs
    ///         or tokens: power 1 (a Common NFT is 3, a Legendary 12).
    ///         Tunable before start.
    uint256 public baseWeight = 1;

    // ---- emission schedule ----
    bool public started;
    uint256 public startTime;
    uint256 public epochLength = 180 days;
    /// @notice Emission in token-wei per second during epoch 0; halves each epoch.
    ///         Default ~= 1.109 tokens/sec, so all epochs together emit ~the pool.
    uint256 public initialRate = 1_109_000_000_000_000_000;
    uint256 public poolBudget; // captured at start: token balance of this contract
    uint256 public totalAccrued; // cumulative emission accounted so far
    uint256 public lastUpdate;
    uint256 public accPerWeight; // cumulative reward per weight unit, x SCALE
    uint256 public totalWeight;

    struct Boost {
        uint16 bps; // e.g. 1000 = +10%
        uint64 expiry;
    }

    mapping(address => Boost) public boosts;
    mapping(address => uint256) public storedWeight;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public owed;

    event BoostSet(address indexed user, uint16 bps, uint64 expiry);
    event Poked(address indexed user, uint256 weight);
    event Claimed(address indexed user, uint256 amount);
    event MiningStarted(uint256 startTime, uint256 poolBudget);

    constructor(address token_, address nft_) Ownable(msg.sender) {
        require(token_ != address(0) && nft_ != address(0), "zero addr");
        token = IERC20(token_);
        nft = INft1999(nft_);
    }

    // ------------------------------------------------------------------ admin

    /// @notice One-way switch: fixes the pool budget to the tokens held here.
    function startMining() external onlyOwner {
        require(!started, "already started");
        started = true;
        startTime = block.timestamp;
        lastUpdate = block.timestamp;
        poolBudget = token.balanceOf(address(this));
        require(poolBudget > 0, "pool not funded");
        emit MiningStarted(startTime, poolBudget);
    }

    function setSchedule(uint256 epochLength_, uint256 initialRate_) external onlyOwner {
        require(!started, "locked after start");
        epochLength = epochLength_;
        initialRate = initialRate_;
    }

    function setWeights(uint256 nftPointWeight_) external onlyOwner {
        require(!started, "locked after start");
        nftPointWeight = nftPointWeight_;
    }

    function setUsdPerPower(uint256 usdPerPower_) external onlyOwner {
        require(!started, "locked after start");
        usdPerPower = usdPerPower_;
    }

    /// @notice Track the token's reference price (see tokenPriceUsd).
    function setTokenPriceUsd(uint256 tokenPriceUsd_) external onlyOwner {
        tokenPriceUsd = tokenPriceUsd_;
    }

    function setBaseWeight(uint256 baseWeight_) external onlyOwner {
        require(!started, "locked after start");
        baseWeight = baseWeight_;
    }

    /// @notice Grant a promoter's mining-power boost after verifying their share post.
    function setBoost(address user, uint16 bps, uint64 expiry) external onlyOwner {
        boosts[user] = Boost(bps, expiry);
        emit BoostSet(user, bps, expiry);
        if (started) _updateUser(user); // apply the boost from now
    }

    // ------------------------------------------------------------------ views

    /// @notice Live weight of an account: free base power + NFT + token holdings.
    function currentWeight(address user) public view returns (uint256 w) {
        w = baseWeight;
        for (uint8 t = 0; t < 4; t++) {
            uint256 c = nft.tierBalances(user, t);
            if (c > 0) w += c * ladder[t] * nftPointWeight;
        }
        if (tokenPriceUsd > 0) {
            // Token power is added last and is value-based: the USD value of
            // the whole tokens held, divided by the USD price of one power.
            uint256 wholeTokens = token.balanceOf(user) / 1e18;
            w += (wholeTokens * tokenPriceUsd) / usdPerPower;
        }
        Boost memory b = boosts[user];
        if (b.bps > 0 && block.timestamp < b.expiry) {
            w = (w * (10_000 + b.bps)) / 10_000;
        }
    }

    function epochOf(uint256 t) public view returns (uint256) {
        if (!started || t <= startTime) return 0;
        return (t - startTime) / epochLength;
    }

    function rateAt(uint256 t) public view returns (uint256) {
        if (!started) return 0;
        uint256 e = epochOf(t);
        if (e >= 128) return 0;
        return initialRate >> e;
    }

    /// @notice What claim() would pay right now (approximately, before gas).
    function pendingOf(address user) external view returns (uint256) {
        uint256 acc = _accPerWeightAt(block.timestamp);
        uint256 settled = (storedWeight[user] * acc) / SCALE;
        uint256 pending = settled > rewardDebt[user] ? settled - rewardDebt[user] : 0;
        return owed[user] + pending;
    }

    // ------------------------------------------------------------------- core

    /// @notice Register/refresh the caller's mining weight.
    function poke() external {
        require(started, "not started");
        _updateUser(msg.sender);
        emit Poked(msg.sender, storedWeight[msg.sender]);
    }

    function claim() external nonReentrant {
        require(started, "not started");
        _updateUser(msg.sender);
        uint256 amount = owed[msg.sender];
        require(amount > 0, "nothing to claim");
        owed[msg.sender] = 0;
        token.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    // --------------------------------------------------------------- internal

    function _accPerWeightAt(uint256 t) internal view returns (uint256 acc) {
        acc = accPerWeight;
        if (!started || t <= lastUpdate || totalWeight == 0) return acc;
        uint256 emitted = _emissionBetween(lastUpdate, t);
        uint256 room = poolBudget > totalAccrued ? poolBudget - totalAccrued : 0;
        if (emitted > room) emitted = room;
        if (emitted == 0) return acc;
        acc += (emitted * SCALE) / totalWeight;
    }

    function _emissionBetween(uint256 from, uint256 to) internal view returns (uint256 emitted) {
        uint256 cursor = from;
        while (cursor < to) {
            uint256 e = epochOf(cursor);
            uint256 epochEnd = startTime + (e + 1) * epochLength;
            uint256 segEnd = to < epochEnd ? to : epochEnd;
            uint256 rate = rateAt(cursor);
            if (rate == 0) break;
            emitted += rate * (segEnd - cursor);
            cursor = segEnd;
        }
    }

    function _accrue() internal {
        if (!started) return;
        uint256 t = block.timestamp;
        if (t <= lastUpdate) return;
        if (totalWeight > 0) {
            uint256 emitted = _emissionBetween(lastUpdate, t);
            uint256 room = poolBudget > totalAccrued ? poolBudget - totalAccrued : 0;
            if (emitted > room) emitted = room;
            if (emitted > 0) {
                accPerWeight += (emitted * SCALE) / totalWeight;
                totalAccrued += emitted;
            }
        } else {
            // Nobody mining: emission for this window is skipped, not banked.
            totalAccrued += 0;
        }
        lastUpdate = t;
    }

    function _updateUser(address user) internal {
        _accrue();
        uint256 old = storedWeight[user];
        uint256 settled = (old * accPerWeight) / SCALE;
        if (settled > rewardDebt[user]) {
            owed[user] += settled - rewardDebt[user];
        }
        uint256 w = currentWeight(user);
        storedWeight[user] = w;
        rewardDebt[user] = (w * accPerWeight) / SCALE;
        totalWeight = totalWeight - old + w;
    }
}
