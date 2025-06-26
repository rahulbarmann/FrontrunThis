// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import "../src/DarkPoolHook.sol";
import "../src/SimpleDarkPool.sol";
import "../src/DarkPoolServiceManager.sol";

/**
 * @title DeploymentTest
 * @notice Test deployed contracts functionality
 */
contract DeploymentTest is Test {
    // Deployed addresses from local testnet
    address constant DARK_POOL_SERVICE_MANAGER =
        0x981B69e7c1650De6bdB795a74bE5E1113B69D674;
    address constant DARK_POOL_TASK_MANAGER =
        0xe76396DA80226bdEAaAD2B5F975D7BAd26fF50A6;
    address constant SIMPLE_DARK_POOL =
        0xb675ab8Cd23254F3cFad9d255e246Cc02cB89401;
    address constant DARK_POOL_HOOK =
        0x6c0Cc15686fC56aAcb4B7Ad4825976383D4a64B1;

    DarkPoolHook hook;
    SimpleDarkPool darkPool;
    DarkPoolServiceManager serviceManager;

    function setUp() public {
        // Connect to deployed contracts
        hook = DarkPoolHook(DARK_POOL_HOOK);
        darkPool = SimpleDarkPool(SIMPLE_DARK_POOL);
        serviceManager = DarkPoolServiceManager(DARK_POOL_SERVICE_MANAGER);

        console.log("=== Testing Deployed Contracts ===");
        console.log("DarkPoolHook:", address(hook));
        console.log("SimpleDarkPool:", address(darkPool));
        console.log("ServiceManager:", address(serviceManager));
    }

    function testDeployedContracts() public view {
        console.log("=== Testing Contract Deployment ===");

        // Test that contracts are deployed and have code
        assertTrue(
            address(hook).code.length > 0,
            "DarkPoolHook should have code"
        );
        assertTrue(
            address(darkPool).code.length > 0,
            "SimpleDarkPool should have code"
        );
        assertTrue(
            address(serviceManager).code.length > 0,
            "ServiceManager should have code"
        );

        console.log("[PASS] All contracts deployed successfully");
    }

    function testHookPermissions() public view {
        console.log("=== Testing Hook Permissions ===");

        Hooks.Permissions memory permissions = hook.getHookPermissions();

        assertTrue(
            permissions.beforeInitialize,
            "beforeInitialize should be enabled"
        );
        assertTrue(
            permissions.afterInitialize,
            "afterInitialize should be enabled"
        );
        assertTrue(
            permissions.afterAddLiquidity,
            "afterAddLiquidity should be enabled"
        );
        assertTrue(
            permissions.afterRemoveLiquidity,
            "afterRemoveLiquidity should be enabled"
        );
        assertTrue(permissions.beforeSwap, "beforeSwap should be enabled");
        assertTrue(permissions.afterSwap, "afterSwap should be enabled");
        assertTrue(
            permissions.beforeSwapReturnDelta,
            "beforeSwapReturnDelta should be enabled"
        );

        console.log("[PASS] Hook permissions correctly configured");
    }

    function testHookConstants() public view {
        console.log("=== Testing Hook Constants ===");

        assertEq(
            hook.DEFAULT_PRICE_IMPACT_THRESHOLD(),
            50,
            "Default price impact should be 50 basis points"
        );
        assertEq(
            hook.MAX_ORDER_LIFETIME(),
            24 hours,
            "Max order lifetime should be 24 hours"
        );
        assertEq(
            hook.MIN_ORDER_VALUE(),
            0.001 ether,
            "Min order value should be 0.001 ether"
        );

        console.log("[PASS] Hook constants correctly set");
    }

    function testDarkPoolInitialState() public view {
        console.log("=== Testing DarkPool Initial State ===");

        assertEq(darkPool.totalStake(), 0, "Initial total stake should be 0");
        assertEq(darkPool.nextOrderId(), 1, "Initial order ID should be 1");
        assertEq(darkPool.currentBatchId(), 0, "Initial batch ID should be 0");

        console.log("[PASS] DarkPool initial state correct");
    }

    function testServiceManagerConfiguration() public view {
        console.log("=== Testing ServiceManager Configuration ===");

        // Test that service manager has the correct addresses configured
        assertTrue(
            address(serviceManager.delegationManager()) != address(0),
            "Delegation manager should be set"
        );
        assertTrue(
            address(serviceManager.avsDirectory()) != address(0),
            "AVS directory should be set"
        );
        assertTrue(
            address(serviceManager.registryCoordinator()) != address(0),
            "Registry coordinator should be set"
        );

        console.log("[PASS] ServiceManager correctly configured");
    }

    function testHookIntegration() public view {
        console.log("=== Testing Hook Integration ===");

        // Test that hook has references to other contracts
        assertEq(
            address(hook.darkPool()),
            SIMPLE_DARK_POOL,
            "Hook should reference dark pool"
        );
        assertEq(
            address(hook.serviceManager()),
            DARK_POOL_SERVICE_MANAGER,
            "Hook should reference service manager"
        );

        console.log("[PASS] Hook integration working correctly");
    }

    function testOrderIdCounters() public view {
        console.log("=== Testing Order ID Counters ===");

        assertEq(hook.nextOrderId(), 1, "Hook next order ID should start at 1");
        assertEq(
            darkPool.nextOrderId(),
            1,
            "DarkPool next order ID should start at 1"
        );

        console.log("[PASS] Order ID counters initialized correctly");
    }
}
