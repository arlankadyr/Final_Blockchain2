pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/vault/RentalVault.sol";
import "../../src/tokens/CraftToken.sol";

contract RentalVaultTest is Test {
    RentalVault public vault;
    CraftToken public craftToken;

    address public admin   = makeAddr("admin");
    address public user1   = makeAddr("user1");
    address public user2   = makeAddr("user2");
    address public renter  = makeAddr("renter");

    uint256 constant DEPOSIT_AMOUNT = 10_000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);
        craftToken = new CraftToken(admin);
        vault = new RentalVault(admin, address(craftToken));

        // Выдаём токены пользователям
        craftToken.mint(user1, DEPOSIT_AMOUNT);
        craftToken.mint(user2, DEPOSIT_AMOUNT);
        craftToken.mint(renter, 5_000 * 1e18);
        vm.stopPrank();
    }

    // ─── Deployment ───────────────────────────────────────────
    function test_VaultName() public view {
        assertEq(vault.name(), "Rental Vault Share");
        assertEq(vault.symbol(), "rvCRAFT");
    }

    function test_AssetIsCraftToken() public view {
        assertEq(vault.asset(), address(craftToken));
    }

    function test_InitialTotalAssets() public view {
        assertEq(vault.totalAssets(), 0);
    }

    // ─── Deposit ──────────────────────────────────────────────
    function test_Deposit() public {
        vm.startPrank(user1);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        assertTrue(shares > 0);
        assertEq(vault.balanceOf(user1), shares);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
    }

    function test_DepositTwoUsers() public {
        vm.startPrank(user1);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, user2);
        vm.stopPrank();

        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT * 2);
    }

    function test_SharesProportional() public {
        vm.startPrank(user1);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares1 = vault.deposit(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        vm.startPrank(user2);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares2 = vault.deposit(DEPOSIT_AMOUNT, user2);
        vm.stopPrank();

        assertEq(shares1, shares2);
    }

    // ─── Withdraw ─────────────────────────────────────────────
    function test_Withdraw() public {
        vm.startPrank(user1);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, user1);

        uint256 craftBefore = craftToken.balanceOf(user1);
        vault.withdraw(DEPOSIT_AMOUNT, user1, user1);
        vm.stopPrank();

        assertEq(craftToken.balanceOf(user1), craftBefore + DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(user1), 0);
    }

    function test_Redeem() public {
        vm.startPrank(user1);
        craftToken.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, user1);

        uint256 craftBefore = craftToken.balanceOf(user1);
        vault.redeem(shares, user1, user1);
        vm.stopPrank();

        assertTrue(craftToken.balanceOf(user1) > craftBefore);
    }

    // ─── Rental ───────────────────────────────────────────────
    function test_RentSkin() public {
        vm.startPrank(renter);
        craftToken.approve(address(vault), type(uint256).max);
        uint256 rentalId = vault.rentSkin(0, 3, 100 * 1e18);
        vm.stopPrank();

        RentalVault.Rental memory rental = vault.getRental(rentalId);
        assertEq(rental.renter, renter);
        assertEq(rental.skinId, 0);
        assertTrue(rental.active);
    }

    function test_RentSkin_BurnsCraftToken() public {
        uint256 balanceBefore = craftToken.balanceOf(renter);
        uint256 pricePerDay = 100 * 1e18;
        uint256 days_ = 3;

        vm.startPrank(renter);
        craftToken.approve(address(vault), type(uint256).max);
        vault.rentSkin(0, days_, pricePerDay);
        vm.stopPrank();

        assertEq(craftToken.balanceOf(renter), balanceBefore - (pricePerDay * days_));
    }

    function test_RentSkin_EndTime() public {
        vm.startPrank(renter);
        craftToken.approve(address(vault), type(uint256).max);
        uint256 rentalId = vault.rentSkin(0, 7, 100 * 1e18);
        vm.stopPrank();

        RentalVault.Rental memory rental = vault.getRental(rentalId);
        assertEq(rental.endTime, block.timestamp + 7 days);
    }

    function test_EndRental() public {
        vm.startPrank(renter);
        craftToken.approve(address(vault), type(uint256).max);
        uint256 rentalId = vault.rentSkin(0, 1, 100 * 1e18);
        vault.endRental(rentalId);
        vm.stopPrank();

        RentalVault.Rental memory rental = vault.getRental(rentalId);
        assertFalse(rental.active);
    }

    function test_RevertEndRental_NotRenter() public {
        vm.startPrank(renter);
        craftToken.approve(address(vault), type(uint256).max);
        uint256 rentalId = vault.rentSkin(0, 1, 100 * 1e18);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("Not authorized");
        vault.endRental(rentalId);
    }

    function test_RevertRent_ZeroDays() public {
        vm.prank(renter);
        vm.expectRevert("Zero days");
        vault.rentSkin(0, 0, 100 * 1e18);
    }

    function test_IsRentalActive() public {
        vm.startPrank(renter);
        craftToken.approve(address(vault), type(uint256).max);
        uint256 rentalId = vault.rentSkin(0, 1, 100 * 1e18);
        vm.stopPrank();

        assertTrue(vault.isRentalActive(rentalId));

        // Перематываем время вперёд
        vm.warp(block.timestamp + 2 days);
        assertFalse(vault.isRentalActive(rentalId));
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_DepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1e18, DEPOSIT_AMOUNT);

        vm.startPrank(user1);
        craftToken.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, user1);
        uint256 assets = vault.redeem(shares, user1, user1);
        vm.stopPrank();

        // После redeem должны вернуть не меньше чем вложили
        assertGe(assets, amount - 1); // -1 на rounding
    }

    function testFuzz_RentSkin(uint256 days_, uint256 pricePerDay) public {
        days_ = bound(days_, 1, 30);
        pricePerDay = bound(pricePerDay, 1e18, 100 * 1e18);

        uint256 totalCost = days_ * pricePerDay;
        vm.prank(admin);
        craftToken.mint(renter, totalCost);

        vm.startPrank(renter);
        craftToken.approve(address(vault), totalCost);
        uint256 rentalId = vault.rentSkin(0, days_, pricePerDay);
        vm.stopPrank();

        assertTrue(vault.getRental(rentalId).active);
    }
}