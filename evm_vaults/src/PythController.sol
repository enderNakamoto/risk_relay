// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MarketCreator.sol";

contract PythController is Ownable {

    IPyth pyth;
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

    
    constructor(address pythContract_) Ownable(msg.sender) {
        pyth = IPyth(pythContract_);
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
    
    function updateBTCPrice(bytes[] calldata priceUpdate) public payable {
        // Update the prices to the latest available values and pay the required fee for it. The `priceUpdateData` data
        // should be retrieved from our off-chain Price Service API using the `pyth-evm-js` package.
        // See section "How Pyth Works on EVM Chains" below for more information.
        uint fee = pyth.getUpdateFee(priceUpdate);
        pyth.updatePriceFeeds{ value: fee }(priceUpdate);
        // Read the current price from a price feed if it is less than 60 seconds old.
        // Each price feed (e.g., ETH/USD) is identified by a price feed ID.
        // The complete list of feed IDs is available at https://pyth.network/developers/price-feed-ids
        bytes32 priceFeedId = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43; // BTC/USD
        PythStructs.Price memory NewPrice = pyth.getPriceNoOlderThan(priceFeedId, 60);
        btcPrice = (uint256(uint64(NewPrice.price) * 10 ** 10));
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