pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SkinMarketAMM.sol";
import "../../src/tokens/CraftToken.sol";
import "../../src/oracle/SkinPriceOracle.sol";
import "../../src/vault/RentalVault.sol";

contract ForkTest is Test {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant ETH_USD_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address constant USDC_WHALE = 0x47c031236e19d024b42f8AE6780E44A573170703;
    address constant WETH_WHALE = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;

    SkinMarketAMM public amm;
    CraftToken public craftToken;
    SkinPriceOracle public oracle;
    RentalVault public vault;

    address public admin = makeAddr("admin");

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        vm.startPrank(admin);
        craftToken = new CraftToken(admin);
        oracle = new SkinPriceOracle(admin, ETH_USD_FEED, 3600);
        amm = new SkinMarketAMM(admin, address(craftToken), WETH);
        vault = new RentalVault(admin, address(craftToken));
        vm.stopPrank();
    }

    function test_Fork_ChainlinkPriceFeed() public view {
        (int256 price, uint256 updatedAt) = oracle.getETHPrice();

        assertGt(price, 500 * 1e8);
        assertLt(price, 50_000 * 1e8);

        assertGt(updatedAt, 0);
        assertLt(block.timestamp - updatedAt, 3600);
    }

    function test_Fork_AMMWithRealWETH() public {
        vm.startPrank(WETH_WHALE);
        IERC20(WETH).transfer(admin, 10 ether);
        vm.stopPrank();

        // Выдаём CRAFT токены
        vm.prank(admin);
        craftToken.mint(admin, 100_000 * 1e18);

        // Добавляем ликвидность
        vm.startPrank(admin);
        craftToken.approve(address(amm), 100_000 * 1e18);
        IERC20(WETH).approve(address(amm), 10 ether);
        uint256 lpTokens = amm.addLiquidity(100_000 * 1e18, 10 ether, 0);
        vm.stopPrank();

        assertTrue(lpTokens > 0);
        assertEq(amm.reserveA(), 100_000 * 1e18);
        assertEq(amm.reserveB(), 10 ether);
    }

    // ─── Fork Test 3: Swap с реальным WETH ────────────────────
    function test_Fork_SwapCraftForWETH() public {
        // Берём WETH у кита
        vm.prank(WETH_WHALE);
        IERC20(WETH).transfer(admin, 10 ether);

        // Добавляем ликвидность
        vm.startPrank(admin);
        craftToken.mint(admin, 100_000 * 1e18);
        craftToken.approve(address(amm), 100_000 * 1e18);
        IERC20(WETH).approve(address(amm), 10 ether);
        amm.addLiquidity(100_000 * 1e18, 10 ether, 0);
        vm.stopPrank();

        // Трейдер получает CRAFT и делает своп
        address trader = makeAddr("trader");
        vm.prank(admin);
        craftToken.mint(trader, 1000 * 1e18);

        uint256 wethBefore = IERC20(WETH).balanceOf(trader);
        uint256 expectedOut = amm.getAmountOutAforB(1000 * 1e18);

        vm.startPrank(trader);
        craftToken.approve(address(amm), 1000 * 1e18);
        uint256 amountOut = amm.swapAforB(1000 * 1e18, 0);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(IERC20(WETH).balanceOf(trader), wethBefore + amountOut);
    }

    // ─── Fork Test 4: Vault с реальным WETH как коллатерал ────
    function test_Fork_OracleSkinsPrice() public {
        // Устанавливаем цену скина в $500
        vm.prank(admin);
        oracle.setSkinPrice(0, 500 * 1e18);

        // Получаем цену в ETH
        uint256 priceInETH = oracle.getSkinPriceInETH(0);

        // Цена должна быть разумной (0.001 - 10 ETH)
        assertGt(priceInETH, 0.001 ether);
        assertLt(priceInETH, 10 ether);
    }
}
