// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import "../src/DarkPoolHook.sol";
import "../src/SimpleDarkPool.sol";
import "../src/DarkPoolServiceManager.sol";
import "../src/DarkPoolTaskManager.sol";

/**
 * @title DeployDarkPoolHook
 * @notice Deployment script for DarkPoolHook integration with Uniswap V4
 */
contract DeployDarkPoolHook is Script {
    // Mock addresses for testnet (replace with actual EigenLayer addresses in production)
    address constant MOCK_DELEGATION_MANAGER =
        0x1234567890123456789012345678901234567890;
    address constant MOCK_AVS_DIRECTORY =
        0x2345678901234567890123456789012345678901;
    address constant MOCK_REGISTRY_COORDINATOR =
        0x3456789012345678901234567890123456789012;
    address constant MOCK_STAKE_REGISTRY =
        0x4567890123456789012345678901234567890123;
    address constant MOCK_STRATEGY_MANAGER =
        0x5678901234567890123456789012345678901234;

    // Use existing PoolManager addresses for different networks
    address constant SEPOLIA_POOL_MANAGER =
        0xE03A1074c86CFeDd5C142C4F04F1a1536e203543; // Official Uniswap v4 Sepolia PoolManager
    address constant MAINNET_POOL_MANAGER =
        0x000000000004444c5dc75cB358380D2e3dE08A90; // Official Uniswap v4 Mainnet PoolManager

    // Pool configuration
    uint24 constant FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;

    struct DeploymentResult {
        IPoolManager poolManager;
        DarkPoolHook hook;
        SimpleDarkPool darkPool;
        DarkPoolServiceManager serviceManager;
        DarkPoolTaskManager taskManager;
        address hookAddress;
        PoolKey poolKey;
    }

    function run() external returns (DeploymentResult memory result) {
        // Use the private key from .env or hardcoded for testing
        uint256 deployerPrivateKey = 0xbf93dac6b885bd4a4fb152463d0e641c4a12d90dcea6cd74a8b0da459a0cd4ce;
        address deployer = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        console.log("Deploying DarkPool Hook system...");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Use existing PoolManager or deploy for local testing
        if (chainId == 11155111) {
            // Sepolia
            result.poolManager = IPoolManager(SEPOLIA_POOL_MANAGER);
            console.log(
                "Using Sepolia PoolManager at:",
                address(result.poolManager)
            );
        } else if (chainId == 1) {
            // Mainnet
            result.poolManager = IPoolManager(MAINNET_POOL_MANAGER);
            console.log(
                "Using Mainnet PoolManager at:",
                address(result.poolManager)
            );
        } else {
            // For local testing, we'll skip PoolManager deployment and use a mock address
            result.poolManager = IPoolManager(
                address(0x1111111111111111111111111111111111111111)
            );
            console.log(
                "Using mock PoolManager for local testing:",
                address(result.poolManager)
            );
        }

        // 2. Deploy Dark Pool contracts first
        result.serviceManager = new DarkPoolServiceManager(
            MOCK_DELEGATION_MANAGER,
            MOCK_AVS_DIRECTORY,
            MOCK_REGISTRY_COORDINATOR
        );
        console.log(
            "DarkPoolServiceManager deployed at:",
            address(result.serviceManager)
        );

        result.taskManager = new DarkPoolTaskManager(
            address(result.serviceManager)
        );
        console.log(
            "DarkPoolTaskManager deployed at:",
            address(result.taskManager)
        );

        result.darkPool = new SimpleDarkPool();
        console.log("SimpleDarkPool deployed at:", address(result.darkPool));

        // 3. Deploy DarkPoolHook with a predictable address
        // Note: In production, you would need to mine for a specific address with required flags
        result.hook = new DarkPoolHook(
            result.poolManager,
            result.darkPool,
            result.serviceManager
        );
        result.hookAddress = address(result.hook);

        console.log("DarkPoolHook deployed at:", result.hookAddress);

        // Check if the address has the correct flags (for informational purposes)
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.AFTER_INITIALIZE_FLAG |
                Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG |
                Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        bool flagsMatch = (uint160(result.hookAddress) & flags) == flags;
        console.log("Hook flags match required permissions:", flagsMatch);
        if (!flagsMatch) {
            console.log(
                "Warning: Hook address doesn't have required flags. You may need to use CREATE2 with a specific salt."
            );
            console.log("Required flags:", flags);
            console.log(
                "Hook address flags:",
                uint160(result.hookAddress) & flags
            );
        }

        // 4. Create a sample pool key for testing
        // For testnet, these can be mock addresses or actual test tokens
        address token0 = address(0x1000000000000000000000000000000000000001); // Mock token 0
        address token1 = address(0x2000000000000000000000000000000000000002); // Mock token 1

        // For Sepolia, you might want to use actual test tokens
        if (chainId == 11155111) {
            token0 = address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9); // WETH on Sepolia
            token1 = address(0x779877A7B0D9E8603169DdbD7836e478b4624789); // LINK on Sepolia (example)
        }

        // Ensure token0 < token1
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        result.poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(result.hookAddress)
        });

        console.log("Sample PoolKey created:");
        console.log("  Currency0:", Currency.unwrap(result.poolKey.currency0));
        console.log("  Currency1:", Currency.unwrap(result.poolKey.currency1));
        console.log("  Fee:", result.poolKey.fee);
        console.log("  TickSpacing:", result.poolKey.tickSpacing);
        console.log("  Hooks:", address(result.poolKey.hooks));

        vm.stopBroadcast();

        // 5. Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Chain ID:", chainId);
        console.log("PoolManager:", address(result.poolManager));
        console.log("DarkPoolServiceManager:", address(result.serviceManager));
        console.log("DarkPoolTaskManager:", address(result.taskManager));
        console.log("SimpleDarkPool:", address(result.darkPool));
        console.log("DarkPoolHook:", result.hookAddress);
        console.log(
            "Hook Permissions Valid:",
            _validateHookPermissions(result.hook)
        );
        console.log("Gas used for deployment: ~2-3M gas");

        // Save addresses to file - commented out to avoid permission issues
        // _saveAddresses(result);

        return result;
    }

    function _validateHookPermissions(
        DarkPoolHook hook
    ) internal view returns (bool) {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        return
            permissions.beforeInitialize &&
            permissions.afterInitialize &&
            permissions.afterAddLiquidity &&
            permissions.afterRemoveLiquidity &&
            permissions.beforeSwap &&
            permissions.afterSwap &&
            permissions.beforeSwapReturnDelta;
    }

    function _saveAddresses(DeploymentResult memory result) internal {
        string memory addresses = string(
            abi.encodePacked(
                "# DarkPool Hook Deployment Addresses - Chain ID: ",
                vm.toString(block.chainid),
                "\n",
                "# Deployed at block: ",
                vm.toString(block.number),
                "\n",
                "# Deployment timestamp: ",
                vm.toString(block.timestamp),
                "\n\n",
                "POOL_MANAGER=",
                vm.toString(address(result.poolManager)),
                "\n",
                "DARK_POOL_SERVICE_MANAGER=",
                vm.toString(address(result.serviceManager)),
                "\n",
                "DARK_POOL_TASK_MANAGER=",
                vm.toString(address(result.taskManager)),
                "\n",
                "SIMPLE_DARK_POOL=",
                vm.toString(address(result.darkPool)),
                "\n",
                "DARK_POOL_HOOK=",
                vm.toString(result.hookAddress),
                "\n",
                "SAMPLE_TOKEN0=",
                vm.toString(Currency.unwrap(result.poolKey.currency0)),
                "\n",
                "SAMPLE_TOKEN1=",
                vm.toString(Currency.unwrap(result.poolKey.currency1)),
                "\n",
                "POOL_FEE=",
                vm.toString(result.poolKey.fee),
                "\n",
                "TICK_SPACING=",
                vm.toString(uint256(int256(result.poolKey.tickSpacing))),
                "\n\n",
                "# Hook Configuration\n",
                "BEFORE_INITIALIZE=true\n",
                "AFTER_INITIALIZE=true\n",
                "AFTER_ADD_LIQUIDITY=true\n",
                "AFTER_REMOVE_LIQUIDITY=true\n",
                "BEFORE_SWAP=true\n",
                "AFTER_SWAP=true\n",
                "BEFORE_SWAP_RETURNS_DELTA=true\n"
            )
        );

        vm.writeFile("darkpool-hook-addresses.txt", addresses);
        console.log("Addresses saved to darkpool-hook-addresses.txt");
    }

    // Helper function to validate hook address flags (for informational purposes)
    function validateHookFlags(address hookAddress) public pure returns (bool) {
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.AFTER_INITIALIZE_FLAG |
                Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG |
                Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        return (uint160(hookAddress) & flags) == flags;
    }
}
