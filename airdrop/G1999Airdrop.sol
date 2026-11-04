// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Minimal Chainlink price-feed interface (BNB/USD), same as Genesis1999.
interface IPriceFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title G1999Airdrop
/// @notice Merkle claim distributor for the Genesis1999 (G1999) holder airdrop.
///         Snapshot: 1,756 minted Genesis1999 NFTs; pool 24,497,550 G1999
///         (minus 3,360 wei of rounding dust) across 842 wallets.
///
///         Claims are PAID: each claim charges a BNB fee priced in USD at the
///         live Chainlink BNB/USD rate, scaled by the tiers inside the
///         claiming wallet's allocation:
///           Common $0.03 · Rare $0.07 · Epic $0.11 · Legendary $0.15 per NFT
///         feeUsdCents = 3*common + 7*rare + 11*epic + 15*legendary.
///         The fee is forwarded to the treasury in the same transaction and
///         any overpayment is refunded; the contract never accumulates BNB.
///
/// Leaf scheme (must match the off-chain tree builder exactly):
///   leaf = keccak256(abi.encodePacked(account, tokenAmountWei, feeUsdCents))
///   - packed: address (20 bytes) + uint256 (32 bytes) + uint256 (32 bytes).
///   - Pair hashing follows the OpenZeppelin MerkleProof convention: each pair
///     is sorted ascending before keccak256 concatenation ("sortPairs").
contract G1999Airdrop is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Treasury receiving every claim fee (the project Binance wallet).
    address public constant TREASURY = 0x36aB2cB68475CfDb4B7da0c33e20b4C1a1837486;

    /// @notice The G1999 token paid out by this distributor.
    IERC20 public immutable token;

    /// @notice Chainlink BNB/USD feed (BSC mainnet:
    ///         0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE), same feed and
    ///         conversion pattern as Genesis1999 (USD with 8 decimals).
    IPriceFeed public immutable bnbUsdFeed;

    /// @notice Claims close and unclaimed tokens become withdrawable after
    ///         this timestamp: deploy time + 365 days, fixed at deploy.
    uint256 public immutable claimDeadline;

    /// @notice Merkle root of the (account, amount, feeUsdCents) claim tree.
    bytes32 public merkleRoot;

    /// @notice Claims only execute while active. Starts inactive; the owner
    ///         activates after the distributor has been funded.
    bool public claimsActive;

    /// @notice One successful claim per address, ever.
    mapping(address => bool) public claimed;

    event RootSet(bytes32 root);
    event Activated();
    event Paused();
    event Claimed(address indexed account, uint256 amount, uint256 feeUsdCents, uint256 feeBnb);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(address token_, address feed_, address initialOwner) Ownable(initialOwner) {
        require(token_ != address(0), "token=0");
        require(feed_ != address(0), "feed=0");
        token = IERC20(token_);
        bnbUsdFeed = IPriceFeed(feed_);
        claimDeadline = block.timestamp + 365 days;
    }

    /// @notice BNB (wei) required for a fee quoted in USD cents, at the live
    ///         Chainlink rate. Genesis1999 conversion: (usd8 * 1e18) / answer,
    ///         with usd8 = feeUsdCents * 1e6 ($0.01 = 1e6 at 8 decimals).
    function feeInBnb(uint256 feeUsdCents) public view returns (uint256) {
        (, int256 answer, , , ) = bnbUsdFeed.latestRoundData();
        require(answer > 0, "bad oracle");
        return (feeUsdCents * 1e24) / uint256(answer);
    }

    /// @notice Set (or replace) the Merkle root. Only before activation;
    ///         pause first to rotate the root afterwards.
    function setRoot(bytes32 root) external onlyOwner {
        require(!claimsActive, "active");
        merkleRoot = root;
        emit RootSet(root);
    }

    /// @notice Open claims. Requires a root to be set.
    function activate() external onlyOwner {
        require(merkleRoot != bytes32(0), "no root");
        claimsActive = true;
        emit Activated();
    }

    /// @notice Close claims.
    function pause() external onlyOwner {
        claimsActive = false;
        emit Paused();
    }

    /// @notice Claim the caller's airdrop allocation exactly once, paying the
    ///         BNB fee committed in the Merkle leaf.
    /// @param amount      G1999 allocation in wei, as committed in the tree.
    /// @param feeUsdCents Fee in USD cents, as committed in the tree.
    /// @param proof       Merkle proof for leaf (msg.sender, amount, feeUsdCents).
    function claim(uint256 amount, uint256 feeUsdCents, bytes32[] calldata proof) external payable {
        require(claimsActive, "not active");
        require(block.timestamp <= claimDeadline, "deadline passed");
        require(!claimed[msg.sender], "already claimed");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount, feeUsdCents));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "bad proof");

        uint256 fee = feeInBnb(feeUsdCents);
        require(msg.value >= fee, "fee too low");

        claimed[msg.sender] = true;
        token.safeTransfer(msg.sender, amount);

        if (fee > 0) {
            (bool ok, ) = TREASURY.call{value: fee}("");
            require(ok, "fee fwd failed");
        }
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool okRefund, ) = msg.sender.call{value: excess}("");
            require(okRefund, "refund failed");
        }
        emit Claimed(msg.sender, amount, feeUsdCents, fee);
    }

    /// @notice After the claim deadline, the owner may withdraw whatever
    ///         tokens remain unclaimed.
    function withdrawUnclaimed(address to) external onlyOwner {
        require(to != address(0), "to=0");
        require(block.timestamp > claimDeadline, "too early");
        uint256 bal = token.balanceOf(address(this));
        require(bal > 0, "empty");
        token.safeTransfer(to, bal);
        emit Withdrawn(to, bal);
    }
}
