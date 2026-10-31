// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockFeed — test-only stand-in for the Chainlink BNB/USD feed.
/// @dev Fixed answer of $880.00 (8 decimals). Never deploy on mainnet.
contract MockFeed {
    int256 public constant ANSWER = 88_000_000_000; // $880 x 1e8

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, ANSWER, block.timestamp, block.timestamp, 1);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}
