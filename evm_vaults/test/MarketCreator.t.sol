// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MarketCreator.sol";
import "../src/vaults/RiskVault.sol";
import "../src/vaults/HedgeVault.sol";
import "./mocks/MockToken.sol";

contract MarketCreatorTest is Test {
    MarketCreator public marketCreator;
    MockToken public token;
    address public controller;
    address public user;
    
    event MarketVaultsCreated(
        uint256 indexed marketId,
        address indexed riskVault,
        address indexed hedgeVault
    );

    function setUp() public {
        controller = makeAddr("controller");
        user = makeAddr("user");
        
        token = new MockToken();
        marketCreator = new MarketCreator(controller, address(token));
        
        vm.label(address(marketCreator), "MarketCreator");
        vm.label(address(token), "Token");
        vm.label(controller, "Controller");
        vm.label(user, "User");
    }

    function test_Constructor() public view {
        assertEq(marketCreator.controller(), controller);
        assertEq(address(marketCreator.asset()), address(token));
    }

    function test_ConstructorZeroAddressReverts() public {
        vm.expectRevert("Invalid controller address");
        new MarketCreator(address(0), address(token));

        vm.expectRevert("Invalid asset address");
        new MarketCreator(controller, address(0));
    }

    function test_CreateFirstMarket() public {
        (uint256 marketId, address riskVault, address hedgeVault) = marketCreator.createMarketVaults();
        
        assertEq(marketId, 1, "First market should have ID 1");
        assertTrue(riskVault != address(0), "Risk vault should be deployed");
        assertTrue(hedgeVault != address(0), "Hedge vault should be deployed");
        assertTrue(riskVault != hedgeVault, "Vaults should be different");
        
        HedgeVault hedge = HedgeVault(hedgeVault);
        RiskVault risk = RiskVault(riskVault);
        
        assertEq(hedge.controller(), controller, "Hedge vault controller wrong");
        assertEq(hedge.marketId(), marketId, "Hedge vault marketId wrong");
        assertEq(address(hedge.asset()), address(token), "Hedge vault asset wrong");
        assertEq(hedge.owner(), address(marketCreator), "Hedge vault owner wrong");
        assertEq(hedge.sisterVault(), riskVault, "Hedge vault sister wrong");
        
        assertEq(risk.controller(), controller, "Risk vault controller wrong");
        assertEq(risk.marketId(), marketId, "Risk vault marketId wrong");
        assertEq(address(risk.asset()), address(token), "Risk vault asset wrong");
        assertEq(risk.sisterVault(), hedgeVault, "Risk vault sister wrong");
    }

    function test_CreateMultipleMarkets() public {
        (uint256 marketId1, address risk1, address hedge1) = marketCreator.createMarketVaults();
        assertEq(marketId1, 1, "First market ID wrong");
        
        (uint256 marketId2, address risk2, address hedge2) = marketCreator.createMarketVaults();
        assertEq(marketId2, 2, "Second market ID wrong");
        
        assertTrue(risk1 != risk2, "Risk vaults should be different");
        assertTrue(hedge1 != hedge2, "Hedge vaults should be different");
        
        (address storedRisk1, address storedHedge1) = marketCreator.getVaults(marketId1);
        (address storedRisk2, address storedHedge2) = marketCreator.getVaults(marketId2);
        
        assertEq(storedRisk1, risk1, "Stored risk1 wrong");
        assertEq(storedHedge1, hedge1, "Stored hedge1 wrong");
        assertEq(storedRisk2, risk2, "Stored risk2 wrong");
        assertEq(storedHedge2, hedge2, "Stored hedge2 wrong");
    }

    function test_GetVaultsNonExistent() public {
        vm.expectRevert("Market does not exist");
        marketCreator.getVaults(1);
    }
}