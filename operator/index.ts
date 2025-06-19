import { ethers } from "ethers";
import dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";

dotenv.config();

// Check if the process.env object is empty
if (!process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY not found in environment variables");
}

// Setup env variables
const provider = new ethers.JsonRpcProvider(
    process.env.RPC_URL || "http://localhost:8545"
);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
console.log("Operator address:", wallet.address);

const chainId = 31337; // Local anvil chain ID

// Load deployment data
const loadDeploymentData = (filename: string) => {
    const filePath = path.join(
        __dirname,
        "..",
        "contracts",
        "config",
        filename
    );
    if (fs.existsSync(filePath)) {
        const data = fs.readFileSync(filePath, "utf8");
        return JSON.parse(data);
    }
    throw new Error(`Deployment file not found: ${filePath}`);
};

// Load core deployment data
const coreDeploymentData = loadDeploymentData(`core/${chainId}.json`);
const darkpoolDeploymentData = loadDeploymentData(`darkpool/${chainId}.json`);

// Contract addresses
const delegationManagerAddress = coreDeploymentData.addresses.delegationManager;
const avsDirectoryAddress = coreDeploymentData.addresses.avsDirectory;
const darkpoolServiceManagerAddress =
    darkpoolDeploymentData.addresses.darkpoolServiceManager;
const darkpoolTaskManagerAddress =
    darkpoolDeploymentData.addresses.darkpoolTaskManager;

// Load ABIs
const loadABI = (filename: string) => {
    const abiPath = path.join(__dirname, "..", "abis", `${filename}.json`);
    return JSON.parse(fs.readFileSync(abiPath, "utf8"));
};

const delegationManagerABI = loadABI("IDelegationManager");
const avsDirectoryABI = loadABI("IAVSDirectory");
const darkpoolServiceManagerABI = loadABI("DarkPoolServiceManager");
const darkpoolTaskManagerABI = loadABI("DarkPoolTaskManager");

// Initialize contract objects
const delegationManager = new ethers.Contract(
    delegationManagerAddress,
    delegationManagerABI,
    wallet
);
const avsDirectory = new ethers.Contract(
    avsDirectoryAddress,
    avsDirectoryABI,
    wallet
);
const darkpoolServiceManager = new ethers.Contract(
    darkpoolServiceManagerAddress,
    darkpoolServiceManagerABI,
    wallet
);
const darkpoolTaskManager = new ethers.Contract(
    darkpoolTaskManagerAddress,
    darkpoolTaskManagerABI,
    wallet
);

// Order and trade types
interface Order {
    trader: string;
    tokenIn: string;
    tokenOut: string;
    amountIn: bigint;
    minAmountOut: bigint;
    deadline: number;
    nonce: bigint;
}

interface TradeMatch {
    buyOrder: Order;
    sellOrder: Order;
    executionPrice: bigint;
    timestamp: number;
}

// Matching engine logic
class MatchingEngine {
    private pendingOrders: Order[] = [];

    addOrder(order: Order): void {
        this.pendingOrders.push(order);
        console.log(
            `Added order: ${order.trader} wants ${ethers.formatEther(
                order.amountIn
            )} ${order.tokenIn} for ${order.tokenOut}`
        );
    }

    findMatches(): TradeMatch[] {
        const matches: TradeMatch[] = [];

        // Simple price-time priority matching
        for (let i = 0; i < this.pendingOrders.length; i++) {
            for (let j = i + 1; j < this.pendingOrders.length; j++) {
                const order1 = this.pendingOrders[i];
                const order2 = this.pendingOrders[j];

                // Check if orders can be matched (opposite direction)
                if (
                    order1.tokenIn === order2.tokenOut &&
                    order1.tokenOut === order2.tokenIn &&
                    order1.trader !== order2.trader
                ) {
                    // Simple price matching logic
                    const executionPrice =
                        (order1.minAmountOut + order2.minAmountOut) / 2n;

                    const match: TradeMatch = {
                        buyOrder: order1,
                        sellOrder: order2,
                        executionPrice,
                        timestamp: Math.floor(Date.now() / 1000),
                    };

                    matches.push(match);

                    // Remove matched orders
                    this.pendingOrders.splice(Math.max(i, j), 1);
                    this.pendingOrders.splice(Math.min(i, j), 1);

                    console.log(
                        `Matched orders: ${order1.trader} <-> ${
                            order2.trader
                        } at price ${ethers.formatEther(executionPrice)}`
                    );
                    break;
                }
            }
        }

        return matches;
    }

    getPendingOrdersCount(): number {
        return this.pendingOrders.length;
    }
}

const matchingEngine = new MatchingEngine();

// Sign and respond to dark pool tasks
const signAndRespondToTask = async (
    taskIndex: number,
    taskCreatedBlock: number,
    orderData: string
) => {
    console.log(`Operator responding to task ${taskIndex}`);

    try {
        // Parse order data and add to matching engine
        const order = JSON.parse(orderData) as Order;
        matchingEngine.addOrder(order);

        // Find matches
        const matches = matchingEngine.findMatches();

        // Create response (simplified - in production would use proper cryptographic commitments)
        const response = {
            matches: matches.length,
            pendingOrders: matchingEngine.getPendingOrdersCount(),
            timestamp: Math.floor(Date.now() / 1000),
        };

        const messageHash = ethers.keccak256(
            ethers.toUtf8Bytes(JSON.stringify(response))
        );
        const messageBytes = ethers.getBytes(messageHash);
        const signature = await wallet.signMessage(messageBytes);

        // Submit response to contract
        console.log(`Submitting response for task ${taskIndex}:`, response);

        const tx = await darkpoolTaskManager.respondToTask(
            taskIndex,
            taskCreatedBlock,
            messageHash,
            signature
        );

        await tx.wait();
        console.log(`✅ Task ${taskIndex} response submitted: ${tx.hash}`);

        return response;
    } catch (error) {
        console.error(`❌ Error responding to task ${taskIndex}:`, error);
    }
};

// Register operator
const registerOperator = async () => {
    try {
        console.log("Registering operator to EigenLayer...");

        // Register as operator in EigenLayer
        if (!(await delegationManager.isOperator(wallet.address))) {
            console.log("Not registered as operator, registering...");

            const tx1 = await delegationManager.registerAsOperator(
                {
                    earningsReceiver: wallet.address,
                    delegationApprover:
                        "0x0000000000000000000000000000000000000000",
                    stakerOptOutWindowBlocks: 0,
                },
                ""
            );

            await tx1.wait();
            console.log("✅ Registered as EigenLayer operator");
        }

        // Register to AVS
        console.log("Registering to DarkPool AVS...");

        const salt = ethers.hexlify(ethers.randomBytes(32));
        const expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

        // Create signature for AVS registration
        const digestHash =
            await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
                wallet.address,
                darkpoolServiceManagerAddress,
                salt,
                expiry
            );

        const signature = await wallet.signMessage(ethers.getBytes(digestHash));

        const operatorSignature = {
            signature: signature,
            salt: salt,
            expiry: expiry,
        };

        const tx2 = await darkpoolServiceManager.registerOperatorToAVS(
            wallet.address,
            operatorSignature
        );
        await tx2.wait();

        console.log("✅ Registered to DarkPool AVS");
    } catch (error) {
        console.error("❌ Registration failed:", error);
        throw error;
    }
};

// Monitor new tasks
const monitorNewTasks = async () => {
    console.log("👀 Monitoring for new tasks...");

    darkpoolTaskManager.on(
        "NewOrderMatchingTask",
        async (taskIndex: number, task: any, taskCreatedBlock: number) => {
            console.log(
                `📋 New order matching task ${taskIndex} created at block ${taskCreatedBlock}`
            );
            await signAndRespondToTask(
                taskIndex,
                taskCreatedBlock,
                task.orderData
            );
        }
    );

    darkpoolTaskManager.on(
        "NewBatchCommitmentTask",
        async (taskIndex: number, task: any, taskCreatedBlock: number) => {
            console.log(
                `📦 New batch commitment task ${taskIndex} created at block ${taskCreatedBlock}`
            );
            // Handle batch commitment task
        }
    );
};

// Main function
const main = async () => {
    console.log("🚀 Starting DarkPool AVS Operator...");
    console.log("Operator Address:", wallet.address);
    console.log("DarkPool Service Manager:", darkpoolServiceManagerAddress);
    console.log("DarkPool Task Manager:", darkpoolTaskManagerAddress);

    try {
        await registerOperator();
        await monitorNewTasks();

        console.log("✅ Operator is running and monitoring for tasks...");

        // Keep the process alive
        process.stdin.resume();
    } catch (error) {
        console.error("❌ Operator failed to start:", error);
        process.exit(1);
    }
};

// Handle graceful shutdown
process.on("SIGINT", () => {
    console.log("\n👋 Shutting down operator...");
    process.exit(0);
});

// Start the operator
main().catch(console.error);
