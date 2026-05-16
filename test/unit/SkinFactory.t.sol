pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/core/SkinFactory.sol";
import "../../src/tokens/SkinToken.sol";

contract SkinFactoryTest is Test {
    SkinFactory public factory;
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");

    function setUp() public {
        vm.prank(admin);
        factory = new SkinFactory(admin);
    }

    // ─── Deployment ───────────────────────────────────────────
    function test_AdminHasRoles() public view {
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.FACTORY_ADMIN_ROLE(), admin));
    }

    function test_InitialCollectionsEmpty() public view {
        assertEq(factory.getCollectionsCount(), 0);
    }

    // ─── CREATE ───────────────────────────────────────────────
    function test_DeployCollection() public {
        vm.prank(admin);
        address collection = factory.deployCollection(admin);
        assertTrue(collection != address(0));
        assertEq(factory.getCollectionsCount(), 1);
        assertEq(factory.collections(0), collection);
    }

    function test_DeployMultipleCollections() public {
        vm.startPrank(admin);
        factory.deployCollection(admin);
        factory.deployCollection(admin);
        factory.deployCollection(admin);
        vm.stopPrank();
        assertEq(factory.getCollectionsCount(), 3);
    }

    function test_RevertDeploy_NotAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        factory.deployCollection(user1);
    }

    function test_DeployedCollectionHasCorrectAdmin() public {
        vm.prank(admin);
        address collection = factory.deployCollection(admin);
        SkinToken skin = SkinToken(collection);
        assertTrue(skin.hasRole(skin.DEFAULT_ADMIN_ROLE(), admin));
    }

    // ─── CREATE2 ──────────────────────────────────────────────
    function test_DeployCreate2() public {
        bytes32 salt = keccak256("collection_1");
        vm.prank(admin);
        address collection = factory.deployCollectionCreate2(admin, salt);
        assertTrue(collection != address(0));
        assertEq(factory.create2Collections(salt), collection);
    }

    function test_Create2AddressMatchesPrediction() public {
        bytes32 salt = keccak256("collection_1");
        address predicted = factory.predictCreate2Address(salt, admin);

        vm.prank(admin);
        address deployed = factory.deployCollectionCreate2(admin, salt);

        assertEq(predicted, deployed);
    }

    function test_RevertCreate2_SaltAlreadyUsed() public {
        bytes32 salt = keccak256("collection_1");

        vm.startPrank(admin);
        factory.deployCollectionCreate2(admin, salt);

        vm.expectRevert("Salt already used");
        factory.deployCollectionCreate2(admin, salt);
        vm.stopPrank();
    }

    function test_DifferentSaltsGiveDifferentAddresses() public {
        bytes32 salt1 = keccak256("collection_1");
        bytes32 salt2 = keccak256("collection_2");

        vm.startPrank(admin);
        address col1 = factory.deployCollectionCreate2(admin, salt1);
        address col2 = factory.deployCollectionCreate2(admin, salt2);
        vm.stopPrank();

        assertTrue(col1 != col2);
    }

    function test_GetAllCollections() public {
        vm.startPrank(admin);
        factory.deployCollection(admin);
        factory.deployCollectionCreate2(admin, keccak256("s1"));
        vm.stopPrank();

        address[] memory all = factory.getAllCollections();
        assertEq(all.length, 2);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_Create2PredictionAlwaysMatches(bytes32 salt) public {
        address predicted = factory.predictCreate2Address(salt, admin);

        vm.prank(admin);
        address deployed = factory.deployCollectionCreate2(admin, salt);

        assertEq(predicted, deployed);
    }
}