// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MarketController {
    struct MarketState {
        bool matured;
        uint256 maturityDate;
        bool delayed;
        bool liquidated;
    }

    uint256 private nextMarketId;
    mapping(uint256 => MarketState) public markets;

    event MarketInitialized(uint256 indexed marketId, uint256 maturityDate);
    event MarketMatured(uint256 indexed marketId);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketDelayed(uint256 indexed marketId);

    error MarketNotFound();
    error MarketAlreadyMatured();
    error MarketAlreadyLiquidated();
    error MarketNotDelayed();
    error MaturityDateNotPassed();
    error MaturityDateNotReached();
    error MarketAlreadyDelayed();
    error InvalidMaturityDate();

    constructor() {
        nextMarketId = 1; // Start from 1 instead of 0
    }

    function initializeMarket(uint256 maturityDate) external returns (uint256 marketId) {
        if (maturityDate <= block.timestamp) revert InvalidMaturityDate();
        
        marketId = nextMarketId++;

        markets[marketId] = MarketState({
            matured: false,
            maturityDate: maturityDate,
            delayed: false,
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
        emit MarketMatured(marketId);
    }

    function liquidate(uint256 marketId) external {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.liquidated) revert MarketAlreadyLiquidated();
        if (!market.delayed) revert MarketNotDelayed();
        if (block.timestamp >= market.maturityDate) revert MaturityDateNotReached();

        market.liquidated = true;
        emit MarketLiquidated(marketId);
    }

    function setDelayed(uint256 marketId) external {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.delayed) revert MarketAlreadyDelayed();

        market.delayed = true;
        emit MarketDelayed(marketId);
    }

    // View function to get full market state
    function getMarketState(uint256 marketId) external view returns (MarketState memory) {
        return markets[marketId];
    }

    // View function to get current market count
    function getCurrentMarketId() external view returns (uint256) {
        return nextMarketId - 1;
    }
}