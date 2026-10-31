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
///   Sale prices are USD-denominated ($0.70 / $2 / $4) and paid in BNB at the
///   live Chainlink BNB/USD rate.
/// @dev v4 — queue-bound minting. Each tokenId's tier is FIXED by its
///      metadata (deploy/queues.json, generated from metadata/*.json), so the
///      contract never draws a tier: it draws a tokenId from a per-bucket
///      queue, and the id's tier is read from a packed tier table. That makes
///      tierOf(id) identical to the art/metadata tier for every id, minted or
///      not. Free mint draws uniformly from the remaining free ids, so the
///      tier odds match the v3 gacha proportions exactly (a Legendary drop is
///      39-in-1,641 at launch). The v3 contract (contracts/Genesis1999.v3.sol)
///      drew a tier at mint time and assigned the next sequential id, which
///      would have mismatched the fixed metadata tiers.
///      Randomness uses block data + a nonce (same as v3). That is
///      predictable enough for miners to game slightly; for a small free
///      mint it is the standard zero-cost choice. Chainlink VRF is the
///      upgrade path if the owner wants provably fair draws later.
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

    // ------------------------------------------------------- queue layout
    // Mint queues, concatenated in this fixed order inside one packed blob.
    // Queue indices double as tier indices for the sale queues.
    uint8 private constant Q_FREE = 0;
    uint8 private constant Q_SALE_RARE = 1; // == uint8(Tier.Rare)
    uint8 private constant Q_SALE_EPIC = 2; // == uint8(Tier.Epic)
    uint8 private constant Q_SALE_LEGENDARY = 3; // == uint8(Tier.Legendary)
    uint8 private constant Q_TEAM_RARE = 4; // team queue = tier + 3
    uint8 private constant Q_MINING = 7;

    uint256 private constant ID_BITS = 11; // tokenIds 1..1999 fit in 11 bits
    uint256 private constant QUEUES_BYTES = 2749; // ceil(1999 * 11 / 8)
    uint256 private constant TIERS_BYTES = 500; // ceil(1999 * 2 / 8)

    IPriceFeed public immutable bnbUsdFeed;

    /// @dev All 1,999 tokenIds, 11 bits each, LSB-first, queues concatenated
    ///      in the order above. Draws swap-and-pop inside each queue's slice.
    bytes private _queueData;
    /// @dev Tier of every tokenId, 2 bits each, LSB-first, in id order.
    bytes private _tierBits;
    /// @dev Remaining length of each queue, 11 bits per queue, packed.
    uint256 private _queueLengths;
    /// @dev Per-tier count of ids still sitting in the free queue.
    uint256[4] private _freeLeft;

    mapping(address => mapping(uint8 => uint256)) public tierBalances;
    mapping(address => uint256) public freeMintedBy;

    bool public freeMintActive;
    bool public saleActive;
    uint256 public maxFreePerWallet = 5;

    string private _baseTokenURI;
    uint256 private _totalMinted;
    uint256 private _nonce;

    event FreeMint(address indexed to, uint256 indexed tokenId, Tier tier);
    event Purchase(address indexed buyer, uint256 indexed tokenId, Tier tier, uint256 paidWei);
    event ReserveMint(address indexed to, uint256 indexed tokenId, Tier tier, string kind);

    /// @param name_ Collection name (chosen by the owner before deployment).
    /// @param symbol_ Collection symbol.
    /// @param feed Chainlink BNB/USD feed (BSC mainnet: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE).
    /// @param royaltyReceiver Receives the 5% secondary royalty.
    /// @param queuesPacked The 8 mint queues from deploy/queues.json, tokenIds
    ///        packed at 11 bits each (LSB-first), concatenated in queue order
    ///        [free, saleRare, saleEpic, saleLegendary, teamRare, teamEpic,
    ///        teamLegendary, mining]. Exactly QUEUES_BYTES long.
    /// @param tiersPacked Tier index (0..3) of every tokenId in id order,
    ///        packed at 2 bits each (LSB-first). Exactly TIERS_BYTES long.
    constructor(
        string memory name_,
        string memory symbol_,
        address feed,
        address royaltyReceiver,
        bytes memory queuesPacked,
        bytes memory tiersPacked
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(feed != address(0), "feed=0");
        bnbUsdFeed = IPriceFeed(feed);
        _setDefaultRoyalty(royaltyReceiver == address(0) ? msg.sender : royaltyReceiver, 500); // 5%

        require(queuesPacked.length == QUEUES_BYTES, "bad queues length");
        require(tiersPacked.length == TIERS_BYTES, "bad tiers length");
        _queueData = queuesPacked;
        _tierBits = tiersPacked;

        // Initial queue lengths: free 1641 · sale 68/75/100 · team 30/25/15 · mining 45.
        uint256[8] memory sizes = [uint256(1641), 68, 75, 100, 30, 25, 15, 45];
        uint256 lengths;
        for (uint256 q = 0; q < 8; q++) {
            lengths |= sizes[q] << (ID_BITS * q);
        }
        _queueLengths = lengths;

        _freeLeft = [uint256(1_100), 352, 150, 39];
    }

    // ------------------------------------------------------------------ views

    function totalMinted() public view returns (uint256) {
        return _totalMinted;
    }

    /// @notice The metadata tier of a tokenId, straight from the tier table.
    /// @dev Unlike a stored mapping this is also correct for ids that have
    ///      not been minted yet; out-of-range ids return Common, matching
    ///      the v3 mapping getter's default.
    function tierOf(uint256 tokenId) public view returns (Tier) {
        if (tokenId == 0 || tokenId > MAX_SUPPLY) return Tier.Common;
        return _tierOfRaw(tokenId);
    }

    /// @notice Free-pool ids remaining for one tier.
    function freeRemaining(uint256 tier) external view returns (uint256) {
        require(tier < 4, "tier out of range");
        return _freeLeft[tier];
    }

    /// @notice Sale ids remaining for one tier (Common is never for sale).
    function saleRemaining(uint256 tier) external view returns (uint256) {
        require(tier < 4, "tier out of range");
        if (tier == 0) return 0;
        return _queueLength(uint8(tier)); // sale queue index == tier index
    }

    /// @notice Team-reserve ids remaining for one tier.
    function teamRemaining(uint256 tier) external view returns (uint256) {
        require(tier < 4, "tier out of range");
        if (tier == 0) return 0;
        return _queueLength(uint8(tier) + 3); // team queue index == tier + 3
    }

    /// @notice Legendary mining-reserve ids remaining.
    function miningRemaining() external view returns (uint256) {
        return _queueLength(Q_MINING);
    }

    function totalFreeRemaining() public view returns (uint256) {
        return _queueLength(Q_FREE);
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

    /// @notice Free mint: draws a random id from the remaining free queue.
    ///         The id's metadata tier is whatever the tier table says, so a
    ///         Legendary can drop at any time with the plan's exact odds.
    function freeMint() external nonReentrant returns (uint256 tokenId, Tier tier) {
        require(freeMintActive, "free mint closed");
        require(freeMintedBy[msg.sender] < maxFreePerWallet, "wallet cap");
        require(_queueLength(Q_FREE) > 0, "free pool empty");

        tokenId = _draw(Q_FREE);
        tier = _tierOfRaw(tokenId);
        _freeLeft[uint8(tier)] -= 1;
        freeMintedBy[msg.sender] += 1;
        _safeMint(msg.sender, tokenId);
        emit FreeMint(msg.sender, tokenId, tier);
    }

    // ------------------------------------------------------------------- sale

    /// @notice Buy one NFT of a paid tier at the USD price, paid in BNB.
    ///         The id is drawn from that tier's sale queue, so the buyer
    ///         always receives an NFT whose art is actually of that tier.
    function buy(Tier tier) external payable nonReentrant returns (uint256 tokenId) {
        require(saleActive, "sale closed");
        require(tier != Tier.Common, "common is free");
        uint8 q = uint8(tier); // sale queue index == tier index
        require(_queueLength(q) > 0, "tier sold out");
        uint256 cost = priceInBnb(tier);
        require(msg.value >= cost, "not enough BNB");
        tokenId = _draw(q);
        require(_tierOfRaw(tokenId) == tier, "queue tier mismatch");
        _safeMint(msg.sender, tokenId);
        emit Purchase(msg.sender, tokenId, tier, cost);
        if (msg.value > cost) {
            (bool ok,) = msg.sender.call{value: msg.value - cost}("");
            require(ok, "refund failed");
        }
    }

    // --------------------------------------------------------------- reserves

    /// @notice Owner mints the team reserve (Rare 30 / Epic 25 / Legendary 15 total).
    function mintTeamReserve(address to, Tier tier) external onlyOwner returns (uint256 tokenId) {
        require(tier != Tier.Common, "team reserve empty");
        uint8 q = uint8(tier) + 3; // team queue index == tier + 3
        require(_queueLength(q) > 0, "team reserve empty");
        tokenId = _draw(q);
        require(_tierOfRaw(tokenId) == tier, "queue tier mismatch");
        _safeMint(to, tokenId);
        emit ReserveMint(to, tokenId, tier, "team");
    }

    /// @notice Owner mints the Legendary mining reserve (45 total) to the mining contract.
    function mintMiningReserve(address to) external onlyOwner returns (uint256 tokenId) {
        require(_queueLength(Q_MINING) > 0, "mining reserve empty");
        tokenId = _draw(Q_MINING);
        require(_tierOfRaw(tokenId) == Tier.Legendary, "queue tier mismatch");
        _safeMint(to, tokenId);
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

    /// @dev Swap-and-pop a random element out of queue `q`. Callers must
    ///      have checked the queue is non-empty. Every id exists in exactly
    ///      one queue and is popped at most once, so no id can mint twice
    ///      and total minted can reach exactly MAX_SUPPLY.
    function _draw(uint8 q) internal returns (uint256 tokenId) {
        uint256 len = _queueLength(q);
        uint256 idx = _random(len);
        uint256 start = _queueStart(q);
        tokenId = _readBits(_queueData, (start + idx) * ID_BITS, ID_BITS);
        if (idx + 1 != len) {
            uint256 lastId = _readBits(_queueData, (start + len - 1) * ID_BITS, ID_BITS);
            _writeBits(_queueData, (start + idx) * ID_BITS, ID_BITS, lastId);
        }
        _setQueueLength(q, len - 1);
        _totalMinted += 1;
    }

    function _tierOfRaw(uint256 tokenId) internal view returns (Tier) {
        return Tier(uint8(_readBits(_tierBits, (tokenId - 1) * 2, 2)));
    }

    function _queueLength(uint8 q) internal view returns (uint256) {
        return (_queueLengths >> (ID_BITS * uint256(q))) & 0x7FF;
    }

    function _setQueueLength(uint8 q, uint256 len) internal {
        uint256 shift = ID_BITS * uint256(q);
        _queueLengths = (_queueLengths & ~(uint256(0x7FF) << shift)) | (len << shift);
    }

    /// @dev First element index of each queue inside the packed blob.
    function _queueStart(uint8 q) internal pure returns (uint256) {
        if (q == 0) return 0;
        if (q == 1) return 1641;
        if (q == 2) return 1709;
        if (q == 3) return 1784;
        if (q == 4) return 1884;
        if (q == 5) return 1914;
        if (q == 6) return 1939;
        return 1954; // q == 7 (mining)
    }

    /// @dev Read `bits` bits starting at `bitPos` from a packed byte stream
    ///      (LSB-first: bit 0 is the lowest bit of byte 0).
    function _readBits(bytes storage data, uint256 bitPos, uint256 bits) internal view returns (uint256 v) {
        uint256 byteIdx = bitPos >> 3;
        uint256 off = bitPos & 7;
        uint256 window = uint8(data[byteIdx]);
        if (byteIdx + 1 < data.length) window |= uint256(uint8(data[byteIdx + 1])) << 8;
        if (byteIdx + 2 < data.length) window |= uint256(uint8(data[byteIdx + 2])) << 16;
        v = (window >> off) & ((1 << bits) - 1);
    }

    /// @dev Write the low `bits` of `value` at `bitPos`, preserving the
    ///      surrounding bits. Never writes past the end of the stream.
    function _writeBits(bytes storage data, uint256 bitPos, uint256 bits, uint256 value) internal {
        uint256 byteIdx = bitPos >> 3;
        uint256 off = bitPos & 7;
        uint256 window = uint8(data[byteIdx]);
        if (byteIdx + 1 < data.length) window |= uint256(uint8(data[byteIdx + 1])) << 8;
        if (byteIdx + 2 < data.length) window |= uint256(uint8(data[byteIdx + 2])) << 16;
        uint256 mask = ((1 << bits) - 1) << off;
        window = (window & ~mask) | ((value << off) & mask);
        data[byteIdx] = bytes1(uint8(window));
        if (byteIdx + 1 < data.length) data[byteIdx + 1] = bytes1(uint8(window >> 8));
        if (byteIdx + 2 < data.length) data[byteIdx + 2] = bytes1(uint8(window >> 16));
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
            uint8 t = uint8(_tierOfRaw(tokenId));
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
