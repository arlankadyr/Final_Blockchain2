pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SkinMarketAMM is ERC20, ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant AMM_ADMIN_ROLE = keccak256("AMM_ADMIN_ROLE");

    // ─── Токены пула ──────────────────────────────────────────
    IERC20 public immutable tokenA; // CraftToken
    IERC20 public immutable tokenB; // любой ERC20 (например WETH)

    // ─── Резервы ──────────────────────────────────────────────
    uint256 public reserveA;
    uint256 public reserveB;

    // ─── Константы ────────────────────────────────────────────
    uint256 public constant FEE_NUMERATOR = 997; // 0.3% fee
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    // Events
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address admin, address _tokenA, address _tokenB) ERC20("SkinMarket LP", "SMLP") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AMM_ADMIN_ROLE, admin);
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // ─── Add Liquidity ────────────────────────────────────────
    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLpTokens)
        external
        nonReentrant
        returns (uint256 lpTokens)
    {
        require(amountA > 0 && amountB > 0, "Zero amounts");

        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {
            // Первый провайдер
            lpTokens = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            // Минимальная ликвидность сжигается навсегда
            _mint(address(0xdead), MINIMUM_LIQUIDITY);
        } else {
            // Последующие провайдеры получают LP токены пропорционально
            uint256 lpFromA = (amountA * totalSupply) / reserveA;
            uint256 lpFromB = (amountB * totalSupply) / reserveB;
            lpTokens = lpFromA < lpFromB ? lpFromA : lpFromB;
        }

        require(lpTokens >= minLpTokens, "Insufficient LP tokens");
        require(lpTokens > 0, "Zero LP tokens");

        _mint(msg.sender, lpTokens);
        _updateReserves();

        emit LiquidityAdded(msg.sender, amountA, amountB, lpTokens);
    }

    // ─── Remove Liquidity ─────────────────────────────────────
    function removeLiquidity(uint256 lpTokens, uint256 minAmountA, uint256 minAmountB)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        require(lpTokens > 0, "Zero LP tokens");

        uint256 totalSupply = totalSupply();
        amountA = (lpTokens * reserveA) / totalSupply;
        amountB = (lpTokens * reserveB) / totalSupply;

        require(amountA >= minAmountA, "Insufficient A");
        require(amountB >= minAmountB, "Insufficient B");

        _burn(msg.sender, lpTokens);

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        _updateReserves();

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpTokens);
    }

    // ─── Swap A → B ───────────────────────────────────────────
    function swapAforB(uint256 amountIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Zero input");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        amountOut = _getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut >= minAmountOut, "Slippage exceeded");

        tokenA.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenB.safeTransfer(msg.sender, amountOut);

        _updateReserves();
        emit Swap(msg.sender, address(tokenA), amountIn, amountOut);
    }

    // ─── Swap B → A ───────────────────────────────────────────
    function swapBforA(uint256 amountIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Zero input");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        amountOut = _getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut >= minAmountOut, "Slippage exceeded");

        tokenB.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenA.safeTransfer(msg.sender, amountOut);

        _updateReserves();
        emit Swap(msg.sender, address(tokenB), amountIn, amountOut);
    }

    // ─── Quote ────────────────────────────────────────────────
    function getAmountOutAforB(uint256 amountIn) external view returns (uint256) {
        return _getAmountOut(amountIn, reserveA, reserveB);
    }

    function getAmountOutBforA(uint256 amountIn) external view returns (uint256) {
        return _getAmountOut(amountIn, reserveB, reserveA);
    }

    // ─── Internal ─────────────────────────────────────────────
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        require(reserveIn > 0 && reserveOut > 0, "No liquidity");
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        return numerator / denominator;
    }

    function _updateReserves() internal {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
