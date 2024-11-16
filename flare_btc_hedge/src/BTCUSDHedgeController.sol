// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// test imports (not for production)
import {ContractRegistry} from "@flarenetwork/flare-periphery-contracts/coston2/ContractRegistry.sol";
import {TestFtsoV2Interface} from "@flarenetwork/flare-periphery-contracts/coston2/TestFtsoV2Interface.sol";

import { OApp, Origin, MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
// import {OAppSender, MessagingFee} from "layerzero-v2/oapp/contracts/oapp/OAppSender.sol";


contract BTCUSDHedgeController is OApp {
    // conroller states
    struct MarketState {
        bool matured;
        uint256 maturityDate;
        uint256 threshold;
        bool liquidated;
    }

    uint256 private nextMarketId;
    uint256 public btcPrice;
    mapping(uint256 => MarketState) public markets;

    // LayerZero OApp states
    string public data;

    // Flare FTSO states
    TestFtsoV2Interface internal ftsoV2;
    // Feed IDs, see https://dev.flare.network/ftso/feeds for full list
    bytes21 public btcUsdId = 0x014254432f55534400000000000000000000000000;


    // events
    event MarketInitialized(uint256 indexed marketId, uint256 maturityDate);
    event MarketMatured(uint256 indexed marketId);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketDelayed(uint256 indexed marketId);

    // errors
    error MarketNotFound();
    error MarketAlreadyMatured();
    error MarketAlreadyLiquidated();
    error ThresholdNotBreached();
    error MaturityDateNotPassed();
    error MaturityDateNotReached();
    error MarketAlreadyDelayed();
    error InvalidMaturityDate();

    constructor(address _endpoint) OApp(_endpoint, msg.sender){
        // market stuff 
        nextMarketId = 1; // Start from 1 instead of 0

        // Flare FTSO stuff
        ftsoV2 = ContractRegistry.getTestFtsoV2(); // test only

        // LayerZero OApp stuff

    }

    function initializeMarket(uint256 maturityDate, uint256 threshold) external returns (uint256 marketId) {
        if (maturityDate <= block.timestamp) revert InvalidMaturityDate();
        
        marketId = nextMarketId++;

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
        // send message to mature
        emit MarketMatured(marketId);
    }

    function liquidate(uint256 marketId) external {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.liquidated) revert MarketAlreadyLiquidated();
        if (market.threshold <= btcPrice) revert ThresholdNotBreached();
        if (block.timestamp >= market.maturityDate) revert MaturityDateNotReached();

        market.liquidated = true;
        // send message to liquidate
        emit MarketLiquidated(marketId);
    }

    // View function to get full market state
    function getMarketState(uint256 marketId) external view returns (MarketState memory) {
        return markets[marketId];
    }

    // View function to get current market count
    function getCurrentMarketId() external view returns (uint256) {
        return nextMarketId - 1;
    }

    function updateBtcUsdPrice() external returns (uint256, int8, uint64) {
        (uint256 feedValue, int8 decimals, uint64 timestamp) = ftsoV2
            .getFeedById(btcUsdId);

        btcPrice = feedValue;    
        return (feedValue, decimals, timestamp);
    }


    // LayerZero OApp functions
    function sendMessage(uint32 _dstEid, string memory _message, bytes calldata _options) external payable {
     bytes memory _payload = abi.encode(_message); // Encode the message as bytes
     _lzSend(
           _dstEid,
           _payload,
           _options,
           MessagingFee(msg.value, 0), // Fee for the message (nativeFee, lzTokenFee)
           payable(msg.sender) // The refund address in case the send call reverts
     );
    }

    // function estimateFee(
    //  uint32 _dstEid,
    //  string memory _message,
    //  bytes calldata _options
    // ) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
    //     bytes memory _payload = abi.encode(_message);
    //     MessagingFee memory fee = _quote(_dstEid, _payload, _options, false);
    //     return (fee.nativeFee, fee.lzTokenFee);
    // }

    function _lzReceive(
     Origin calldata _origin,
     bytes32 _guid,
     bytes calldata payload,
     address _executor,
     bytes calldata _extraData
    ) internal override {
        data = abi.decode(payload, (string));
    }

}