// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SkinPriceOracle is AccessControl {
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");

    AggregatorV3Interface public priceFeed;

    // Максимальный возраст цены (1 час)
    uint256 public stalenessThreshold;

    // Цены скинов в USD (в 18 decimals)
    mapping(uint256 => uint256) public skinPriceUSD;

    event PriceFeedUpdated(address indexed newFeed);
    event SkinPriceSet(uint256 indexed skinId, uint256 priceUSD);
    event StalenessThresholdUpdated(uint256 newThreshold);

    constructor(address admin, address _priceFeed, uint256 _stalenessThreshold) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ADMIN_ROLE, admin);
        priceFeed = AggregatorV3Interface(_priceFeed);
        stalenessThreshold = _stalenessThreshold;
    }

    /// @notice Получить текущую цену ETH/USD из Chainlink
    function getETHPrice() external view returns (int256 price, uint256 updatedAt) {
        (uint80 roundId, int256 answer,, uint256 timestamp, uint80 answeredInRound) = priceFeed.latestRoundData();

        // Staleness check
        require(block.timestamp - timestamp <= stalenessThreshold, "Stale price");
        // Sanity checks
        require(answer > 0, "Invalid price");
        require(answeredInRound >= roundId, "Incomplete round");

        return (answer, timestamp);
    }

    /// @notice Получить цену скина в ETH
    function getSkinPriceInETH(uint256 skinId) external view returns (uint256) {
        require(skinPriceUSD[skinId] > 0, "Skin price not set");

        (int256 ethPrice,) = this.getETHPrice();

        // skinPriceUSD / ethPrice = цена в ETH
        // ethPrice в 8 decimals (Chainlink), skinPriceUSD в 18 decimals
        return (skinPriceUSD[skinId] * 1e8) / uint256(ethPrice);
    }

    /// @notice Установить цену скина в USD
    function setSkinPrice(uint256 skinId, uint256 priceUSD) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(priceUSD > 0, "Zero price");
        skinPriceUSD[skinId] = priceUSD;
        emit SkinPriceSet(skinId, priceUSD);
    }

    /// @notice Обновить адрес price feed
    function setPriceFeed(address newFeed) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(newFeed != address(0), "Zero address");
        priceFeed = AggregatorV3Interface(newFeed);
        emit PriceFeedUpdated(newFeed);
    }

    /// @notice Обновить порог устаревания
    function setStalenessThreshold(uint256 newThreshold) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(newThreshold > 0, "Zero threshold");
        stalenessThreshold = newThreshold;
        emit StalenessThresholdUpdated(newThreshold);
    }
}
