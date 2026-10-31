// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev Minimal Chainlink price-feed interface (BNB/USD).
interface IPriceFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title Genesis1999 — the 1,999-piece AI NFT collection (BSC).
/// @notice Tiers and pools follow the agreed plan (2026-10-31):
///   Common 1,100 (all free) · Rare 450 (68 sale / 30 team / 352 free) ·
///   Epic 250 (75 sale / 25 team / 150 free) ·
///   Legendary 199 (100 sale / 15 team / 45 mining reserve / 39 free drops).
///   Free mint is a gacha: each mint draws randomly from the remaining free
///   pool, so a Legendary can drop at any time. Sale prices are USD-denominated
///   ($0.70 / $2 / $4) and paid in BNB at the live Chainlink BNB/USD rate.
/// @dev Randomness uses block data + a nonce. That is predictable enough for
///      miners to game slightly; for a small free mint it is the standard
///      zero-cost choice. Chainlink VRF is the upgrade path if the owner wants
///      provably fair draws later (it has running costs).
contract Genesis1999 is ERC721, ERC2981, Ownable, ReentrancyGuard {
    enum Tier {
        Common,
        Rare,
        Epic,
        Legendary
    }

    uint256 public constant MAX_SUPPLY = 1_999;

    /// @notice USD sale prices with 8 decimals (Chainlink precision).
    uint256 public constant PRICE_RARE_USD = 70_000_000; // $0.70
    uint256 public constant PRICE_EPIC_USD = 200_000_000; // $2.00
    uint256 public constant PRICE_LEGENDARY_USD = 400_000_000; // $4.00

    IPriceFeed public immutable bnbUsdFeed;

    uint256[4] public freeRemaining; // per tier
    uint256[4] public saleRemaining; // per tier
    uint256[4] public teamRemaining; // per tier
    uint256 public miningRemaining; // Legendary only

    mapping(uint256 => Tier) public tierOf;
    mapping(address => mapping(uint8 => uint256)) public tierBalances;
    mapping(address => uint256) public freeMintedBy;

    bool public freeMintActive;
    bool public saleActive;
    uint256 public maxFreePerWallet = 5;

    string private _baseTokenURI;
    uint256 private _nextId = 1;
    uint256 private _nonce;

    event FreeMint(address indexed to, uint256 indexed tokenId, Tier tier);
    event Purchase(address indexed buyer, uint256 indexed tokenId, Tier tier, uint256 paidWei);
    event ReserveMint(address indexed to, uint256 indexed tokenId, Tier tier, string kind);

    /// @param name_ Collection name (chosen by the owner before deployment).
    /// @param symbol_ Collection symbol.
    /// @param feed Chainlink BNB/USD feed (BSC mainnet: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE).
    /// @param royaltyReceiver Receives the 5% secondary royalty.
    constructor(
        string memory name_,
        string memory symbol_,
        address feed,
        address royaltyReceiver
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(feed != address(0), "feed=0");
        bnbUsdFeed = IPriceFeed(feed);
        _setDefaultRoyalty(royaltyReceiver == address(0) ? msg.sender : royaltyReceiver, 500); // 5%

        freeRemaining = [1_100, 352, 150, 39];
        saleRemaining = [0, 68, 75, 100];
        teamRemaining = [0, 30, 25, 15];
        miningRemaining = 45;
    }

    // ------------------------------------------------------------------ views

    function totalMinted() public view returns (uint256) {
        return _nextId - 1;
    }

    function totalFreeRemaining() public view returns (uint256 total) {
        for (uint256 i = 0; i < 4; i++) total += freeRemaining[i];
    }

    /// @notice Current BNB cost (wei) of a paid tier, from the oracle price.
    function priceInBnb(Tier tier) public view returns (uint256) {
        uint256 usd = tier == Tier.Rare
            ? PRICE_RARE_USD
            : tier == Tier.Epic
                ? PRICE_EPIC_USD
                : tier == Tier.Legendary
                    ? PRICE_LEGENDARY_USD
                    : 0;
        require(usd > 0, "tier not for sale");
        (, int256 answer,,,) = bnbUsdFeed.latestRoundData();
        require(answer > 0, "bad oracle");
        return (usd * 1e18) / uint256(answer);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(_baseTokenURI, _toString(tokenId), ".json"));
    }

    // ------------------------------------------------------------- free mint

    /// @notice Free gacha mint: draws a random tier from the remaining free pool.
    function freeMint() external nonReentrant returns (uint256 tokenId, Tier tier) {
        require(freeMintActive, "free mint closed");
        require(freeMintedBy[msg.sender] < maxFreePerWallet, "wallet cap");
        uint256 total = totalFreeRemaining();
        require(total > 0, "free pool empty");

        uint256 r = _random(total);
        uint256 acc = 0;
        tier = Tier.Common;
        for (uint256 i = 0; i < 4; i++) {
            acc += freeRemaining[i];
            if (r < acc) {
                tier = Tier(i);
                break;
            }
        }
        freeRemaining[uint8(tier)] -= 1;
        freeMintedBy[msg.sender] += 1;
        tokenId = _mintTier(msg.sender, tier);
        emit FreeMint(msg.sender, tokenId, tier);
    }

    // ------------------------------------------------------------------- sale

    /// @notice Buy one NFT of a paid tier at the USD price, paid in BNB.
    function buy(Tier tier) external payable nonReentrant returns (uint256 tokenId) {
        require(saleActive, "sale closed");
        require(tier != Tier.Common, "common is free");
        require(saleRemaining[uint8(tier)] > 0, "tier sold out");
        uint256 cost = priceInBnb(tier);
        require(msg.value >= cost, "not enough BNB");
        saleRemaining[uint8(tier)] -= 1;
        tokenId = _mintTier(msg.sender, tier);
        emit Purchase(msg.sender, tokenId, tier, cost);
        if (msg.value > cost) {
            (bool ok,) = msg.sender.call{value: msg.value - cost}("");
            require(ok, "refund failed");
        }
    }

    // --------------------------------------------------------------- reserves

    /// @notice Owner mints the team reserve (Rare 30 / Epic 25 / Legendary 15 total).
    function mintTeamReserve(address to, Tier tier) external onlyOwner returns (uint256 tokenId) {
        require(teamRemaining[uint8(tier)] > 0, "team reserve empty");
        teamRemaining[uint8(tier)] -= 1;
        tokenId = _mintTier(to, tier);
        emit ReserveMint(to, tokenId, tier, "team");
    }

    /// @notice Owner mints the Legendary mining reserve (45 total) to the mining contract.
    function mintMiningReserve(address to) external onlyOwner returns (uint256 tokenId) {
        require(miningRemaining > 0, "mining reserve empty");
        miningRemaining -= 1;
        tokenId = _mintTier(to, Tier.Legendary);
        emit ReserveMint(to, tokenId, Tier.Legendary, "mining");
    }

    // ------------------------------------------------------------------ admin

    function setFreeMintActive(bool v) external onlyOwner {
        freeMintActive = v;
    }

    function setSaleActive(bool v) external onlyOwner {
        saleActive = v;
    }

    function setMaxFreePerWallet(uint256 v) external onlyOwner {
        maxFreePerWallet = v;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    /// @notice Sale proceeds fund the token liquidity pool (see PLAN.md).
    function withdraw(address payable to) external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "empty");
        (bool ok,) = to.call{value: bal}("");
        require(ok, "withdraw failed");
    }

    // --------------------------------------------------------------- internal

    function _mintTier(address to, Tier tier) internal returns (uint256 tokenId) {
        require(_nextId <= MAX_SUPPLY, "supply out");
        tokenId = _nextId++;
        tierOf[tokenId] = tier; // set before _safeMint so _update can track balances
        _safeMint(to, tokenId);
    }

    function _random(uint256 modulo) internal returns (uint256) {
        _nonce += 1;
        bytes32 h = keccak256(
            abi.encodePacked(blockhash(block.number - 1), block.timestamp, msg.sender, _nonce, address(this))
        );
        return uint256(h) % modulo;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        address prev = super._update(to, tokenId, auth);
        if (from != to) {
            uint8 t = uint8(tierOf[tokenId]);
            if (from != address(0)) tierBalances[from][t] -= 1;
            if (to != address(0)) tierBalances[to][t] += 1;
        }
        return prev;
    }

    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 digits;
        uint256 tmp = v;
        while (tmp > 0) {
            digits++;
            tmp /= 10;
        }
        bytes memory b = new bytes(digits);
        while (v > 0) {
            b[--digits] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(b);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
