pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../tokens/CraftToken.sol";

/// @notice Vault где владельцы скинов депозитят CRAFT токены
/// и получают shares пропорционально вкладу.
/// Арендаторы платят CRAFT → доход делится между депозиторами.
contract RentalVault is ERC4626, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");

    CraftToken public immutable craftToken;

    // Накопленный доход от аренды
    uint256 public totalRentalIncome;

    // Активные аренды
    struct Rental {
        address renter;
        uint256 skinId;
        uint256 startTime;
        uint256 endTime;
        uint256 pricePerDay; // в CRAFT
        bool active;
    }

    mapping(uint256 => Rental) public rentals;
    uint256 public nextRentalId;

    // Events
    event RentalStarted(uint256 indexed rentalId, address indexed renter, uint256 skinId, uint256 endTime);
    event RentalEnded(uint256 indexed rentalId, address indexed renter);
    event RentalIncomeAdded(uint256 amount);

    constructor(
        address admin,
        address _craftToken
    ) ERC4626(IERC20(_craftToken))
      ERC20("Rental Vault Share", "rvCRAFT")
    {
        craftToken = CraftToken(_craftToken);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_ADMIN_ROLE, admin);
    }

    /// @notice Арендовать скин — платишь CRAFT, аренда на N дней
    function rentSkin(
        uint256 skinId,
        uint256 days_,
        uint256 pricePerDay
    ) external nonReentrant returns (uint256 rentalId) {
        require(days_ > 0, "Zero days");
        require(pricePerDay > 0, "Zero price");

        uint256 totalCost = pricePerDay * days_;

        // Checks-Effects-Interactions
        rentalId = nextRentalId++;
        rentals[rentalId] = Rental({
            renter: msg.sender,
            skinId: skinId,
            startTime: block.timestamp,
            endTime: block.timestamp + (days_ * 1 days),
            pricePerDay: pricePerDay,
            active: true
        });

        totalRentalIncome += totalCost;

        // Берём оплату с арендатора
        craftToken.burnFrom(msg.sender, totalCost);

        emit RentalStarted(rentalId, msg.sender, skinId, rentals[rentalId].endTime);
    }

    /// @notice Завершить аренду
    function endRental(uint256 rentalId) external nonReentrant {
        Rental storage rental = rentals[rentalId];
        require(rental.active, "Rental not active");
        require(
            msg.sender == rental.renter || hasRole(VAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );

        rental.active = false;
        emit RentalEnded(rentalId, rental.renter);
    }

    /// @notice Добавить доход в vault (вызывает admin или протокол)
    function addRentalIncome(uint256 amount) external onlyRole(VAULT_ADMIN_ROLE) {
        require(amount > 0, "Zero amount");
        craftToken.transferFrom(msg.sender, address(this), amount);
        emit RentalIncomeAdded(amount);
    }

    /// @notice Проверить активна ли аренда
    function isRentalActive(uint256 rentalId) external view returns (bool) {
        Rental storage rental = rentals[rentalId];
        return rental.active && block.timestamp <= rental.endTime;
    }

    /// @notice Получить информацию об аренде
    function getRental(uint256 rentalId) external view returns (Rental memory) {
        return rentals[rentalId];
    }

    // ─── ERC-4626 overrides ───────────────────────────────────
    function totalAssets() public view override returns (uint256) {
        return craftToken.balanceOf(address(this));
    }

    // ─── Required overrides ───────────────────────────────────
    function supportsInterface(bytes4 interfaceId)
        public view override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}