# CS:GO Skin Economy — Blockchain Final Project

A GameFi protocol built on Arbitrum Sepolia simulating a CS:GO-style skin economy.

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address |
|---|---|
| CraftToken | [0x5F1d9B13F7E4a7D788CD1DB8443E712729525F87](https://sepolia.arbiscan.io/address/0x5F1d9B13F7E4a7D788CD1DB8443E712729525F87) |
| SkinToken | [0x36Ecc0242CF19B9d2FD13a79a3615fef884645FD](https://sepolia.arbiscan.io/address/0x36Ecc0242CF19B9d2FD13a79a3615fef884645FD) |
| SkinFactory | [0xBFB4aE681DEd4b104Dd7782C95C95380880063de](https://sepolia.arbiscan.io/address/0xBFB4aE681DEd4b104Dd7782C95C95380880063de) |
| SkinTimelock | [0x2Ce682690597FEa387C34D364578400f39a4F648](https://sepolia.arbiscan.io/address/0x2Ce682690597FEa387C34D364578400f39a4F648) |
| SkinGovernor | [0x270c9d73CDFD8c2341Ba8FD1461Af093DC145b8d](https://sepolia.arbiscan.io/address/0x270c9d73CDFD8c2341Ba8FD1461Af093DC145b8d) |
| CaseOpening | [0x5C4195840127243aa57D80CFb5eC89F54E438025](https://sepolia.arbiscan.io/address/0x5C4195840127243aa57D80CFb5eC89F54E438025) |
| SkinMarketAMM | [0x60DC2A02E2e03E14b17816Fc0338779839EE1ee3](https://sepolia.arbiscan.io/address/0x60DC2A02E2e03E14b17816Fc0338779839EE1ee3) |
| RentalVault | [0x7a11D85bcFC156a8ec7D96aBDd21dB0050D10860](https://sepolia.arbiscan.io/address/0x7a11D85bcFC156a8ec7D96aBDd21dB0050D10860) |
| SkinPriceOracle | [0xce77e59d8446a791A9Aa76907BbE6c4Cfb9E99CB](https://sepolia.arbiscan.io/address/0xce77e59d8446a791A9Aa76907BbE6c4Cfb9E99CB) |
| CraftingSystem | [0xFDe973d41894462FD7B4AB79Abc26fB513E741bA](https://sepolia.arbiscan.io/address/0xFDe973d41894462FD7B4AB79Abc26fB513E741bA) |

## Architecture

- **CraftToken** — ERC20Votes + ERC20Permit governance and resource token
- **SkinToken** — ERC-1155 skin NFTs (Common / Rare / Legendary)
- **SkinFactory** — Deploys skin collections via CREATE and CREATE2
- **CaseOpening** — Chainlink VRF random loot drops
- **SkinMarketAMM** — x*y=k AMM with 0.3% fee and LP tokens
- **CraftingSystem** — Burn skins + CRAFT tokens to craft rarer skins
- **RentalVault** — ERC-4626 vault for skin rentals
- **SkinPriceOracle** — Chainlink ETH/USD price feed with staleness check
- **SkinGovernor** — OpenZeppelin Governor with 4% quorum, 1 week voting
- **SkinTimelock** — 2-day timelock for governance actions

## Test Results

- Total tests: 135 passing
- Coverage: 92%
- Unit tests: 50+
- Fuzz tests: 10+
- Invariant tests: 5
- Fork tests: 4

## Setup

```bash
git clone <repo>
cd skin-protocol
forge install
forge build
forge test
```

## Deploy

```bash
source .env
forge script script/Deploy.s.sol \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY
```
