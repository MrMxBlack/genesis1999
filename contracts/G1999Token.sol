// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title G1999Token — project token, fixed supply 99.99 million.
/// @notice Allocation (agreed plan, 2026-10-31):
///   Mining pool 34.5% · NFT-holder airdrop 24.5% · Public sale 11% ·
///   Promotion 10% · Team 20%.
/// @dev The whole supply is minted once, in the constructor, to the bucket
///      addresses passed at deployment. There is no mint function afterwards:
///      the cap is hard. Any bucket address left as address(0) falls back to
///      the deployer (owner), who can forward it later (e.g. once the mining
///      contract is deployed). The public-sale price is NOT set here — the
///      owner decides it later; the sale itself is handled by a separate
///      sale contract that will custody the public-sale bucket.
contract G1999Token is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 99_990_000 * 1e18;

    // Allocation in basis points of TOTAL_SUPPLY (sum = 10_000).
    uint256 public constant BPS_MINING = 3_450; // 34.5%
    uint256 public constant BPS_AIRDROP = 2_450; // 24.5%
    uint256 public constant BPS_PUBLIC_SALE = 1_100; // 11%
    uint256 public constant BPS_PROMOTION = 1_000; // 10%
    uint256 public constant BPS_TEAM = 2_000; // 20%

    event BucketFunded(string bucket, address indexed to, uint256 amount);

    /// @param name_  Token name (chosen by the owner before deployment).
    /// @param symbol_ Token symbol (chosen by the owner before deployment).
    /// @param miningVault   Receives the 34.5% mining bucket (mining contract or owner).
    /// @param airdropVault  Receives the 24.5% airdrop bucket.
    /// @param publicSaleVault Receives the 11% public-sale bucket.
    /// @param promotionVault  Receives the 10% promotion bucket.
    /// @param teamVault     Receives the 20% team bucket.
    constructor(
        string memory name_,
        string memory symbol_,
        address miningVault,
        address airdropVault,
        address publicSaleVault,
        address promotionVault,
        address teamVault
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _fund("mining", miningVault, (TOTAL_SUPPLY * BPS_MINING) / 10_000);
        _fund("airdrop", airdropVault, (TOTAL_SUPPLY * BPS_AIRDROP) / 10_000);
        _fund("publicSale", publicSaleVault, (TOTAL_SUPPLY * BPS_PUBLIC_SALE) / 10_000);
        _fund("promotion", promotionVault, (TOTAL_SUPPLY * BPS_PROMOTION) / 10_000);
        // Team bucket takes the remainder so the minted total is exact.
        uint256 rest = TOTAL_SUPPLY - totalSupply();
        _fund("team", teamVault, rest);
    }

    function _fund(string memory bucket, address to, uint256 amount) internal {
        address dst = to == address(0) ? owner() : to;
        _mint(dst, amount);
        emit BucketFunded(bucket, dst, amount);
    }
}
