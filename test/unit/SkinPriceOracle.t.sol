// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/oracle/SkinPriceOracle.sol";
import "../mocks/MockPriceFeed.sol";

contract SkinPriceOracleTest is Test {
    SkinPriceOracle public oracle;
    MockPriceFeed public priceFeed;

    address public admin = makeAddr("admin");
    address public user  = makeAddr("user");

    int256 constant ETH_PRICE = 3000 * 1e8; // $3000 в 8 decimals
    uint256 constant STALENESS = 3600;       // 1 час

    function setUp() public {
        vm.startPrank(admin);
        priceFeed = new MockPriceFeed(ETH_PRICE);
        oracle = new SkinPriceOracle(admin, address(priceFeed), STALENESS);
        vm.stopPrank();
    }

    // ─── Deployment ───────────────────────────────────────────
    function test_AdminHasRoles() public view {
        assertTrue(oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(oracle.hasRole(oracle.ORACLE_ADMIN_ROLE(), admin));
    }

    function test_StalenessThreshold() public view {
        assertEq(oracle.stalenessThreshold(), STALENESS);
    }

    // ─── Get ETH Price ────────────────────────────────────────
    function test_GetETHPrice() public view {
        (int256 price,) = oracle.getETHPrice();
        assertEq(price, ETH_PRICE);
    }

    function test_RevertGetPrice_Stale() public {
        // Двигаем время вперёд за порог
        vm.warp(block.timestamp + STALENESS + 1);
        vm.expectRevert("Stale price");
        oracle.getETHPrice();
    }

    function test_RevertGetPrice_NegativePrice() public {
        priceFeed.setPrice(-1);
        vm.expectRevert("Invalid price");
        oracle.getETHPrice();
    }

    function test_RevertGetPrice_ZeroPrice() public {
        priceFeed.setPrice(0);
        vm.expectRevert("Invalid price");
        oracle.getETHPrice();
    }

    // ─── Skin Price ───────────────────────────────────────────
    function test_SetSkinPrice() public {
        vm.prank(admin);
        oracle.setSkinPrice(0, 100 * 1e18); // $100
        assertEq(oracle.skinPriceUSD(0), 100 * 1e18);
    }

    function test_GetSkinPriceInETH() public {
        vm.prank(admin);
        oracle.setSkinPrice(0, 300 * 1e18); // $300

        uint256 priceInETH = oracle.getSkinPriceInETH(0);
        // $300 / $3000 = 0.1 ETH = 1e17
        assertEq(priceInETH, 0.1 ether);
    }

    function test_RevertGetSkinPrice_NotSet() public {
        vm.expectRevert("Skin price not set");
        oracle.getSkinPriceInETH(999);
    }

    function test_RevertSetSkinPrice_NotAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        oracle.setSkinPrice(0, 100 * 1e18);
    }

    function test_RevertSetSkinPrice_ZeroPrice() public {
        vm.prank(admin);
        vm.expectRevert("Zero price");
        oracle.setSkinPrice(0, 0);
    }

    // ─── Update Feed ──────────────────────────────────────────
    function test_UpdatePriceFeed() public {
        MockPriceFeed newFeed = new MockPriceFeed(4000 * 1e8);

        vm.prank(admin);
        oracle.setPriceFeed(address(newFeed));

        (int256 price,) = oracle.getETHPrice();
        assertEq(price, 4000 * 1e8);
    }

    function test_RevertUpdateFeed_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Zero address");
        oracle.setPriceFeed(address(0));
    }

    function test_UpdateStalenessThreshold() public {
        vm.prank(admin);
        oracle.setStalenessThreshold(7200);
        assertEq(oracle.stalenessThreshold(), 7200);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_SkinPriceInETH(uint256 priceUSD, int256 ethPrice) public {
        priceUSD = bound(priceUSD, 1 * 1e18, 100_000 * 1e18);
        ethPrice = int256(bound(uint256(ethPrice), 100 * 1e8, 100_000 * 1e8));

        priceFeed.setPrice(ethPrice);

        vm.prank(admin);
        oracle.setSkinPrice(0, priceUSD);

        uint256 skinETHPrice = oracle.getSkinPriceInETH(0);
        assertTrue(skinETHPrice > 0);
    }
}