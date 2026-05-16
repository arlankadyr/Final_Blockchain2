pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/CraftToken.sol";

contract CraftTokenTest is Test {
    CraftToken public token;
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.prank(admin);
        token = new CraftToken(admin);
    }

    // ─── Deployment ───────────────────────────────────────────
    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10 ** 18);
    }

    function test_AdminHasMinterRole() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
    }

    function test_NameAndSymbol() public view {
        assertEq(token.name(), "CraftToken");
        assertEq(token.symbol(), "CRAFT");
    }

    // ─── Mint ─────────────────────────────────────────────────
    function test_MintTokens() public {
        vm.prank(admin);
        token.mint(user1, 500 * 10 ** 18);
        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
    }

    function test_RevertMint_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 100 * 10 ** 18);
    }

    // ─── Burn ─────────────────────────────────────────────────
    function test_BurnTokens() public {
        vm.prank(admin);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        token.burn(400 * 10 ** 18);

        assertEq(token.balanceOf(user1), 600 * 10 ** 18);
    }

    function test_RevertBurn_InsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(1 * 10 ** 18);
    }

    // ─── Voting Power ─────────────────────────────────────────
    function test_DelegateVotingPower() public {
        vm.prank(admin);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        token.delegate(user1);

        assertEq(token.getVotes(user1), 1000 * 10 ** 18);
    }

    function test_VotingPowerTransferAfterDelegate() public {
        vm.prank(admin);
        token.mint(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        token.delegate(user1);

        vm.prank(user1);
        token.transfer(user2, 300 * 10 ** 18);

        assertEq(token.getVotes(user1), 700 * 10 ** 18);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 * 10 ** 18);
        vm.prank(admin);
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testFuzz_BurnNeverExceedsBalance(uint256 mintAmt, uint256 burnAmt) public {
        mintAmt = bound(mintAmt, 1, 1_000_000 * 10 ** 18);
        burnAmt = bound(burnAmt, 1, mintAmt);

        vm.prank(admin);
        token.mint(user1, mintAmt);

        vm.prank(user1);
        token.burn(burnAmt);

        assertEq(token.balanceOf(user1), mintAmt - burnAmt);
    }
}