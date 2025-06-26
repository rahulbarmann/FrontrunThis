// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";

import "../src/DarkPoolHook.sol";
import "../src/SimpleDarkPool.sol";
import "../src/DarkPoolServiceManager.sol";

contract MockPoolManager {
    mapping(bytes4 => bool) public supportedFunctions;

    constructor() {
        // Mark all functions as supported
        supportedFunctions[IPoolManager.beforeInitialize.selector] = true;
        supportedFunctions[IPoolManager.afterInitialize.selector] = true;
        supportedFunctions[IPoolManager.beforeAddLiquidity.selector] = true;
        supportedFunctions[IPoolManager.afterAddLiquidity.selector] = true;
        supportedFunctions[IPoolManager.beforeRemoveLiquidity.selector] = true;
        supportedFunctions[IPoolManager.afterRemoveLiquidity.selector] = true;
        supportedFunctions[IPoolManager.beforeSwap.selector] = true;
        supportedFunctions[IPoolManager.afterSwap.selector] = true;
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract DarkPoolHookTest is Test {
    using PoolIdLibrary for PoolKey;

    DarkPoolHook public hook;
    SimpleDarkPool public darkPool;
    DarkPoolServiceManager public serviceManager;
    MockPoolManager public poolManager;
    MockERC20 public token0;
    MockERC20 public token1;

    PoolKey public poolKey;
    PoolId public poolId;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public operator = address(0x3);

    // Mock addresses for EigenLayer components
    address constant MOCK_DELEGATION_MANAGER = address(0x1001);
    address constant MOCK_AVS_DIRECTORY = address(0x1002);
    address constant MOCK_REGISTRY_COORDINATOR = address(0x1003);

    event DarkPoolOrderCreated(
        address indexed trader,
        PoolId indexed poolId,
        uint256 indexed orderId,
        uint256 amount,
        bool isZeroForOne,
        uint256 deadline
    );

    event DarkPoolOrderMatched(
        uint256 indexed orderId,
        address indexed trader,
        uint256 amountIn,
        uint256 amountOut,
        uint256 settledPrice
    );

    event AMMTradeRouted(
        address indexed trader,
        PoolId indexed poolId,
        uint256 amountIn,
        uint256 amountOut,
        bool darkPoolAttempted
    );

    function setUp() public {
        console.log("=== Setting up DarkPoolHook Test Environment ===");

        // Deploy mock contracts
        poolManager = new MockPoolManager();
        token0 = new MockERC20("Token0", "TK0", 1000000 * 1e18);
        token1 = new MockERC20("Token1", "TK1", 1000000 * 1e18);

        // Ensure token0 < token1 for proper ordering
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Deploy DarkPool components
        serviceManager = new DarkPoolServiceManager(
            MOCK_DELEGATION_MANAGER,
            MOCK_AVS_DIRECTORY,
            MOCK_REGISTRY_COORDINATOR
        );

        darkPool = new SimpleDarkPool();

        // Deploy the hook
        hook = new DarkPoolHook(
            IPoolManager(address(poolManager)),
            darkPool,
            serviceManager
        );

        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();

        // Fund test accounts
        token0.transfer(alice, 10000 * 1e18);
        token1.transfer(alice, 10000 * 1e18);
        token0.transfer(bob, 10000 * 1e18);
        token1.transfer(bob, 10000 * 1e18);

        console.log("Hook deployed at:", address(hook));
        console.log("PoolId:", uint256(PoolId.unwrap(poolId)));
        console.log("Token0:", address(token0));
        console.log("Token1:", address(token1));
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

        assertFalse(
            permissions.beforeAddLiquidity,
            "beforeAddLiquidity should be disabled"
        );
        assertFalse(
            permissions.beforeRemoveLiquidity,
            "beforeRemoveLiquidity should be disabled"
        );
        assertFalse(
            permissions.beforeDonate,
            "beforeDonate should be disabled"
        );
        assertFalse(permissions.afterDonate, "afterDonate should be disabled");

        console.log("All hook permissions correctly configured");
    }

    function testBeforeInitialize() public {
        console.log("=== Testing beforeInitialize Hook ===");

        vm.prank(address(poolManager));
        bytes4 result = hook.beforeInitialize(address(this), poolKey, 0);

        assertEq(
            result,
            hook.beforeInitialize.selector,
            "Should return correct selector"
        );

        // Check that default pool config was set
        DarkPoolHook.PoolConfig memory config = hook.getPoolConfig(poolId);
        assertTrue(
            config.darkPoolEnabled,
            "Dark pool should be enabled by default"
        );
        assertEq(
            config.maxPriceImpact,
            50,
            "Default price impact should be 50 basis points"
        );
        assertEq(
            config.minOrderSize,
            0.001 ether,
            "Default min order size should be 0.001 ether"
        );
        assertEq(
            config.orderLifetime,
            1 hours,
            "Default order lifetime should be 1 hour"
        );

        console.log("[PASS] beforeInitialize working correctly");
    }

    function testAfterInitialize() public {
        console.log("=== Testing afterInitialize Hook ===");

        // First call beforeInitialize to set up the pool config
        vm.prank(address(poolManager));
        hook.beforeInitialize(address(this), poolKey, 0);

        // Then call afterInitialize
        vm.prank(address(poolManager));
        bytes4 result = hook.afterInitialize(address(this), poolKey, 0, 0);

        assertEq(
            result,
            hook.afterInitialize.selector,
            "Should return correct selector"
        );

        // Check that liquidity tracking was initialized
        assertEq(
            hook.getDarkPoolLiquidity(poolId, true),
            0,
            "Initial liquidity should be 0"
        );
        assertEq(
            hook.getDarkPoolLiquidity(poolId, false),
            0,
            "Initial liquidity should be 0"
        );

        console.log("[PASS] afterInitialize working correctly");
    }

    function testAfterAddLiquidity() public {
        console.log("=== Testing afterAddLiquidity Hook ===");

        // Initialize the pool first
        vm.startPrank(address(poolManager));
        hook.beforeInitialize(address(this), poolKey, 0);
        hook.afterInitialize(address(this), poolKey, 0, 0);

        // Simulate adding liquidity
        BalanceDelta delta = BalanceDelta.wrap(0);
        delta = delta.add(Currency.wrap(address(token0)), int128(1000 * 1e18));
        delta = delta.add(Currency.wrap(address(token1)), int128(2000 * 1e18));

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager
            .ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000 * 1e18,
                salt: bytes32(0)
            });

        (bytes4 selector, BalanceDelta hookDelta) = hook.afterAddLiquidity(
            address(this),
            poolKey,
            params,
            delta,
            BalanceDelta.wrap(0),
            ""
        );
        vm.stopPrank();

        assertEq(
            selector,
            hook.afterAddLiquidity.selector,
            "Should return correct selector"
        );
        assertEq(
            BalanceDelta.unwrap(hookDelta),
            0,
            "Hook delta should be zero"
        );

        // Check that dark pool liquidity was updated (10% of AMM liquidity)
        assertEq(
            hook.getDarkPoolLiquidity(poolId, true),
            100 * 1e18,
            "Dark pool liquidity should be 10% of token0"
        );
        assertEq(
            hook.getDarkPoolLiquidity(poolId, false),
            200 * 1e18,
            "Dark pool liquidity should be 10% of token1"
        );

        console.log("[PASS] afterAddLiquidity working correctly");
    }

    function testAfterRemoveLiquidity() public {
        console.log("=== Testing afterRemoveLiquidity Hook ===");

        // First add liquidity
        testAfterAddLiquidity();

        // Now remove liquidity
        vm.startPrank(address(poolManager));

        BalanceDelta delta = BalanceDelta.wrap(0);
        delta = delta.add(Currency.wrap(address(token0)), int128(-500 * 1e18)); // Negative for removal
        delta = delta.add(Currency.wrap(address(token1)), int128(-1000 * 1e18));

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager
            .ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: -500 * 1e18,
                salt: bytes32(0)
            });

        (bytes4 selector, BalanceDelta hookDelta) = hook.afterRemoveLiquidity(
            address(this),
            poolKey,
            params,
            delta,
            BalanceDelta.wrap(0),
            ""
        );
        vm.stopPrank();

        assertEq(
            selector,
            hook.afterRemoveLiquidity.selector,
            "Should return correct selector"
        );

        // Check that dark pool liquidity was reduced
        assertEq(
            hook.getDarkPoolLiquidity(poolId, true),
            50 * 1e18,
            "Dark pool liquidity should be reduced"
        );
        assertEq(
            hook.getDarkPoolLiquidity(poolId, false),
            100 * 1e18,
            "Dark pool liquidity should be reduced"
        );

        console.log("[PASS] afterRemoveLiquidity working correctly");
    }

    function testBeforeSwapDarkPoolDisabled() public {
        console.log("=== Testing beforeSwap with Dark Pool Disabled ===");

        // Initialize pool
        vm.startPrank(address(poolManager));
        hook.beforeInitialize(address(this), poolKey, 0);
        hook.afterInitialize(address(this), poolKey, 0, 0);
        vm.stopPrank();

        // Disable dark pool for this pool
        hook.configurePool(
            poolId,
            false,
            50,
            0.001 ether,
            type(uint256).max,
            1 hours,
            false
        );

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -1 * 1e18, // Exact input
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        (
            bytes4 selector,
            BeforeSwapDelta swapDelta,
            uint24 lpFeeOverride
        ) = hook.beforeSwap(alice, poolKey, params, "");

        assertEq(
            selector,
            hook.beforeSwap.selector,
            "Should return correct selector"
        );
        assertEq(
            BeforeSwapDelta.unwrap(swapDelta),
            0,
            "Should return zero delta when disabled"
        );
        assertEq(lpFeeOverride, 0, "Should not override LP fee");

        console.log("[PASS] beforeSwap correctly handles disabled dark pool");
    }

    function testBeforeSwapDarkPoolRouting() public {
        console.log("=== Testing beforeSwap Dark Pool Routing ===");

        // Initialize pool and add liquidity
        testAfterAddLiquidity();

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -10 * 1e18, // Large order that should trigger dark pool
            sqrtPriceLimitX96: 0
        });

        // Expect DarkPoolOrderCreated event
        vm.expectEmit(true, true, true, false);
        emit DarkPoolOrderCreated(
            alice,
            poolId,
            1,
            10 * 1e18,
            true,
            block.timestamp + 1 hours
        );

        vm.prank(address(poolManager));
        (
            bytes4 selector,
            BeforeSwapDelta swapDelta,
            uint24 lpFeeOverride
        ) = hook.beforeSwap(alice, poolKey, params, "");

        assertEq(
            selector,
            hook.beforeSwap.selector,
            "Should return correct selector"
        );

        // Check that order was created
        DarkPoolHook.DarkPoolOrder memory order = hook.getOrder(1);
        assertEq(order.trader, alice, "Order trader should be Alice");
        assertEq(order.amountIn, 10 * 1e18, "Order amount should match");
        assertTrue(order.isZeroForOne, "Order direction should be correct");
        assertTrue(order.isActive, "Order should be active");

        console.log("[PASS] beforeSwap correctly routes to dark pool");
    }

    function testAfterSwap() public {
        console.log("=== Testing afterSwap Hook ===");

        // Initialize pool
        testAfterAddLiquidity();

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -1 * 1e18,
            sqrtPriceLimitX96: 0
        });

        BalanceDelta delta = BalanceDelta.wrap(0);
        delta = delta.add(Currency.wrap(address(token0)), int128(-1 * 1e18));
        delta = delta.add(
            Currency.wrap(address(token1)),
            int128(990000000000000000)
        ); // ~0.99 token1

        // Expect AMMTradeRouted event
        vm.expectEmit(true, true, false, false);
        emit AMMTradeRouted(alice, poolId, 1 * 1e18, 1 * 1e18, false);

        vm.prank(address(poolManager));
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(
            alice,
            poolKey,
            params,
            delta,
            ""
        );

        assertEq(
            selector,
            hook.afterSwap.selector,
            "Should return correct selector"
        );
        assertEq(hookDelta, 0, "Hook delta should be zero");

        console.log("[PASS] afterSwap working correctly");
    }

    function testPoolConfiguration() public {
        console.log("=== Testing Pool Configuration ===");

        // Test configuring pool parameters
        hook.configurePool(
            poolId,
            true, // darkPoolEnabled
            100, // maxPriceImpact (1%)
            1 * 1e18, // minOrderSize
            100 * 1e18, // maxOrderSize
            2 hours, // orderLifetime
            true // requireCommitReveal
        );

        DarkPoolHook.PoolConfig memory config = hook.getPoolConfig(poolId);
        assertTrue(config.darkPoolEnabled, "Dark pool should be enabled");
        assertEq(
            config.maxPriceImpact,
            100,
            "Price impact should be 100 basis points"
        );
        assertEq(
            config.minOrderSize,
            1 * 1e18,
            "Min order size should be 1 ether"
        );
        assertEq(
            config.maxOrderSize,
            100 * 1e18,
            "Max order size should be 100 ether"
        );
        assertEq(
            config.orderLifetime,
            2 hours,
            "Order lifetime should be 2 hours"
        );
        assertTrue(
            config.requireCommitReveal,
            "Commit-reveal should be required"
        );

        console.log("[PASS] Pool configuration working correctly");
    }

    function testOrderManagement() public {
        console.log("=== Testing Order Management ===");

        // Initialize and add liquidity
        testAfterAddLiquidity();

        // Create an order through swap
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -10 * 1e18,
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        hook.beforeSwap(alice, poolKey, params, "");

        // Check trader orders
        uint256[] memory aliceOrders = hook.getTraderOrders(alice);
        assertEq(aliceOrders.length, 1, "Alice should have 1 order");
        assertEq(aliceOrders[0], 1, "Order ID should be 1");

        // Test order cancellation
        vm.prank(alice);
        hook.cancelOrder(1);

        DarkPoolHook.DarkPoolOrder memory order = hook.getOrder(1);
        assertFalse(
            order.isActive,
            "Order should be inactive after cancellation"
        );

        console.log("[PASS] Order management working correctly");
    }

    function testOrderCancellationAccess() public {
        console.log("=== Testing Order Cancellation Access Control ===");

        // Initialize and create order
        testAfterAddLiquidity();

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -10 * 1e18,
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        hook.beforeSwap(alice, poolKey, params, "");

        // Try to cancel order from wrong account
        vm.prank(bob);
        vm.expectRevert(DarkPoolHook.Unauthorized.selector);
        hook.cancelOrder(1);

        // Verify order is still active
        DarkPoolHook.DarkPoolOrder memory order = hook.getOrder(1);
        assertTrue(order.isActive, "Order should still be active");

        console.log(
            "[PASS] Order cancellation access control working correctly"
        );
    }

    function testHookAccessControl() public {
        console.log("=== Testing Hook Access Control ===");

        // Test that only pool manager can call hook functions
        vm.expectRevert(DarkPoolHook.NotPoolManager.selector);
        hook.beforeInitialize(address(this), poolKey, 0);

        vm.expectRevert(DarkPoolHook.NotPoolManager.selector);
        hook.afterInitialize(address(this), poolKey, 0, 0);

        console.log("[PASS] Hook access control working correctly");
    }

    function testLiquidityTracking() public {
        console.log("=== Testing Liquidity Tracking ===");

        // Initialize pool
        vm.startPrank(address(poolManager));
        hook.beforeInitialize(address(this), poolKey, 0);
        hook.afterInitialize(address(this), poolKey, 0, 0);
        vm.stopPrank();

        // Add liquidity in multiple steps
        vm.startPrank(address(poolManager));

        // First addition
        BalanceDelta delta1 = BalanceDelta.wrap(0);
        delta1 = delta1.add(
            Currency.wrap(address(token0)),
            int128(1000 * 1e18)
        );
        delta1 = delta1.add(
            Currency.wrap(address(token1)),
            int128(2000 * 1e18)
        );

        IPoolManager.ModifyLiquidityParams memory params1 = IPoolManager
            .ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 1000 * 1e18,
                salt: bytes32(0)
            });

        hook.afterAddLiquidity(
            address(this),
            poolKey,
            params1,
            delta1,
            BalanceDelta.wrap(0),
            ""
        );

        assertEq(
            hook.getDarkPoolLiquidity(poolId, true),
            100 * 1e18,
            "First addition tracked correctly"
        );
        assertEq(
            hook.getDarkPoolLiquidity(poolId, false),
            200 * 1e18,
            "First addition tracked correctly"
        );

        // Second addition
        hook.afterAddLiquidity(
            address(this),
            poolKey,
            params1,
            delta1,
            BalanceDelta.wrap(0),
            ""
        );

        assertEq(
            hook.getDarkPoolLiquidity(poolId, true),
            200 * 1e18,
            "Second addition tracked correctly"
        );
        assertEq(
            hook.getDarkPoolLiquidity(poolId, false),
            400 * 1e18,
            "Second addition tracked correctly"
        );

        vm.stopPrank();

        console.log("[PASS] Liquidity tracking working correctly");
    }

    function testCompleteWorkflow() public {
        console.log("=== Testing Complete Workflow ===");

        console.log("1. Initializing pool...");
        vm.startPrank(address(poolManager));
        hook.beforeInitialize(address(this), poolKey, 0);
        hook.afterInitialize(address(this), poolKey, 0, 0);
        vm.stopPrank();

        console.log("2. Adding liquidity...");
        vm.startPrank(address(poolManager));
        BalanceDelta delta = BalanceDelta.wrap(0);
        delta = delta.add(Currency.wrap(address(token0)), int128(10000 * 1e18));
        delta = delta.add(Currency.wrap(address(token1)), int128(20000 * 1e18));

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager
            .ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 10000 * 1e18,
                salt: bytes32(0)
            });

        hook.afterAddLiquidity(
            address(this),
            poolKey,
            params,
            delta,
            BalanceDelta.wrap(0),
            ""
        );
        vm.stopPrank();

        console.log("3. Configuring pool for optimal trading...");
        hook.configurePool(
            poolId,
            true,
            50,
            1 * 1e18,
            1000 * 1e18,
            1 hours,
            false
        );

        console.log("4. Executing large swap (should route to dark pool)...");
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -100 * 1e18, // Large order
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        hook.beforeSwap(alice, poolKey, swapParams, "");

        console.log("5. Verifying order creation...");
        uint256[] memory aliceOrders = hook.getTraderOrders(alice);
        assertEq(aliceOrders.length, 1, "Order should be created");

        DarkPoolHook.DarkPoolOrder memory order = hook.getOrder(1);
        assertEq(order.trader, alice, "Order trader correct");
        assertEq(order.amountIn, 100 * 1e18, "Order amount correct");
        assertTrue(order.isActive, "Order should be active");

        console.log("6. Testing order cancellation...");
        vm.prank(alice);
        hook.cancelOrder(1);

        order = hook.getOrder(1);
        assertFalse(order.isActive, "Order should be cancelled");

        console.log("7. Executing small swap (should route to AMM)...");
        swapParams.amountSpecified = -0.5 * 1e18; // Small order

        vm.prank(address(poolManager));
        (
            bytes4 selector,
            BeforeSwapDelta swapDelta,
            uint24 lpFeeOverride
        ) = hook.beforeSwap(bob, poolKey, swapParams, "");

        // Small order should not create dark pool order
        uint256[] memory bobOrders = hook.getTraderOrders(bob);
        assertEq(bobOrders.length, 0, "Bob should have no dark pool orders");

        console.log("[PASS] Complete workflow executed successfully!");
    }

    function testFuzzOrderCreation(uint256 amount, bool zeroForOne) public {
        // Bound the amount to reasonable values
        amount = bound(amount, 0.001 ether, 1000 ether);

        // Initialize pool and add liquidity
        testAfterAddLiquidity();

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amount),
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        hook.beforeSwap(alice, poolKey, params, "");

        // Verify order was created with correct parameters
        DarkPoolHook.DarkPoolOrder memory order = hook.getOrder(
            hook.nextOrderId() - 1
        );
        assertEq(order.trader, alice, "Fuzz: Order trader should be Alice");
        assertEq(
            order.amountIn,
            amount,
            "Fuzz: Order amount should match input"
        );
        assertEq(
            order.isZeroForOne,
            zeroForOne,
            "Fuzz: Order direction should match"
        );
        assertTrue(order.isActive, "Fuzz: Order should be active");
    }
}
