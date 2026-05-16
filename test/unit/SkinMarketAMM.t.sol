pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SkinMarketAMM.sol";
import "../../src/tokens/CraftToken.sol";

// Простой ERC20 для tokenB (WETH мок)
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped ETH", "WETH") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SkinMarketAMMTest is Test {
    SkinMarketAMM public amm;
    CraftToken public craftToken;
    MockWETH public weth;

    address public admin  = makeAddr("admin");
    address public lp     = makeAddr("lp");
    address public trader = makeAddr("trader");

    uint256 constant INITIAL_A = 100_000 * 1e18;
    uint256 constant INITIAL_B = 100_000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);
        craftToken = new CraftToken(admin);
        weth = new MockWETH();
        amm = new SkinMarketAMM(admin, address(craftToken), address(weth));

        // Выдаём токены LP провайдеру
        craftToken.mint(lp, INITIAL_A * 2);
        weth.mint(lp, INITIAL_B * 2);

        // Выдаём токены трейдеру
        craftToken.mint(trader, 10_000 * 1e18);
        weth.mint(trader, 10_000 * 1e18);
        vm.stopPrank();
    }

    // ─── Helpers ──────────────────────────────────────────────
    function _addInitialLiquidity() internal {
        vm.startPrank(lp);
        craftToken.approve(address(amm), INITIAL_A);
        weth.approve(address(amm), INITIAL_B);
        amm.addLiquidity(INITIAL_A, INITIAL_B, 0);
        vm.stopPrank();
    }

    // ─── Add Liquidity ────────────────────────────────────────
    function test_AddInitialLiquidity() public {
        _addInitialLiquidity();
        assertEq(amm.reserveA(), INITIAL_A);
        assertEq(amm.reserveB(), INITIAL_B);
        assertTrue(amm.balanceOf(lp) > 0);
    }

    function test_AddLiquidity_MinimumLiquidityBurned() public {
        _addInitialLiquidity();
        assertEq(amm.balanceOf(address(0xdead)), amm.MINIMUM_LIQUIDITY());
    }

    function test_AddLiquidity_SecondProvider() public {
        _addInitialLiquidity();

        address lp2 = makeAddr("lp2");
        vm.startPrank(admin);
        craftToken.mint(lp2, INITIAL_A);
        weth.mint(lp2, INITIAL_B);
        vm.stopPrank();

        vm.startPrank(lp2);
        craftToken.approve(address(amm), INITIAL_A);
        weth.approve(address(amm), INITIAL_B);
        amm.addLiquidity(INITIAL_A, INITIAL_B, 0);
        vm.stopPrank();

        assertTrue(amm.balanceOf(lp2) > 0);
    }

    function test_RevertAddLiquidity_ZeroAmounts() public {
        vm.prank(lp);
        vm.expectRevert("Zero amounts");
        amm.addLiquidity(0, 0, 0);
    }

    // ─── Remove Liquidity ─────────────────────────────────────
    function test_RemoveLiquidity() public {
        _addInitialLiquidity();

        uint256 lpBalance = amm.balanceOf(lp);
        uint256 craftBefore = craftToken.balanceOf(lp);
        uint256 wethBefore = weth.balanceOf(lp);

        vm.startPrank(lp);
        amm.approve(address(amm), lpBalance);
        amm.removeLiquidity(lpBalance, 0, 0);
        vm.stopPrank();

        assertTrue(craftToken.balanceOf(lp) > craftBefore);
        assertTrue(weth.balanceOf(lp) > wethBefore);
        assertEq(amm.balanceOf(lp), 0);
    }

    function test_RevertRemoveLiquidity_SlippageCheck() public {
        _addInitialLiquidity();

        uint256 lpBalance = amm.balanceOf(lp);

        vm.startPrank(lp);
        amm.approve(address(amm), lpBalance);
        vm.expectRevert("Insufficient A");
        amm.removeLiquidity(lpBalance, type(uint256).max, 0);
        vm.stopPrank();
    }

    // ─── Swap ─────────────────────────────────────────────────
    function test_SwapAforB() public {
        _addInitialLiquidity();

        uint256 amountIn = 1000 * 1e18;
        uint256 wethBefore = weth.balanceOf(trader);

        vm.startPrank(trader);
        craftToken.approve(address(amm), amountIn);
        uint256 amountOut = amm.swapAforB(amountIn, 0);
        vm.stopPrank();

        assertTrue(amountOut > 0);
        assertEq(weth.balanceOf(trader), wethBefore + amountOut);
    }

    function test_SwapBforA() public {
        _addInitialLiquidity();

        uint256 amountIn = 1000 * 1e18;
        uint256 craftBefore = craftToken.balanceOf(trader);

        vm.startPrank(trader);
        weth.approve(address(amm), amountIn);
        uint256 amountOut = amm.swapBforA(amountIn, 0);
        vm.stopPrank();

        assertTrue(amountOut > 0);
        assertEq(craftToken.balanceOf(trader), craftBefore + amountOut);
    }

    function test_SwapFeeApplied() public {
        _addInitialLiquidity();

        uint256 amountIn = 1000 * 1e18;
        uint256 amountOut = amm.getAmountOutAforB(amountIn);

        // С учётом 0.3% fee amountOut должен быть меньше чем без fee
        uint256 amountOutNoFee = (amountIn * INITIAL_B) / (INITIAL_A + amountIn);
        assertTrue(amountOut < amountOutNoFee);
    }

    function test_RevertSwap_SlippageExceeded() public {
        _addInitialLiquidity();

        vm.startPrank(trader);
        craftToken.approve(address(amm), 1000 * 1e18);
        vm.expectRevert("Slippage exceeded");
        amm.swapAforB(1000 * 1e18, type(uint256).max);
        vm.stopPrank();
    }

    function test_RevertSwap_NoLiquidity() public {
        vm.startPrank(trader);
        craftToken.approve(address(amm), 1000 * 1e18);
        vm.expectRevert("No liquidity");
        amm.swapAforB(1000 * 1e18, 0);
        vm.stopPrank();
    }

    // ─── Invariant: k никогда не уменьшается ─────────────────
    function test_KInvariantAfterSwap() public {
        _addInitialLiquidity();

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        craftToken.approve(address(amm), 1000 * 1e18);
        amm.swapAforB(1000 * 1e18, 0);
        vm.stopPrank();

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertTrue(kAfter >= kBefore);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_SwapNeverDrainsPool(uint256 amountIn) public {
        _addInitialLiquidity();
        amountIn = bound(amountIn, 1, 1000 * 1e18);

        vm.startPrank(trader);
        craftToken.approve(address(amm), amountIn);
        amm.swapAforB(amountIn, 0);
        vm.stopPrank();

        assertTrue(amm.reserveA() > 0);
        assertTrue(amm.reserveB() > 0);
    }

    function testFuzz_KInvariantAlwaysHolds(uint256 amountIn) public {
        _addInitialLiquidity();
        amountIn = bound(amountIn, 1, 5000 * 1e18);

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        craftToken.approve(address(amm), amountIn);
        amm.swapAforB(amountIn, 0);
        vm.stopPrank();

        assertTrue(amm.reserveA() * amm.reserveB() >= kBefore);
    }
}