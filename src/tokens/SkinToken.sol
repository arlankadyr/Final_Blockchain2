pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SkinToken is ERC1155, ERC1155Burnable, ERC1155Supply, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    enum Rarity {
        COMMON,
        RARE,
        LEGENDARY
    }

    // Данные о каждом типе скина
    struct SkinInfo {
        string name;
        Rarity rarity;
        uint256 maxSupply;
        bool exists;
    }

    // skinId => SkinInfo
    mapping(uint256 => SkinInfo) public skins;
    uint256 public nextSkinId;

    // Events
    event SkinTypeCreated(uint256 indexed skinId, string name, Rarity rarity, uint256 maxSupply);
    event SkinMinted(address indexed to, uint256 indexed skinId, uint256 amount);

    constructor(address admin) ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);

        // Создаём стартовые типы скинов
        _createSkinType("AK-47 | Redline", Rarity.COMMON, 10000);
        _createSkinType("AWP | Dragon Lore", Rarity.LEGENDARY, 500);
        _createSkinType("M4A4 | Howl", Rarity.LEGENDARY, 500);
        _createSkinType("Glock | Water Elemental", Rarity.RARE, 3000);
        _createSkinType("USP | Neo-Noir", Rarity.RARE, 3000);
    }

    /// @notice Создать новый тип скина (только admin)
    function createSkinType(string calldata name, Rarity rarity, uint256 maxSupply)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256)
    {
        return _createSkinType(name, rarity, maxSupply);
    }

    /// @notice Заминтить скин игроку (только MINTER_ROLE — вызывает CaseOpening)
    function mint(address to, uint256 skinId, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(skins[skinId].exists, "Skin does not exist");
        require(totalSupply(skinId) + amount <= skins[skinId].maxSupply, "Exceeds max supply");
        _mint(to, skinId, amount, "");
        emit SkinMinted(to, skinId, amount);
    }

    /// @notice Получить редкость скина
    function getRarity(uint256 skinId) external view returns (Rarity) {
        require(skins[skinId].exists, "Skin does not exist");
        return skins[skinId].rarity;
    }

    /// @notice Получить имя скина
    function getSkinName(uint256 skinId) external view returns (string memory) {
        require(skins[skinId].exists, "Skin does not exist");
        return skins[skinId].name;
    }

    // ─── Internal ─────────────────────────────────────────────
    function _createSkinType(string memory name, Rarity rarity, uint256 maxSupply) internal returns (uint256) {
        uint256 skinId = nextSkinId++;
        skins[skinId] = SkinInfo({name: name, rarity: rarity, maxSupply: maxSupply, exists: true});
        emit SkinTypeCreated(skinId, name, rarity, maxSupply);
        return skinId;
    }

    // ─── Required overrides ───────────────────────────────────
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
