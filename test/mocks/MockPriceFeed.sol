pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockPriceFeed is AggregatorV3Interface {
    int256 private price;
    uint256 private updatedAt;
    uint80 private roundId;

    uint8 public constant override decimals = 8;
    string public constant override description = "ETH/USD Mock";
    uint256 public constant override version = 1;

    constructor(int256 _initialPrice) {
        price = _initialPrice;
        updatedAt = block.timestamp;
        roundId = 1;
    }

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
        roundId++;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, block.timestamp, updatedAt, roundId);
    }

    function getRoundData(uint80) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, price, block.timestamp, updatedAt, roundId);
    }
}
