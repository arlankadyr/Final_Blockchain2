// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/tokens/CraftToken.sol";
import "../src/tokens/SkinToken.sol";
import "../src/core/SkinFactory.sol";
import "../src/core/CaseOpening.sol";
import "../src/core/SkinMarketAMM.sol";
import "../src/core/CraftingSystem.sol";
import "../src/vault/RentalVault.sol";
import "../src/oracle/SkinPriceOracle.sol";
import "../src/governance/SkinGovernor.sol";
import "../src/governance/SkinTimelock.sol";

contract Deploy is Script {
    // Arbitrum Sepolia Chainlink ETH/USD
    address constant ETH_USD_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

    // Arbitrum Sepolia Chainlink VRF
    address constant VRF_COORDINATOR = 0x50d47e4142598E3411aA864e08a44284e471AC6f;
    bytes32 constant KEY_HASH = 0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae0ef3f58e15c0d2df;
    uint64  constant SUBSCRIPTION_ID = 1; // замени на свой sub ID

    // Arbitrum Sepolia WETH
    address constant WETH = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. CraftToken (governance + resource token)
        CraftToken craftToken = new CraftToken(deployer);
        console.log("CraftToken:", address(craftToken));

        // 2. SkinToken (ERC-1155 skins)
        SkinToken skinToken = new SkinToken(deployer);
        console.log("SkinToken:", address(skinToken));

        // 3. SkinFactory (CREATE + CREATE2)
        SkinFactory factory = new SkinFactory(deployer);
        console.log("SkinFactory:", address(factory));

        // 4. Timelock (2 days delay)
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = deployer;
        executors[0] = address(0);
        SkinTimelock timelock = new SkinTimelock(2 days, proposers, executors, deployer);
        console.log("SkinTimelock:", address(timelock));

        // 5. SkinGovernor
        SkinGovernor governor = new SkinGovernor(
            IVotes(address(craftToken)),
            timelock
        );
        console.log("SkinGovernor:", address(governor));

        // 6. Setup Timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(),  address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        craftToken.grantRole(craftToken.MINTER_ROLE(), address(timelock));

        // 7. CaseOpening (Chainlink VRF)
        CaseOpening caseOpening = new CaseOpening(
            deployer,
            VRF_COORDINATOR,
            KEY_HASH,
            SUBSCRIPTION_ID,
            address(skinToken),
            address(craftToken)
        );
        console.log("CaseOpening:", address(caseOpening));

        // 8. SkinMarketAMM
        SkinMarketAMM amm = new SkinMarketAMM(
            deployer,
            address(craftToken),
            WETH
        );
        console.log("SkinMarketAMM:", address(amm));

        // 9. RentalVault (ERC-4626)
        RentalVault vault = new RentalVault(deployer, address(craftToken));
        console.log("RentalVault:", address(vault));

        // 10. SkinPriceOracle (Chainlink)
        SkinPriceOracle oracle = new SkinPriceOracle(
            deployer,
            ETH_USD_FEED,
            3600
        );
        console.log("SkinPriceOracle:", address(oracle));

        // 11. CraftingSystem
        CraftingSystem crafting = new CraftingSystem(
            deployer,
            address(skinToken),
            address(craftToken)
        );
        console.log("CraftingSystem:", address(crafting));

        // 12. Setup roles
        skinToken.grantRole(skinToken.MINTER_ROLE(), address(caseOpening));
        skinToken.grantRole(skinToken.MINTER_ROLE(), address(crafting));
        craftToken.grantRole(craftToken.MINTER_ROLE(), address(deployer));

        // 13. Устанавливаем цены скинов в оракуле
        oracle.setSkinPrice(0, 50  * 1e18);  // AK-47 $50
        oracle.setSkinPrice(1, 5000 * 1e18); // AWP Dragon Lore $5000
        oracle.setSkinPrice(2, 3000 * 1e18); // M4A4 Howl $3000
        oracle.setSkinPrice(3, 200  * 1e18); // Glock $200
        oracle.setSkinPrice(4, 150  * 1e18); // USP $150

        vm.stopBroadcast();

        // Выводим все адреса
        console.log("\n=== DEPLOYED ADDRESSES ===");
        console.log("CraftToken:    ", address(craftToken));
        console.log("SkinToken:     ", address(skinToken));
        console.log("SkinFactory:   ", address(factory));
        console.log("SkinTimelock:  ", address(timelock));
        console.log("SkinGovernor:  ", address(governor));
        console.log("CaseOpening:   ", address(caseOpening));
        console.log("SkinMarketAMM: ", address(amm));
        console.log("RentalVault:   ", address(vault));
        console.log("SkinPriceOracle:", address(oracle));
        console.log("CraftingSystem: ", address(crafting));
    }
}