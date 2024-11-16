// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MarketCreator.sol";

interface IChronicle {
    function read() external view returns (uint256 value);
    function readWithAge() external view returns (uint256 value, uint256 age);
}

interface ISelfKisser {
    function selfKiss(address oracle) external;
}

contract ChronicleController is Ownable {

    // Base Chain Values 
    IChronicle public chronicle = IChronicle(address(0x8E947Ea7D5881Cd600Ace95F1201825F8C708844));
    ISelfKisser public selfKisser = ISelfKisser(address(0x70E58b7A1c884fFFE7dbce5249337603a28b8422));

    MarketCreator public marketCreator;
    struct MarketState {
        bool matured;
        uint256 maturityDate;
        uint256 threshold;
        bool liquidated;
    }

    uint256 private nextMarketId;
    uint256 public btcPrice;
    mapping(uint256 => MarketState) public markets;
    
    error InvalidMaturityDate();
    error MarketNotFound();
    error MarketAlreadyMatured();
    error MarketAlreadyLiquidated();
    error MaturityDateNotPassed();
    error MaturityDateNotReached();
    error ThresholdNotBreached();
    
    event MarketInitialized(uint256 indexed marketId, uint256 maturityDate);
    event MarketMatured(uint256 indexed marketId);
    event MarketLiquidated(uint256 indexed marketId);
    event BTCPriceUpdated(uint256 price);
    event MarketCreatorSet(address marketCreator);

    
    constructor() Ownable(msg.sender) {
        // only works in testnet
        selfKisser.selfKiss(address(chronicle));
    }

    function setMarketCreator(address newMarketCreator) external onlyOwner {
        require(newMarketCreator != address(0), "Invalid market creator address");
                
        marketCreator = MarketCreator(newMarketCreator);
        emit MarketCreatorSet(newMarketCreator);
    }

    function initializeMarket(uint256 maturityDate, uint256 threshold) 
        external 
        returns (uint256 marketId) 
    {
        if (maturityDate <= block.timestamp) revert InvalidMaturityDate();
        
        // Create vaults first
        (marketId, , ) = marketCreator.createMarketVaults();
        
        // Initialize market state
        markets[marketId] = MarketState({
            matured: false,
            maturityDate: maturityDate,
            threshold: threshold,
            liquidated: false
        });

        emit MarketInitialized(marketId, maturityDate);
        return marketId;
    }

    function mature(uint256 marketId) external {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.matured) revert MarketAlreadyMatured();
        if (market.liquidated) revert MarketAlreadyLiquidated();
        if (block.timestamp < market.maturityDate) revert MaturityDateNotPassed();

        market.matured = true;
        
        // Execute maturity on market creator
        marketCreator.controllerMature(marketId);
        
        emit MarketMatured(marketId);
    }

    function liquidate(uint256 marketId) external {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.liquidated) revert MarketAlreadyLiquidated();
        if (market.threshold <= btcPrice) revert ThresholdNotBreached();
        if (block.timestamp >= market.maturityDate) revert MaturityDateNotReached();

        market.liquidated = true;
        
        // Execute liquidation on market creator
        marketCreator.controllerLiquidate(marketId);
        
        emit MarketLiquidated(marketId);
    }
    
    function updateBTCPrice() external returns (uint256 val, uint256 age) {
        (val, age) = chronicle.readWithAge();
        btcPrice = val;
        emit BTCPriceUpdated(btcPrice);
    }
    
    // View functions
    function getMarketState(uint256 marketId) 
        external 
        view 
        returns (
            bool matured,
            uint256 maturityDate,
            uint256 threshold,
            bool liquidated
        ) 
    {
        MarketState memory market = markets[marketId];
        return (
            market.matured,
            market.maturityDate,
            market.threshold,
            market.liquidated
        );
    }
    
    function getCurrentPrice() external view returns (uint256) {
        return btcPrice;
    }
}