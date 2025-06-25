// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "../src/SimpleDarkPool.sol";

contract SimpleDeployment is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying SimpleDarkPool...");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        SimpleDarkPool pool = new SimpleDarkPool();
        console.log("SimpleDarkPool deployed at:", address(pool));

        vm.stopBroadcast();

        console.log("Deployment completed successfully!");
    }
}
