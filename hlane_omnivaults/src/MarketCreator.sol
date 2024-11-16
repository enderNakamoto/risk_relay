// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMailbox} from "./interfaces/IMailbox.sol";
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
    event Received(uint32, bytes32, uint, string);

    error VaultsNotFound();
    error NotController();
    
    modifier onlyController() {
        if (msg.sender != controller) revert NotController();
        _;
    }
    
    constructor(address controller_, address asset_) {
        require(controller_ != address(0), "Invalid controller address");
        require(asset_ != address(0), "Invalid asset address");
        controller = controller_;
        asset = IERC20(asset_);
        nextMarketId = 1;
    }


    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // alignment preserving cast
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data
    ) external payable returns(string memory, uint32) {
        emit Received(_origin, _sender, msg.value, string(_data));
        // Route Actions
        // Liquidate
        // Mature
        // Create Market
        return (string(_data), _origin);
    }

    function controllerLiquidate(uint256 marketId) external onlyController {
        MarketVaults memory vaults = marketVaults[marketId];
        if (vaults.riskVault == address(0)) revert VaultsNotFound();
        
        // Get total assets in Risk Vault
        uint256 riskAssets = IERC20(asset).balanceOf(vaults.riskVault);
        
        // Move all assets from Risk to Hedge vault
        if (riskAssets > 0) {
            RiskVault(vaults.riskVault).transferAssets(vaults.hedgeVault, riskAssets);
        }
    }

    function controllerMature(uint256 marketId) external onlyController {
        MarketVaults memory vaults = marketVaults[marketId];
        if (vaults.riskVault == address(0)) revert VaultsNotFound();
        
        // Get total assets in Hedge Vault
        uint256 hedgeAssets = IERC20(asset).balanceOf(vaults.hedgeVault);
        
        // Move all assets from Hedge to Risk vault
        if (hedgeAssets > 0) {
            HedgeVault(vaults.hedgeVault).transferAssets(vaults.riskVault, hedgeAssets);
        }
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
        if (vaults.riskVault == address(0)) revert VaultsNotFound();
        return (vaults.riskVault, vaults.hedgeVault);
    }
}