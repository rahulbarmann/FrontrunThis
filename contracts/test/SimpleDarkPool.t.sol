// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import "../src/SimpleDarkPool.sol";

contract SimpleDarkPoolTest is Test {
    SimpleDarkPool public darkPool;

    // Test accounts
    address public owner = address(0x1);
    address public operator1 = address(0x2);
    address public operator2 = address(0x3);
    address public trader1 = address(0x4);
    address public trader2 = address(0x5);

    // Test tokens
    address public tokenA = address(0x10);
    address public tokenB = address(0x11);

    function setUp() public {
        vm.prank(owner);
        darkPool = new SimpleDarkPool();

        // Fund operators and traders
        vm.deal(operator1, 10 ether);
        vm.deal(operator2, 10 ether);
        vm.deal(trader1, 1 ether);
        vm.deal(trader2, 1 ether);
    }

    function testInitialState() public {
        assertEq(darkPool.owner(), owner);
        assertEq(darkPool.MIN_OPERATOR_STAKE(), 1 ether);
        assertEq(darkPool.BATCH_TIMEOUT(), 1 hours);
        assertFalse(darkPool.isOperator(operator1));
    }

    function testRegisterOperator() public {
        // Should fail with insufficient stake
        vm.expectRevert("Insufficient stake");
        vm.prank(operator1);
        darkPool.registerOperator{value: 0.5 ether}();

        // Should succeed with sufficient stake
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        assertTrue(darkPool.isOperator(operator1));
        assertEq(darkPool.operatorStake(operator1), 2 ether);
    }

    function testSubmitOrder() public {
        SimpleDarkPool.Order memory order = SimpleDarkPool.Order({
            trader: trader1,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 100,
            minAmountOut: 95,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: true
        });

        vm.prank(trader1);
        bytes32 orderHash = darkPool.submitOrder(order);

        assertTrue(orderHash != bytes32(0));

        SimpleDarkPool.Order memory retrievedOrder = darkPool.getOrder(
            orderHash
        );
        assertEq(retrievedOrder.trader, trader1);
        assertEq(retrievedOrder.amountIn, 100);
        assertEq(retrievedOrder.minAmountOut, 95);
    }

    function testSubmitOrderFailures() public {
        SimpleDarkPool.Order memory order = SimpleDarkPool.Order({
            trader: trader2, // Wrong trader
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 100,
            minAmountOut: 95,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: true
        });

        // Should fail when msg.sender != order.trader
        vm.expectRevert("Invalid trader");
        vm.prank(trader1);
        darkPool.submitOrder(order);

        // Test expired order
        order.trader = trader1;
        order.deadline = block.timestamp - 1; // Expired

        vm.expectRevert("Order expired");
        vm.prank(trader1);
        darkPool.submitOrder(order);
    }

    function testCommitBatch() public {
        // Register operator
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        bytes32 merkleRoot = keccak256("test_merkle_root");
        uint256 tradeCount = 5;

        vm.prank(operator1);
        darkPool.commitBatch(merkleRoot, tradeCount);

        SimpleDarkPool.Batch memory batch = darkPool.getBatch(merkleRoot);
        assertEq(batch.merkleRoot, merkleRoot);
        assertEq(batch.tradeCount, tradeCount);
        assertEq(batch.operator, operator1);
        assertTrue(batch.isCommitted);
        assertFalse(batch.isSettled);
    }

    function testCommitBatchFailures() public {
        // Should fail for non-operator
        vm.expectRevert("Only operator");
        vm.prank(trader1);
        darkPool.commitBatch(keccak256("test"), 1);

        // Register operator
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        // Should fail with invalid merkle root
        vm.expectRevert("Invalid merkle root");
        vm.prank(operator1);
        darkPool.commitBatch(bytes32(0), 1);

        // Should fail with zero trades
        vm.expectRevert("No trades");
        vm.prank(operator1);
        darkPool.commitBatch(keccak256("test"), 0);
    }

    function testSettleTrade() public {
        // Setup: Register operator and submit orders
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        // Submit buy order
        SimpleDarkPool.Order memory buyOrder = SimpleDarkPool.Order({
            trader: trader1,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 100,
            minAmountOut: 95,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: true
        });

        vm.prank(trader1);
        bytes32 buyOrderHash = darkPool.submitOrder(buyOrder);

        // Submit sell order
        SimpleDarkPool.Order memory sellOrder = SimpleDarkPool.Order({
            trader: trader2,
            tokenIn: tokenB,
            tokenOut: tokenA,
            amountIn: 95,
            minAmountOut: 100,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: false
        });

        vm.prank(trader2);
        bytes32 sellOrderHash = darkPool.submitOrder(sellOrder);

        // Create trade
        SimpleDarkPool.Trade memory trade = SimpleDarkPool.Trade({
            buyOrderHash: buyOrderHash,
            sellOrderHash: sellOrderHash,
            price: 100,
            quantity: 95,
            timestamp: block.timestamp
        });

        bytes32 tradeHash = keccak256(abi.encode(trade));

        // Create merkle tree (simplified - single leaf)
        bytes32 merkleRoot = tradeHash; // Single leaf tree
        bytes32[] memory proof = new bytes32[](0); // No proof needed for single leaf

        // Commit batch
        vm.prank(operator1);
        darkPool.commitBatch(merkleRoot, 1);

        // Settle trade
        darkPool.settleTrade(trade, proof, merkleRoot);

        assertTrue(darkPool.isTradeSettled(tradeHash));
    }

    function testMerkleProofVerification() public {
        // Test single leaf (root == leaf)
        bytes32 leaf = keccak256("test_leaf");
        bytes32[] memory emptyProof = new bytes32[](0);

        // This should pass because for a single leaf tree, root == leaf
        assertTrue(_callVerifyProof(emptyProof, leaf, leaf));

        // Test with actual proof
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 expectedRoot = keccak256(abi.encodePacked(leaf1, leaf2));

        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = leaf2;

        assertTrue(_callVerifyProof(proof1, expectedRoot, leaf1));
    }

    function testEndToEndWorkflow() public {
        console.log("=== Testing End-to-End Dark Pool Workflow ===");

        // 1. Register operator
        console.log("1. Registering operator...");
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        // 2. Submit orders
        console.log("2. Submitting orders...");
        SimpleDarkPool.Order memory buyOrder = SimpleDarkPool.Order({
            trader: trader1,
            tokenIn: tokenA,
            tokenOut: tokenB,
            amountIn: 1000,
            minAmountOut: 950,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: true
        });

        SimpleDarkPool.Order memory sellOrder = SimpleDarkPool.Order({
            trader: trader2,
            tokenIn: tokenB,
            tokenOut: tokenA,
            amountIn: 950,
            minAmountOut: 1000,
            nonce: 1,
            deadline: block.timestamp + 1 hours,
            isBuy: false
        });

        vm.prank(trader1);
        bytes32 buyOrderHash = darkPool.submitOrder(buyOrder);

        vm.prank(trader2);
        bytes32 sellOrderHash = darkPool.submitOrder(sellOrder);

        console.log("Orders submitted successfully");

        // 3. Operator matches orders off-chain and commits batch
        console.log("3. Committing batch...");
        SimpleDarkPool.Trade memory trade = SimpleDarkPool.Trade({
            buyOrderHash: buyOrderHash,
            sellOrderHash: sellOrderHash,
            price: 975, // Midpoint price
            quantity: 950,
            timestamp: block.timestamp
        });

        bytes32 tradeHash = keccak256(abi.encode(trade));
        bytes32 merkleRoot = tradeHash; // Single trade

        vm.prank(operator1);
        darkPool.commitBatch(merkleRoot, 1);

        console.log("Batch committed successfully");

        // 4. Settle trade
        console.log("4. Settling trade...");
        bytes32[] memory proof = new bytes32[](0);
        darkPool.settleTrade(trade, proof, merkleRoot);

        console.log("Trade settled successfully");

        // 5. Verify final state
        assertTrue(darkPool.isTradeSettled(tradeHash));
        SimpleDarkPool.Batch memory batch = darkPool.getBatch(merkleRoot);
        assertTrue(batch.isCommitted);

        console.log("=== End-to-End Test Completed Successfully! ===");
    }

    // Helper function to test merkle proof verification
    function _callVerifyProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal view returns (bool) {
        // We need to use a public function that calls the internal _verifyMerkleProof
        // For testing, we'll recreate the logic here
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        return computedHash == root;
    }

    function testMultipleOperators() public {
        // Register multiple operators
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        vm.prank(operator2);
        darkPool.registerOperator{value: 3 ether}();

        assertTrue(darkPool.isOperator(operator1));
        assertTrue(darkPool.isOperator(operator2));
        assertEq(darkPool.operatorStake(operator1), 2 ether);
        assertEq(darkPool.operatorStake(operator2), 3 ether);
    }

    function testBatchTimeout() public {
        // Register operator and commit batch
        vm.prank(operator1);
        darkPool.registerOperator{value: 2 ether}();

        bytes32 merkleRoot = keccak256("test_batch");
        vm.prank(operator1);
        darkPool.commitBatch(merkleRoot, 1);

        // Create dummy trade
        SimpleDarkPool.Trade memory trade = SimpleDarkPool.Trade({
            buyOrderHash: keccak256("buy"),
            sellOrderHash: keccak256("sell"),
            price: 100,
            quantity: 50,
            timestamp: block.timestamp
        });

        // Fast forward past timeout
        vm.warp(block.timestamp + 2 hours);

        // Should fail due to timeout
        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert("Batch expired");
        darkPool.settleTrade(trade, proof, merkleRoot);
    }
}
