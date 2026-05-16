pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../tokens/SkinToken.sol";
import "../tokens/CraftToken.sol";

contract CraftingSystem is AccessControl, ReentrancyGuard {
    bytes32 public constant CRAFT_ADMIN_ROLE = keccak256("CRAFT_ADMIN_ROLE");

    SkinToken public immutable skinToken;
    CraftToken public immutable craftToken;

    // Рецепт крафта
    struct Recipe {
        uint256[] inputSkinIds; // какие скины нужны
        uint256[] inputAmounts; // сколько каждого
        uint256 craftTokenCost; // цена в CRAFT токенах
        uint256 outputSkinId; // что получается
        uint256 outputAmount; // сколько выдаём
        bool exists;
    }

    mapping(uint256 => Recipe) public recipes;
    uint256 public nextRecipeId;

    // Статистика
    uint256 public totalCrafts;

    // Events
    event RecipeCreated(uint256 indexed recipeId, uint256 outputSkinId);
    event SkinCrafted(address indexed player, uint256 indexed recipeId, uint256 outputSkinId, uint256 outputAmount);

    constructor(address admin, address _skinToken, address _craftToken) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CRAFT_ADMIN_ROLE, admin);
        skinToken = SkinToken(_skinToken);
        craftToken = CraftToken(_craftToken);

        // Стартовый рецепт: 3x AK-47 Redline → 1x Glock Water Elemental
        uint256[] memory inputIds = new uint256[](1);
        uint256[] memory inputAmts = new uint256[](1);
        inputIds[0] = 0; // AK-47 Redline
        inputAmts[0] = 3;

        _createRecipe(inputIds, inputAmts, 50 * 1e18, 3, 1);

        // Рецепт 2: 2x Glock Water Elemental → 1x AWP Dragon Lore
        uint256[] memory inputIds2 = new uint256[](1);
        uint256[] memory inputAmts2 = new uint256[](1);
        inputIds2[0] = 3; // Glock Water Elemental
        inputAmts2[0] = 2;

        _createRecipe(inputIds2, inputAmts2, 200 * 1e18, 1, 1);
    }

    /// @notice Создать новый рецепт крафта
    function createRecipe(
        uint256[] calldata inputSkinIds,
        uint256[] calldata inputAmounts,
        uint256 craftTokenCost,
        uint256 outputSkinId,
        uint256 outputAmount
    ) external onlyRole(CRAFT_ADMIN_ROLE) returns (uint256) {
        return _createRecipe(inputSkinIds, inputAmounts, craftTokenCost, outputSkinId, outputAmount);
    }

    /// @notice Скрафтить скин по рецепту
    function craft(uint256 recipeId) external nonReentrant {
        Recipe storage recipe = recipes[recipeId];
        require(recipe.exists, "Recipe does not exist");

        // ─── Checks ───────────────────────────────────────────
        // Проверяем баланс CRAFT токенов
        require(craftToken.balanceOf(msg.sender) >= recipe.craftTokenCost, "Insufficient CRAFT");

        // Проверяем наличие всех нужных скинов
        for (uint256 i = 0; i < recipe.inputSkinIds.length; i++) {
            require(
                skinToken.balanceOf(msg.sender, recipe.inputSkinIds[i]) >= recipe.inputAmounts[i],
                "Insufficient skin balance"
            );
        }

        // ─── Effects ──────────────────────────────────────────
        totalCrafts++;

        // ─── Interactions ─────────────────────────────────────
        // Сжигаем CRAFT токены
        craftToken.burnFrom(msg.sender, recipe.craftTokenCost);

        // Сжигаем входные скины
        for (uint256 i = 0; i < recipe.inputSkinIds.length; i++) {
            skinToken.burn(msg.sender, recipe.inputSkinIds[i], recipe.inputAmounts[i]);
        }

        // Минтим выходной скин
        skinToken.mint(msg.sender, recipe.outputSkinId, recipe.outputAmount);

        emit SkinCrafted(msg.sender, recipeId, recipe.outputSkinId, recipe.outputAmount);
    }

    /// @notice Получить рецепт
    function getRecipe(uint256 recipeId) external view returns (Recipe memory) {
        return recipes[recipeId];
    }

    /// @notice Проверить может ли игрок скрафтить
    function canCraft(address player, uint256 recipeId) external view returns (bool) {
        Recipe storage recipe = recipes[recipeId];
        if (!recipe.exists) return false;
        if (craftToken.balanceOf(player) < recipe.craftTokenCost) return false;

        for (uint256 i = 0; i < recipe.inputSkinIds.length; i++) {
            if (skinToken.balanceOf(player, recipe.inputSkinIds[i]) < recipe.inputAmounts[i]) {
                return false;
            }
        }
        return true;
    }

    // ─── Internal ─────────────────────────────────────────────
    function _createRecipe(
        uint256[] memory inputSkinIds,
        uint256[] memory inputAmounts,
        uint256 craftTokenCost,
        uint256 outputSkinId,
        uint256 outputAmount
    ) internal returns (uint256) {
        require(inputSkinIds.length == inputAmounts.length, "Length mismatch");
        require(inputSkinIds.length > 0, "No inputs");
        require(outputAmount > 0, "Zero output");

        uint256 recipeId = nextRecipeId++;
        recipes[recipeId] = Recipe({
            inputSkinIds: inputSkinIds,
            inputAmounts: inputAmounts,
            craftTokenCost: craftTokenCost,
            outputSkinId: outputSkinId,
            outputAmount: outputAmount,
            exists: true
        });

        emit RecipeCreated(recipeId, outputSkinId);
        return recipeId;
    }
}
