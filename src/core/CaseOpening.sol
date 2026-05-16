pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "../tokens/SkinToken.sol";
import "../tokens/CraftToken.sol";

contract CaseOpening is VRFConsumerBaseV2, AccessControl, ReentrancyGuard {
    bytes32 public constant CASE_ADMIN_ROLE = keccak256("CASE_ADMIN_ROLE");

    VRFCoordinatorV2Interface public immutable coordinator;
    bytes32 public immutable keyHash;
    uint64 public immutable subscriptionId;
    uint32 public constant CALLBACK_GAS_LIMIT = 200_000;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant NUM_WORDS = 1;

    SkinToken public immutable skinToken;
    CraftToken public immutable craftToken;

    // ─── Кейсы ────────────────────────────────────────────────
    struct Case {
        string name;
        uint256 price; // цена в CraftToken
        uint256[] skinIds; // какие скины могут выпасть
        uint256[] weights; // вес каждого скина (редкость)
        bool exists;
    }

    struct OpenRequest {
        address player;
        uint256 caseId;
        bool fulfilled;
    }

    mapping(uint256 => Case) public cases;
    uint256 public nextCaseId;

    // requestId => OpenRequest
    mapping(uint256 => OpenRequest) public openRequests;

    // Events
    event CaseCreated(uint256 indexed caseId, string name, uint256 price);
    event CaseOpenRequested(uint256 indexed requestId, address indexed player, uint256 caseId);
    event CaseOpened(uint256 indexed requestId, address indexed player, uint256 skinId);

    constructor(
        address admin,
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        address _skinToken,
        address _craftToken
    ) VRFConsumerBaseV2(vrfCoordinator) {
        coordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        skinToken = SkinToken(_skinToken);
        craftToken = CraftToken(_craftToken);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CASE_ADMIN_ROLE, admin);

        // Создаём стартовые кейсы
        uint256[] memory fractureSkins = new uint256[](3);
        fractureSkins[0] = 0; // AK-47 Redline     (Common)
        fractureSkins[1] = 3; // Glock Water Elem  (Rare)
        fractureSkins[2] = 1; // AWP Dragon Lore   (Legendary)

        uint256[] memory fractureWeights = new uint256[](3);
        fractureWeights[0] = 70; // 70% Common
        fractureWeights[1] = 25; // 25% Rare
        fractureWeights[2] = 5; // 5%  Legendary

        _createCase("Fracture Case", 100 * 10 ** 18, fractureSkins, fractureWeights);
    }

    /// @notice Создать новый кейс
    function createCase(string calldata name, uint256 price, uint256[] calldata skinIds, uint256[] calldata weights)
        external
        onlyRole(CASE_ADMIN_ROLE)
        returns (uint256)
    {
        return _createCase(name, price, skinIds, weights);
    }

    /// @notice Открыть кейс — сжигает CraftToken и запрашивает VRF
    function openCase(uint256 caseId) external nonReentrant returns (uint256 requestId) {
        Case storage c = cases[caseId];
        require(c.exists, "Case does not exist");

        // Checks-Effects-Interactions
        // 1. Checks
        require(craftToken.balanceOf(msg.sender) >= c.price, "Insufficient CRAFT balance");

        craftToken.burnFrom(msg.sender, c.price);

        // 3. Interactions — запрашиваем рандом у Chainlink
        requestId = coordinator.requestRandomWords(
            keyHash, subscriptionId, REQUEST_CONFIRMATIONS, CALLBACK_GAS_LIMIT, NUM_WORDS
        );

        openRequests[requestId] = OpenRequest({player: msg.sender, caseId: caseId, fulfilled: false});

        emit CaseOpenRequested(requestId, msg.sender, caseId);
    }

    /// @notice Chainlink вызывает эту функцию с рандомным числом
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        OpenRequest storage req = openRequests[requestId];
        require(!req.fulfilled, "Already fulfilled");

        req.fulfilled = true;
        Case storage c = cases[req.caseId];

        // Определяем выпавший скин по весам
        uint256 skinId = _selectSkin(c, randomWords[0]);

        // Минтим скин игроку
        skinToken.mint(req.player, skinId, 1);

        emit CaseOpened(requestId, req.player, skinId);
    }

    /// @notice Выбрать скин по рандомному числу и весам
    function _selectSkin(Case storage c, uint256 randomWord) internal view returns (uint256) {
        uint256 totalWeight;
        for (uint256 i = 0; i < c.weights.length; i++) {
            totalWeight += c.weights[i];
        }

        uint256 roll = randomWord % totalWeight;
        uint256 cumulative;

        for (uint256 i = 0; i < c.skinIds.length; i++) {
            cumulative += c.weights[i];
            if (roll < cumulative) {
                return c.skinIds[i];
            }
        }

        return c.skinIds[0];
    }

    function _createCase(string memory name, uint256 price, uint256[] memory skinIds, uint256[] memory weights)
        internal
        returns (uint256)
    {
        require(skinIds.length == weights.length, "Length mismatch");
        require(skinIds.length > 0, "No skins");

        uint256 caseId = nextCaseId++;
        cases[caseId] = Case({name: name, price: price, skinIds: skinIds, weights: weights, exists: true});

        emit CaseCreated(caseId, name, price);
        return caseId;
    }

    /// @notice Получить скины кейса
    function getCaseSkins(uint256 caseId) external view returns (uint256[] memory) {
        return cases[caseId].skinIds;
    }

    /// @notice Получить веса кейса
    function getCaseWeights(uint256 caseId) external view returns (uint256[] memory) {
        return cases[caseId].weights;
    }
}
