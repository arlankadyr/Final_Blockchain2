pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/CaseOpening.sol";
import "../../src/tokens/SkinToken.sol";
import "../../src/tokens/CraftToken.sol";
import "../mocks/MockVRFCoordinator.sol";

contract CaseOpeningTest is Test {
    CaseOpening public caseOpening;
    SkinToken public skinToken;
    CraftToken public craftToken;
    MockVRFCoordinator public vrfCoordinator;

    address public admin = makeAddr("admin");
    address public player = makeAddr("player");

    uint256 constant CASE_PRICE = 100 * 10 ** 18;

    function setUp() public {
        vm.startPrank(admin);

        // Деплоим контракты
        vrfCoordinator = new MockVRFCoordinator();
        craftToken = new CraftToken(admin);
        skinToken = new SkinToken(admin);

        caseOpening = new CaseOpening(
            admin, address(vrfCoordinator), bytes32("keyhash"), 1, address(skinToken), address(craftToken)
        );

        // Даём CaseOpening право минтить скины
        skinToken.grantRole(skinToken.MINTER_ROLE(), address(caseOpening));

        // Даём игроку CRAFT токены
        craftToken.mint(player, 10_000 * 10 ** 18);

        vm.stopPrank();
    }

    function test_InitialCaseCreated() public view {
        assertEq(caseOpening.nextCaseId(), 1);
        (string memory name,, bool exists) = caseOpening.cases(0);
        assertEq(name, "Fracture Case");
        assertTrue(exists);
    }

    function test_CasePriceCorrect() public view {
        (, uint256 price,) = caseOpening.cases(0);
        assertEq(price, CASE_PRICE);
    }

    function test_OpenCase_RequestCreated() public {
        vm.startPrank(player);
        craftToken.approve(address(caseOpening), CASE_PRICE);
        uint256 requestId = caseOpening.openCase(0);
        vm.stopPrank();

        (address reqPlayer, uint256 caseId, bool fulfilled) = caseOpening.openRequests(requestId);
        assertEq(reqPlayer, player);
        assertEq(caseId, 0);
        assertFalse(fulfilled);
    }

    function test_OpenCase_BurnsCraftToken() public {
        uint256 balanceBefore = craftToken.balanceOf(player);

        vm.startPrank(player);
        craftToken.approve(address(caseOpening), CASE_PRICE);
        caseOpening.openCase(0);
        vm.stopPrank();

        assertEq(craftToken.balanceOf(player), balanceBefore - CASE_PRICE);
    }

    function test_OpenCase_FulfillMintsCommonSkin() public {
        vm.startPrank(player);
        craftToken.approve(address(caseOpening), CASE_PRICE);
        uint256 requestId = caseOpening.openCase(0);
        vm.stopPrank();

        // randomWord % 100 = 0 → попадает в Common (0-69)
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, 100);

        // Игрок получил скин
        uint256 total = skinToken.balanceOf(player, 0) + skinToken.balanceOf(player, 1) + skinToken.balanceOf(player, 2)
            + skinToken.balanceOf(player, 3) + skinToken.balanceOf(player, 4);
        assertEq(total, 1);
    }

    function test_OpenCase_FulfillMarkedAsFulfilled() public {
        vm.startPrank(player);
        craftToken.approve(address(caseOpening), CASE_PRICE);
        uint256 requestId = caseOpening.openCase(0);
        vm.stopPrank();

        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, 50);

        (,, bool fulfilled) = caseOpening.openRequests(requestId);
        assertTrue(fulfilled);
    }

    function test_RevertOpen_InsufficientBalance() public {
        address broke = makeAddr("broke");
        vm.prank(broke);
        vm.expectRevert("Insufficient CRAFT balance");
        caseOpening.openCase(0);
    }

    function test_RevertOpen_CaseNotExist() public {
        vm.prank(player);
        vm.expectRevert("Case does not exist");
        caseOpening.openCase(999);
    }

    // ─── Create Case ──────────────────────────────────────────
    function test_CreateNewCase() public {
        uint256[] memory skinIds = new uint256[](2);
        skinIds[0] = 0;
        skinIds[1] = 1;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 80;
        weights[1] = 20;

        vm.prank(admin);
        uint256 caseId = caseOpening.createCase("Danger Zone Case", 200 * 10 ** 18, skinIds, weights);

        assertEq(caseId, 1);
        assertEq(caseOpening.nextCaseId(), 2);
    }

    function test_RevertCreateCase_NotAdmin() public {
        uint256[] memory skinIds = new uint256[](1);
        uint256[] memory weights = new uint256[](1);
        skinIds[0] = 0;
        weights[0] = 100;

        vm.prank(player);
        vm.expectRevert();
        caseOpening.createCase("Fake Case", 100, skinIds, weights);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_OpenCase_AlwaysMintsOneSkin(uint256 randomWord) public {
        vm.startPrank(player);
        craftToken.approve(address(caseOpening), CASE_PRICE);
        uint256 requestId = caseOpening.openCase(0);
        vm.stopPrank();

        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, randomWord);

        uint256 total;
        for (uint256 i = 0; i < 5; i++) {
            total += skinToken.balanceOf(player, i);
        }
        assertEq(total, 1);
    }
}
