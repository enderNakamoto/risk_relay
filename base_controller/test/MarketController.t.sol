// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketController.sol";

contract MarketControllerTest is Test {
    MarketController public controller;
    uint256 public maturityDate;

    event MarketInitialized(uint256 indexed marketId, uint256 maturityDate);
    event MarketMatured(uint256 indexed marketId);
    event MarketLiquidated(uint256 indexed marketId);
    event MarketDelayed(uint256 indexed marketId);

    function setUp() public {
        controller = new MarketController();
        maturityDate = block.timestamp + 1 days;
    }

    function test_InitializeMarket() public {
        vm.expectEmit(true, false, false, true);
        emit MarketInitialized(1, maturityDate);
        
        uint256 marketId = controller.initializeMarket(maturityDate);
        assertEq(marketId, 1, "First market should have ID 1");
        
        MarketController.MarketState memory state = controller.getMarketState(marketId);
        assertEq(state.matured, false);
        assertEq(state.maturityDate, maturityDate);
        assertEq(state.delayed, false);
        assertEq(state.liquidated, false);
    }

    function test_MarketIdIncrement() public {
        uint256 firstId = controller.initializeMarket(maturityDate);
        uint256 secondId = controller.initializeMarket(maturityDate + 1 days);
        uint256 thirdId = controller.initializeMarket(maturityDate + 2 days);
        
        assertEq(firstId, 1, "First market should be ID 1");
        assertEq(secondId, 2, "Second market should be ID 2");
        assertEq(thirdId, 3, "Third market should be ID 3");
        assertEq(controller.getCurrentMarketId(), 3, "Current market ID should be 3");
    }

    function test_CannotInitializeWithPastMaturity() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidMaturityDate()"));
        controller.initializeMarket(block.timestamp - 1);
    }

    function test_Mature() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        
        // Move time past maturity
        vm.warp(maturityDate + 1);
        
        vm.expectEmit(true, false, false, false);
        emit MarketMatured(marketId);
        
        controller.mature(marketId);
        
        MarketController.MarketState memory state = controller.getMarketState(marketId);
        assertTrue(state.matured);
    }

    function test_CannotMatureBeforeMaturity() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        
        vm.expectRevert(abi.encodeWithSignature("MaturityDateNotPassed()"));
        controller.mature(marketId);
    }

    function test_CannotMatureLiquidatedMarket() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        
        // Set delayed and liquidate
        controller.setDelayed(marketId);
        controller.liquidate(marketId);
        
        // Move time past maturity
        vm.warp(maturityDate + 1);
        
        vm.expectRevert(abi.encodeWithSignature("MarketAlreadyLiquidated()"));
        controller.mature(marketId);
    }

    function test_Liquidate() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        controller.setDelayed(marketId);
        
        vm.expectEmit(true, false, false, false);
        emit MarketLiquidated(marketId);
        
        controller.liquidate(marketId);
        
        MarketController.MarketState memory state = controller.getMarketState(marketId);
        assertTrue(state.liquidated);
    }

    function test_CannotLiquidateAfterMaturity() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        controller.setDelayed(marketId);
        
        // Move time past maturity
        vm.warp(maturityDate + 1);
        
        vm.expectRevert(abi.encodeWithSignature("MaturityDateNotReached()"));
        controller.liquidate(marketId);
    }

    function test_CannotLiquidateWithoutDelay() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        
        vm.expectRevert(abi.encodeWithSignature("MarketNotDelayed()"));
        controller.liquidate(marketId);
    }

    function test_SetDelayed() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        
        vm.expectEmit(true, false, false, false);
        emit MarketDelayed(marketId);
        
        controller.setDelayed(marketId);
        
        MarketController.MarketState memory state = controller.getMarketState(marketId);
        assertTrue(state.delayed);
    }

    function test_CannotSetDelayedTwice() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        controller.setDelayed(marketId);
        
        vm.expectRevert(abi.encodeWithSignature("MarketAlreadyDelayed()"));
        controller.setDelayed(marketId);
    }

    function test_NonExistentMarket() public {
        uint256 nonExistentId = 999;
        
        vm.expectRevert(abi.encodeWithSignature("MarketNotFound()"));
        controller.mature(nonExistentId);
        
        vm.expectRevert(abi.encodeWithSignature("MarketNotFound()"));
        controller.liquidate(nonExistentId);
        
        vm.expectRevert(abi.encodeWithSignature("MarketNotFound()"));
        controller.setDelayed(nonExistentId);
    }

    function test_FullLifecycle() public {
        uint256 marketId = controller.initializeMarket(maturityDate);
        
        // Initial state
        MarketController.MarketState memory state = controller.getMarketState(marketId);
        assertFalse(state.delayed);
        assertFalse(state.liquidated);
        assertFalse(state.matured);
        
        // Set delayed
        controller.setDelayed(marketId);
        state = controller.getMarketState(marketId);
        assertTrue(state.delayed);
        
        // Liquidate
        controller.liquidate(marketId);
        state = controller.getMarketState(marketId);
        assertTrue(state.liquidated);
        
        // Try to mature (should fail)
        vm.warp(maturityDate + 1);
        vm.expectRevert(abi.encodeWithSignature("MarketAlreadyLiquidated()"));
        controller.mature(marketId);
    }
}