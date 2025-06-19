// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimpleDarkPool.sol";

contract DarkPoolDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SimpleDarkPool
        SimpleDarkPool darkPool = new SimpleDarkPool();

        console.log("SimpleDarkPool deployed at:", address(darkPool));

        vm.stopBroadcast();
    }
}
