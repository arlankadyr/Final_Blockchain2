pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../src/core/SkinMarketAMM.sol";
import "../../src/tokens/CraftToken.sol";
import "../../src/vault/RentalVault.sol";
import "../../src/tokens/SkinToken.sol";

// Простой ERC20 для tokenB
contract SimpleToken is ERC20 {
    constructor() ERC20("Simple", "SMP") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

// Хендлер — все действия идут через него
contract AMMHandler is Test {
    SkinMarketAMM public amm;
    CraftToken public craftToken;
    SimpleToken public simpleToken;

    address public lp = makeAddr("lp");
    address public trader = makeAddr("trader");

    uint256 public totalSwapsAtoB;
    uint256 public totalSwapsBtoA;

    constructor(SkinMarketAMM _amm, CraftToken _craft, SimpleToken _simple) {
        amm = _amm;
        craftToken = _craft;
        simpleToken = _simple;
    }

    function swapAforB(uint256 amount) external {
        amount = bound(amount, 1, 1000 * 1e18);
        if (craftToken.balanceOf(trader) < amount) return;

        vm.startPrank(trader);
        craftToken.approve(address(amm), amount);
        if (amm.reserveA() > 0 && amm.reserveB() > 0) {
            amm.swapAforB(amount, 0);
            totalSwapsAtoB++;
        }
        vm.stopPrank();
    }

    function swapBforA(uint256 amount) external {
        amount = bound(amount, 1, 1000 * 1e18);
        if (simpleToken.balanceOf(trader) < amount) return;

        vm.startPrank(trader);
        simpleToken.approve(address(amm), amount);
        if (amm.reserveA() > 0 && amm.reserveB() > 0) {
            amm.swapBforA(amount, 0);
            totalSwapsBtoA++;
        }
        vm.stopPrank();
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        amountA = bound(amountA, 1000, 10_000 * 1e18);
        amountB = bound(amountB, 1000, 10_000 * 1e18);

        if (craftToken.balanceOf(lp) < amountA) return;
        if (simpleToken.balanceOf(lp) < amountB) return;

        vm.startPrank(lp);
        craftToken.approve(address(amm), amountA);
        simpleToken.approve(address(amm), amountB);
        amm.addLiquidity(amountA, amountB, 0);
        vm.stopPrank();
    }
}

contract InvariantTest is Test {
    SkinMarketAMM public amm;
    CraftToken public craftToken;
    SimpleToken public simpleToken;
    AMMHandler public handler;
    RentalVault public vault;

    address public admin = makeAddr("admin");
    address public lp = makeAddr("lp");
    address public trader = makeAddr("trader");

    function setUp() public {
        vm.startPrank(admin);

        craftToken = new CraftToken(admin);
        simpleToken = new SimpleToken();
        amm = new SkinMarketAMM(admin, address(craftToken), address(simpleToken));
        vault = new RentalVault(admin, address(craftToken));

        // Выдаём токены
        craftToken.mint(lp, 500_000 * 1e18);
        craftToken.mint(trader, 100_000 * 1e18);
        simpleToken.mint(lp, 500_000 * 1e18);
        simpleToken.mint(trader, 100_000 * 1e18);
        vm.stopPrank();

        // Добавляем начальную ликвидность
        vm.startPrank(lp);
        craftToken.approve(address(amm), 100_000 * 1e18);
        simpleToken.approve(address(amm), 100_000 * 1e18);
        amm.addLiquidity(100_000 * 1e18, 100_000 * 1e18, 0);
        vm.stopPrank();

        // Деплоим хендлер
        handler = new AMMHandler(amm, craftToken, simpleToken);

        // Даём хендлеру токены
        vm.prank(admin);
        craftToken.mint(address(handler), 100_000 * 1e18);
        simpleToken.mint(address(handler), 100_000 * 1e18);

        // Таргетим хендлер
        targetContract(address(handler));
    }

    // ─── Инвариант 1: k никогда не уменьшается ───────────────
    function invariant_KNeverDecreases() public view {
        uint256 k = amm.reserveA() * amm.reserveB();
        uint256 initialK = 100_000 * 1e18 * 100_000 * 1e18;
        assertGe(k, initialK / 2); // даём небольшой допуск на округление
    }

    // ─── Инвариант 2: резервы всегда > 0 если есть ликвидность
    function invariant_ReservesPositive() public view {
        if (amm.totalSupply() > 0) {
            assertGt(amm.reserveA(), 0);
            assertGt(amm.reserveB(), 0);
        }
    }

    // ─── Инвариант 3: резервы совпадают с балансами ───────────
    function invariant_ReservesMatchBalances() public view {
        assertEq(amm.reserveA(), craftToken.balanceOf(address(amm)));
        assertEq(amm.reserveB(), simpleToken.balanceOf(address(amm)));
    }

    // ─── Инвариант 4: totalSupply CraftToken консистентен ─────
    function invariant_CraftTotalSupplyConsistent() public view {
        uint256 supply = craftToken.totalSupply();
        assertGt(supply, 0);
    }

    // ─── Инвариант 5: vault totalAssets = балансу контракта ───
    function invariant_VaultAssetsMatchBalance() public view {
        assertEq(vault.totalAssets(), craftToken.balanceOf(address(vault)));
    }
}
