pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/SkinToken.sol";

contract SkinTokenTest is Test {
    SkinToken public skinToken;
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

   function setUp() public {
    vm.startPrank(admin);
    skinToken = new SkinToken(admin);
    skinToken.grantRole(skinToken.MINTER_ROLE(), minter);
    vm.stopPrank();
    }
    
    function test_InitialSkinsCreated() public view {
        assertEq(skinToken.nextSkinId(), 5);
    }

    function test_FirstSkinIsAK() public view {
        (string memory name, SkinToken.Rarity rarity,,) = skinToken.skins(0);
        assertEq(name, "AK-47 | Redline");
        assertEq(uint(rarity), uint(SkinToken.Rarity.COMMON));
    }

    function test_LegendarySkinMaxSupply() public view {
        (,, uint256 maxSupply,) = skinToken.skins(1); // AWP Dragon Lore
        assertEq(maxSupply, 500);
    }

    function test_AdminHasRoles() public view {
        assertTrue(skinToken.hasRole(skinToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(skinToken.hasRole(skinToken.MINTER_ROLE(), admin));
    }

    // ─── Mint ─────────────────────────────────────────────────
    function test_MintSkin() public {
        vm.prank(minter);
        skinToken.mint(user1, 0, 1);
        assertEq(skinToken.balanceOf(user1, 0), 1);
    }

    function test_MintMultipleSkins() public {
        vm.prank(minter);
        skinToken.mint(user1, 0, 5);
        assertEq(skinToken.balanceOf(user1, 0), 5);
    }

    function test_RevertMint_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        skinToken.mint(user1, 0, 1);
    }

    function test_RevertMint_SkinNotExist() public {
        vm.prank(minter);
        vm.expectRevert("Skin does not exist");
        skinToken.mint(user1, 999, 1);
    }

    function test_RevertMint_ExceedsMaxSupply() public {
        vm.prank(minter);
        vm.expectRevert("Exceeds max supply");
        skinToken.mint(user1, 1, 501); // AWP max supply = 500
    }

    
    function test_CreateNewSkinType() public {
        vm.prank(admin);
        uint256 newId = skinToken.createSkinType("Desert Eagle | Blaze", SkinToken.Rarity.RARE, 2000);
        assertEq(newId, 5);
        assertEq(skinToken.getSkinName(5), "Desert Eagle | Blaze");
    }

    function test_RevertCreateSkin_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        skinToken.createSkinType("Fake Skin", SkinToken.Rarity.COMMON, 1000);
    }

    
    function test_TransferSkin() public {
        vm.prank(minter);
        skinToken.mint(user1, 0, 2);

        vm.prank(user1);
        skinToken.safeTransferFrom(user1, user2, 0, 1, "");

        assertEq(skinToken.balanceOf(user1, 0), 1);
        assertEq(skinToken.balanceOf(user2, 0), 1);
    }

    
    function test_BurnSkin() public {
        vm.prank(minter);
        skinToken.mint(user1, 0, 3);

        vm.prank(user1);
        skinToken.burn(user1, 0, 2);

        assertEq(skinToken.balanceOf(user1, 0), 1);
    }

    function test_RevertBurn_NotOwner() public {
        vm.prank(minter);
        skinToken.mint(user1, 0, 1);

        vm.prank(user2);
        vm.expectRevert();
        skinToken.burn(user1, 0, 1);
    }

    
    function test_GetRarity() public view {
        assertEq(uint(skinToken.getRarity(0)), uint(SkinToken.Rarity.COMMON));
        assertEq(uint(skinToken.getRarity(1)), uint(SkinToken.Rarity.LEGENDARY));
    }

    function test_TotalSupplyTracked() public {
        vm.prank(minter);
        skinToken.mint(user1, 0, 10);
        assertEq(skinToken.totalSupply(0), 10);
    }

    
    function testFuzz_MintWithinMaxSupply(uint256 amount) public {
        amount = bound(amount, 1, 500); // AWP max = 500
        vm.prank(minter);
        skinToken.mint(user1, 1, amount);
        assertEq(skinToken.balanceOf(user1, 1), amount);
    }

    function testFuzz_TransferNeverExceedsBalance(uint256 mintAmt, uint256 transferAmt) public {
        mintAmt = bound(mintAmt, 1, 10000);
        transferAmt = bound(transferAmt, 1, mintAmt);

        vm.prank(minter);
        skinToken.mint(user1, 0, mintAmt);

        vm.prank(user1);
        skinToken.safeTransferFrom(user1, user2, 0, transferAmt, "");

        assertEq(skinToken.balanceOf(user1, 0), mintAmt - transferAmt);
        assertEq(skinToken.balanceOf(user2, 0), transferAmt);
    }
}