// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IMailbox} from "./interfaces/IMailbox.sol";
import {FtsoV2Interface} from "@flarenetwork/flare-periphery-contracts/coston2/FtsoV2Interface.sol";
import {IFeeCalculator} from "@flarenetwork/flare-periphery-contracts/coston2/IFeeCalculator.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MarketCreator.sol";

contract FlareController is Ownable {

    // HyperLane states
    IMailbox public mailbox;
    uint32 destinationChain;

    string public constant  CREATE = "create";
    string public constant  MATURE = "mature";
    string public constant  LIQUIDATE = "liquidate";


    // conroller states
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
    

    // Flare FTSO states
    FtsoV2Interface internal ftsoV2;
    IFeeCalculator internal feeCalc;
    bytes21[] public feedIds;
    uint256 public fee;
    // TestFtsoV2Interface internal ftsoV2;
    // Feed IDs, see https://dev.flare.network/ftso/feeds for full list
    bytes21 public btcUsdId = 0x014254432f55534400000000000000000000000000;

    // events
    event MarketInitialized(uint256 indexed marketId, uint256 maturityDate);
    event MarketMatured(uint256 indexed marketId);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketDelayed(uint256 indexed marketId);
    event MarketCreatorSet(address marketCreator);
    event Received(uint32, bytes32, uint, string);

    // errors
    error MarketNotFound();
    error MarketAlreadyMatured();
    error MarketAlreadyLiquidated();
    error ThresholdNotBreached();
    error MaturityDateNotPassed();
    error MaturityDateNotReached();
    error MarketAlreadyDelayed();
    error InvalidMaturityDate();

    constructor(
        address _ftsoV2, 
        address _feeCalc,
        address mailboxAddress,
        uint32 _destinationChain
        ) Ownable() {
        // market stuff 
        nextMarketId = 1; // Start from 1 instead of 0

        // Flare FTSO stuff
        // test only
        // ftsoV2 = ContractRegistry.getTestFtsoV2(); 
        ftsoV2 = FtsoV2Interface(_ftsoV2);
        feeCalc = IFeeCalculator(_feeCalc);
        feedIds.push(btcUsdId);

        // HyperLane stuff
        mailbox = IMailbox(mailboxAddress);
        destinationChain = _destinationChain;
    }

    function setMarketCreator(address newMarketCreator) external onlyOwner {
        require(newMarketCreator != address(0), "Invalid market creator address");
                
        marketCreator = MarketCreator(newMarketCreator);
        emit MarketCreatorSet(newMarketCreator);
    }

    function checkFees() external returns (uint256 _fee) {
        fee = feeCalc.calculateFeeByIds(feedIds);
        return fee;
    }

    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // alignment preserving cast
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }
    
    function initializeMarket(uint256 maturityDate, uint256 threshold) 
        external
        payable
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

        mailbox.dispatch{value: msg.value}(
            destinationChain,
            addressToBytes32(address(marketCreator)),
            bytes(abi.encode(CREATE, marketId)
        ));

        emit MarketInitialized(marketId, maturityDate);
        return marketId;
    }

    function mature(uint256 marketId) external payable {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.matured) revert MarketAlreadyMatured();
        if (market.liquidated) revert MarketAlreadyLiquidated();
        if (block.timestamp < market.maturityDate) revert MaturityDateNotPassed();

        market.matured = true;
        
        // Execute maturity on market creator
        // marketCreator.controllerMature(marketId);

        mailbox.dispatch{value: msg.value}(
            destinationChain,
            addressToBytes32(address(marketCreator)),
            bytes(abi.encode(MATURE, marketId)
        ));
        
        emit MarketMatured(marketId);
    }

    function liquidate(uint256 marketId) external payable {
        MarketState storage market = markets[marketId];
        
        if (market.maturityDate == 0) revert MarketNotFound();
        if (market.liquidated) revert MarketAlreadyLiquidated();
        if (market.threshold <= btcPrice) revert ThresholdNotBreached();
        if (block.timestamp >= market.maturityDate) revert MaturityDateNotReached();

        market.liquidated = true;
        
        // Execute liquidation on market creator
        // marketCreator.controllerLiquidate(marketId);

        mailbox.dispatch{value: msg.value}(
            destinationChain,
            addressToBytes32(address(marketCreator)),
            bytes(abi.encode(LIQUIDATE, marketId)
        ));
        
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

    function updateBtcUsdPrice() external payable returns (uint256, int8, uint64) {
        (uint256 feedValue, int8 decimals, uint64 timestamp) = ftsoV2
            .getFeedById{value: msg.value}(btcUsdId);

        btcPrice = feedValue;    
        return (feedValue, decimals, timestamp);
    }

}