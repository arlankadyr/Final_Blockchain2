pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../tokens/SkinToken.sol";

contract SkinFactory is AccessControl {
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    // Все задеплоенные коллекции
    address[] public collections;
    // salt => адрес (для CREATE2)
    mapping(bytes32 => address) public create2Collections;

    event CollectionDeployed(address indexed collection, address indexed admin, bool isCreate2);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FACTORY_ADMIN_ROLE, admin);
    }

    /// @notice Деплой новой коллекции скинов через CREATE
    function deployCollection(address collectionAdmin)
        external
        onlyRole(FACTORY_ADMIN_ROLE)
        returns (address)
    {
        SkinToken newCollection = new SkinToken(collectionAdmin);
        collections.push(address(newCollection));
        emit CollectionDeployed(address(newCollection), collectionAdmin, false);
        return address(newCollection);
    }

    /// @notice 
    function deployCollectionCreate2(address collectionAdmin, bytes32 salt)
        external
        onlyRole(FACTORY_ADMIN_ROLE)
        returns (address)
    {
        require(create2Collections[salt] == address(0), "Salt already used");

        SkinToken newCollection = new SkinToken{salt: salt}(collectionAdmin);
        collections.push(address(newCollection));
        create2Collections[salt] = address(newCollection);
        emit CollectionDeployed(address(newCollection), collectionAdmin, true);
        return address(newCollection);
    }

    /// @notice 
    function predictCreate2Address(bytes32 salt, address collectionAdmin)
        external
        view
        returns (address)
    {
        bytes memory bytecode = abi.encodePacked(
            type(SkinToken).creationCode,
            abi.encode(collectionAdmin)
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }

    /// @notice 
    function getCollectionsCount() external view returns (uint256) {
        return collections.length;
    }

    /// @notice 
    function getAllCollections() external view returns (address[] memory) {
        return collections;
    }
}