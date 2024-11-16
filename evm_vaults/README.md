# EVM Vaults and VaultCreator

## Directory Structure

```
risk-markets/
├── lib/
├── src/
│   ├── MarketCreator.sol
│   └── vaults/
│       ├── RiskVault.sol
│       └── HedgeVault.sol
├── test/
│   ├── MarketCreator.t.sol
│   ├── HedgeVault.t.sol 
│   ├── RiskVault.t.sol
│   └── mocks/
│       └── MockToken.sol
└── foundry.toml
```

## Risk Markets Contracts

This is a Solidity-based project that implements a decentralized risk markets system. The system consists of three main components:

* **MarketCreator**: This contract is responsible for creating and managing risk and hedge vaults for each market.
* **RiskVault**: This contract represents the "risk" side of a market, where users can deposit funds to take on risk.
* **HedgeVault**: This contract represents the "hedge" side of a market, where users can deposit funds to hedge against the risks.

### Architecture Overview

The architecture of this project is designed to facilitate the creation and management of risk markets, where users can take on or hedge against various types of risks.

#### MarketCreator

The `MarketCreator` contract is the entry point for the system. It has the following responsibilities:

1. **Market Creation**: The `createMarketVaults()` function allows the creation of a new risk and hedge vault pair for a given market.

2. **Market Lookup**: The `getVaults()` function allows retrieving the addresses of the risk and hedge vaults for a given market.

The `MarketCreator` contract maintains a mapping of market IDs to the corresponding risk and hedge vault addresses.

#### RiskVault and HedgeVault

The `RiskVault` and `HedgeVault` contracts represent the "risk" and "hedge" sides of a market, respectively. They share a similar structure and functionality:

1. **Deposit and Withdrawal**: Users can deposit funds into the vaults and withdraw their shares later.

2. **Asset Transfer**: The vaults can only transfer assets to their "sister" vault, as controlled by the MarketCreator contract.

3. **Ownership**: The HedgeVault contract has an owner, which is the MarketCreator contract.

The vaults inherit from the **ERC4626** standard, which provides a standard interface for tokenized vaults.

The tests provided in the project demonstrate the expected usage and behavior of the system.


## With Pyth Controller - Pyth as Price Oracle
- Mantle, Morph , Linea 

```mermaid
    %% Control flows
    PC --> |Liquidate/Mature| MC
    MC --> |Transfer assets| HV
    MC --> |Transfer assets| RV
    HV <--> |Sister vault transfers| RV
    
    %% Oracle interaction
    PYTH --> |BTC Price Updates| PC
    
    %% Additional annotations
    classDef controller fill:#f96
    classDef vault fill:#9cf
    classDef external fill:#fcf
    
    class PC controller
    class HV,RV vault
    class PYTH,USDC external
    
    %% Add notes
    note1[Price feeds for<br>liquidation conditions]
    note2[Vault pair for each market]
    note3[Asset transfers during<br>liquidation/maturity]
    
    PYTH --> note1
    MC --> note2
    HV --> note3
    RV --> note3
   ``` 