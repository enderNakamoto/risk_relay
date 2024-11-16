// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PythController.sol";
import "../src/MarketCreator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract DeployProtocol is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy USDC mock (or use existing address in prod)
        MockUSDC usdc = new MockUSDC();
        console.log("USDC deployed at:", address(usdc));

        // Step 2: Deploy PythController
        PythController controller = new PythController();
        console.log("PythController deployed at:", address(controller));

        // Step 3: Deploy MarketCreator with controller address
        MarketCreator marketCreator = new MarketCreator(
            address(controller),
            address(usdc)
        );
        console.log("MarketCreator deployed at:", address(marketCreator));

        // Step 4: Set MarketCreator in PythController
        controller.setMarketCreator(address(marketCreator));
        console.log("Set MarketCreator in PythController");

        vm.stopBroadcast();
    }
}