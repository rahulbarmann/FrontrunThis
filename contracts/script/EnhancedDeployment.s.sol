// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimpleDarkPool.sol";
import "../src/DarkPoolServiceManager.sol";
import "../src/DarkPoolTaskManager.sol";

/**
 * @title EnhancedDeployment
 * @dev Deployment script for the enhanced DarkPool system with full EigenLayer integration
 */
contract EnhancedDeployment is Script {
    function run() external {
        // Get deployment key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying from:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Mock EigenLayer addresses for testnet deployment
        // In production, these would be the actual EigenLayer contract addresses
        address delegationManager = address(0x1); // Mock address
        address avsDirectory = address(0x2); // Mock address
        address registryCoordinator = address(0x3); // Mock address

        // Deploy DarkPoolServiceManager first
        DarkPoolServiceManager serviceManager = new DarkPoolServiceManager(
            delegationManager,
            avsDirectory,
            registryCoordinator
        );
        console.log(
            "DarkPoolServiceManager deployed to:",
            address(serviceManager)
        );

        // Deploy DarkPoolTaskManager with ServiceManager address
        DarkPoolTaskManager taskManager = new DarkPoolTaskManager(
            address(serviceManager)
        );
        console.log("DarkPoolTaskManager deployed to:", address(taskManager));

        // Deploy enhanced SimpleDarkPool with both managers
        SimpleDarkPool darkPool = new SimpleDarkPool();
        console.log("Enhanced SimpleDarkPool deployed to:", address(darkPool));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== ENHANCED DEPLOYMENT COMPLETE ===");
        console.log("DarkPoolServiceManager:", address(serviceManager));
        console.log("DarkPoolTaskManager:", address(taskManager));
        console.log("Enhanced SimpleDarkPool:", address(darkPool));
        console.log("Network: Sepolia Testnet");
        console.log("Deployer:", deployer);
        console.log("Remaining balance:", deployer.balance);
    }
}
