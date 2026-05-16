pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/CraftingSystem.sol";
import "../../src/tokens/SkinToken.sol";
import "../../src/tokens/CraftToken.sol";

contract CraftingSystemTest is Test {
    CraftingSystem public crafting;
    SkinToken      public skinToken;
    CraftToken     public craftToken;

    address public admin  = makeAddr("admin");
    address public player = makeAddr("player");
    address public user2  = makeAddr("user2");

    function setUp() public {
        vm.startPrank(admin);
        craftToken  = new CraftToken(admin);
        skinToken   = new SkinToken(admin);
        crafting    = new CraftingSystem(admin, address(skinToken), address(craftToken));

        // Даём CraftingSystem право минтить и сжигать скины
        skinToken.grantRole(skinToken.MINTER_ROLE(), address(crafting));

        // Выдаём игроку CRAFT токены
        craftToken.mint(player, 10_000 * 1e18);


        skinToken.mint(player, 0, 6); // 6 штук AK-47
    
        skinToken.mint(player, 3, 4); // 4 штуки Glock

        // Даём approve для burnFrom
        vm.stopPrank();

        vm.startPrank(player);
        craftToken.approve(address(crafting), type(uint256).max);
        skinToken.setApprovalForAll(address(crafting), true);
        vm.stopPrank();
    }

    // ─── Deployment ───────────────────────────────────────────
    function test_InitialRecipesCreated() public view {
        assertEq(crafting.nextRecipeId(), 2);
    }

    function test_Recipe0Exists() public view {
        CraftingSystem.Recipe memory r = crafting.getRecipe(0);
        assertTrue(r.exists);
        assertEq(r.outputSkinId, 3); // Glock Water Elemental
        assertEq(r.outputAmount, 1);
        assertEq(r.craftTokenCost, 50 * 1e18);
    }

    function test_Recipe1Exists() public view {
        CraftingSystem.Recipe memory r = crafting.getRecipe(1);
        assertTrue(r.exists);
        assertEq(r.outputSkinId, 1); // AWP Dragon Lore
        assertEq(r.outputAmount, 1);
        assertEq(r.craftTokenCost, 200 * 1e18);
    }

    // ─── Craft ────────────────────────────────────────────────
    function test_CraftRecipe0() public {
        uint256 craftBefore = craftToken.balanceOf(player);
        uint256 akBefore    = skinToken.balanceOf(player, 0);

        vm.prank(player);
        crafting.craft(0);

        // AK-47 сожжены
        assertEq(skinToken.balanceOf(player, 0), akBefore - 3);
        // Glock получен
        assertEq(skinToken.balanceOf(player, 3), 4 + 1); // 4 было + 1 скрафтили
        // CRAFT сожжён
        assertEq(craftToken.balanceOf(player), craftBefore - 50 * 1e18);
    }

    function test_CraftRecipe1() public {
        uint256 craftBefore  = craftToken.balanceOf(player);
        uint256 glockBefore  = skinToken.balanceOf(player, 3);

        vm.prank(player);
        crafting.craft(1);

        // Glock сожжён
        assertEq(skinToken.balanceOf(player, 3), glockBefore - 2);
        // AWP Dragon Lore получен
        assertEq(skinToken.balanceOf(player, 1), 1);
        // CRAFT сожжён
        assertEq(craftToken.balanceOf(player), craftBefore - 200 * 1e18);
    }

    function test_CraftIncrementsTotalCrafts() public {
        vm.prank(player);
        crafting.craft(0);
        assertEq(crafting.totalCrafts(), 1);

        vm.prank(player);
        crafting.craft(0);
        assertEq(crafting.totalCrafts(), 2);
    }

    function test_RevertCraft_RecipeNotExist() public {
        vm.prank(player);
        vm.expectRevert("Recipe does not exist");
        crafting.craft(999);
    }

    function test_RevertCraft_InsufficientCraft() public {
        address broke = makeAddr("broke");
        vm.prank(admin);
        skinToken.mint(broke, 0, 3);

        vm.prank(broke);
        vm.expectRevert("Insufficient CRAFT");
        crafting.craft(0);
    }

    function test_RevertCraft_InsufficientSkins() public {
        address noSkins = makeAddr("noSkins");
        vm.prank(admin);
        craftToken.mint(noSkins, 1000 * 1e18);

        vm.startPrank(noSkins);
        craftToken.approve(address(crafting), type(uint256).max);
        vm.expectRevert("Insufficient skin balance");
        crafting.craft(0);
        vm.stopPrank();
    }

    // ─── canCraft ─────────────────────────────────────────────
    function test_CanCraft_True() public view {
        assertTrue(crafting.canCraft(player, 0));
    }

    function test_CanCraft_False_NoSkins() public view {
        assertFalse(crafting.canCraft(user2, 0));
    }

    function test_CanCraft_False_NoCraft() public {
        address poor = makeAddr("poor");
        vm.prank(admin);
        skinToken.mint(poor, 0, 3);
        assertFalse(crafting.canCraft(poor, 0));
    }

    // ─── Create Recipe ────────────────────────────────────────
    function test_CreateNewRecipe() public {
        uint256[] memory ids  = new uint256[](1);
        uint256[] memory amts = new uint256[](1);
        ids[0]  = 0;
        amts[0] = 5;

        vm.prank(admin);
        uint256 recipeId = crafting.createRecipe(ids, amts, 500 * 1e18, 1, 1);
        assertEq(recipeId, 2);
        assertEq(crafting.nextRecipeId(), 3);
    }

    function test_RevertCreateRecipe_NotAdmin() public {
        uint256[] memory ids  = new uint256[](1);
        uint256[] memory amts = new uint256[](1);

        vm.prank(player);
        vm.expectRevert();
        crafting.createRecipe(ids, amts, 100 * 1e18, 0, 1);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_CraftMultipleTimes(uint256 times) public {
        times = bound(times, 1, 2); // у нас 6 AK-47, рецепт требует 3

        for (uint256 i = 0; i < times; i++) {
            vm.prank(player);
            crafting.craft(0);
        }

        assertEq(crafting.totalCrafts(), times);
    }
}