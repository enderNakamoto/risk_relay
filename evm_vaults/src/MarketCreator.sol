// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./vaults/RiskVault.sol";
import "./vaults/HedgeVault.sol";

contract MarketCreator {
    address public immutable controller;
    IERC20 public immutable asset;
    
    uint256 private nextMarketId;
    
    mapping(uint256 => MarketVaults) public marketVaults;
    
    struct MarketVaults {
        address riskVault;
        address hedgeVault;
    }
    
    event MarketVaultsCreated(
        uint256 indexed marketId,
        address indexed riskVault,
        address indexed hedgeVault
    );
    
    constructor(address controller_, address asset_) {
        require(controller_ != address(0), "Invalid controller address");
        require(asset_ != address(0), "Invalid asset address");
        controller = controller_;
        asset = IERC20(asset_);
        nextMarketId = 1;
    }
    
    function createMarketVaults() 
        external 
        returns (
            uint256 marketId,
            address riskVault,
            address hedgeVault
        ) 
    {
        marketId = nextMarketId++;
        
        // Deploy Hedge vault first
        HedgeVault hedge = new HedgeVault(
            asset,
            controller,
            marketId
        );
        
        hedgeVault = address(hedge);
        
        // Deploy Risk vault with Hedge vault address
        RiskVault risk = new RiskVault(
            asset,
            controller,
            hedgeVault,
            marketId
        );
        
        riskVault = address(risk);
        
        // Set sister vault in Hedge vault
        hedge.setSisterVault(riskVault);
        
        // Store vault addresses
        marketVaults[marketId] = MarketVaults({
            riskVault: riskVault,
            hedgeVault: hedgeVault
        });
        
        emit MarketVaultsCreated(marketId, riskVault, hedgeVault);
        
        return (marketId, riskVault, hedgeVault);
    }
    
    function getVaults(uint256 marketId) 
        external 
        view 
        returns (
            address riskVault,
            address hedgeVault
        ) 
    {
        MarketVaults memory vaults = marketVaults[marketId];
        require(vaults.riskVault != address(0), "Market does not exist");
        return (vaults.riskVault, vaults.hedgeVault);
    }
}