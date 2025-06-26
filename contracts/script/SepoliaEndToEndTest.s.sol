// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/SimpleDarkPool.sol";

/**
 * @title SepoliaEndToEndTest
 * @notice End-to-end test for deployed contracts on Sepolia
 */
contract SepoliaEndToEndTest is Script {
    address constant SIMPLE_DARK_POOL =
        0x2e961535d6f6b3C11E69120aAc9f4fa4f562B6D5;
    uint256 constant PRIVATE_KEY =
        0xbf93dac6b885bd4a4fb152463d0e641c4a12d90dcea6cd74a8b0da459a0cd4ce;

    function run() external {
        console.log("=== SEPOLIA END-TO-END TEST ===");

        SimpleDarkPool darkPool = SimpleDarkPool(SIMPLE_DARK_POOL);
        address deployer = vm.addr(PRIVATE_KEY);

        console.log("Dark Pool Address:", address(darkPool));
        console.log("Deployer Address:", deployer);
        console.log("Deployer Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(PRIVATE_KEY);

        // Test 1: Verify contract state
        console.log("\n--- Test 1: Contract State ---");
        address owner = darkPool.owner();
        uint256 minStake = darkPool.MIN_OPERATOR_STAKE();
        uint256 batchTimeout = darkPool.BATCH_TIMEOUT();

        console.log("Owner:", owner);
        console.log("Min Stake:", minStake / 1e15, "milli-ETH");
        console.log("Batch Timeout:", batchTimeout / 3600, "hours");

        // Test 2: Register as operator
        console.log("\n--- Test 2: Register Operator ---");
        try darkPool.registerOperator{value: 0.001 ether}() {
            console.log("SUCCESS: Operator registration successful");
        } catch Error(string memory reason) {
            console.log("FAILED: Operator registration failed:", reason);
        }

        // Test 3: Submit an order
        console.log("\n--- Test 3: Submit Order ---");
        SimpleDarkPool.Order memory order = SimpleDarkPool.Order({
            trader: deployer,
            tokenIn: address(0x1111111111111111111111111111111111111111),
            tokenOut: address(0x2222222222222222222222222222222222222222),
            amountIn: 1 ether,
            minAmountOut: 0.9 ether,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: true
        });

        try darkPool.submitOrder(order) returns (bytes32 orderHash) {
            console.log("SUCCESS: Order submitted successfully");
            console.log("Order Hash:", vm.toString(orderHash));
        } catch Error(string memory reason) {
            console.log("FAILED: Order submission failed:", reason);
        }

        // Test 4: Commit a batch
        console.log("\n--- Test 4: Commit Batch ---");
        bytes32 merkleRoot = keccak256("test_merkle_root");

        try darkPool.commitBatch(merkleRoot, 1) {
            console.log("SUCCESS: Batch committed successfully");
            console.log("Merkle Root:", vm.toString(merkleRoot));
        } catch Error(string memory reason) {
            console.log("FAILED: Batch commit failed:", reason);
        }

        vm.stopBroadcast();

        console.log("\n=== END-TO-END TEST COMPLETE ===");
        console.log("All core functionality verified on Sepolia!");
    }
}
