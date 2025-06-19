import { ethers } from "ethers";
import dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";

dotenv.config();

// Setup env variables
const provider = new ethers.JsonRpcProvider(
    process.env.RPC_URL || "http://localhost:8545"
);
const wallet = new ethers.Wallet(
    process.env.PRIVATE_KEY ||
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    provider
);

console.log("Task creator address:", wallet.address);

const chainId = 31337;

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

const darkpoolDeploymentData = loadDeploymentData(`darkpool/${chainId}.json`);
const darkpoolServiceManagerAddress =
    darkpoolDeploymentData.addresses.darkpoolServiceManager;

// Load ABI
const loadABI = (filename: string) => {
    const abiPath = path.join(__dirname, "..", "abis", `${filename}.json`);
    return JSON.parse(fs.readFileSync(abiPath, "utf8"));
};

const darkpoolServiceManagerABI = loadABI("DarkPoolServiceManager");
const darkpoolServiceManager = new ethers.Contract(
    darkpoolServiceManagerAddress,
    darkpoolServiceManagerABI,
    wallet
);

// Sample token addresses (mock tokens for testing)
const TOKENS = [
    "0x1111111111111111111111111111111111111111", // Mock USDC
    "0x2222222222222222222222222222222222222222", // Mock WETH
    "0x3333333333333333333333333333333333333333", // Mock WBTC
    "0x4444444444444444444444444444444444444444", // Mock DAI
];

// Generate random trader address
const generateRandomTrader = (): string => {
    return ethers.Wallet.createRandom().address;
};

// Generate random order
const generateRandomOrder = () => {
    const trader = generateRandomTrader();
    const tokenInIndex = Math.floor(Math.random() * TOKENS.length);
    let tokenOutIndex = Math.floor(Math.random() * TOKENS.length);

    // Ensure different tokens
    while (tokenOutIndex === tokenInIndex) {
        tokenOutIndex = Math.floor(Math.random() * TOKENS.length);
    }

    const tokenIn = TOKENS[tokenInIndex];
    const tokenOut = TOKENS[tokenOutIndex];
    const amountIn = ethers.parseEther((Math.random() * 100 + 1).toFixed(6)); // 1-100 tokens
    const minAmountOut = ethers.parseEther((Math.random() * 50 + 1).toFixed(6)); // 1-50 tokens
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const nonce = BigInt(Math.floor(Math.random() * 1000000));

    return {
        trader,
        tokenIn,
        tokenOut,
        amountIn,
        minAmountOut,
        deadline,
        nonce,
    };
};

// Create order matching task
async function createOrderMatchingTask(orderData: string) {
    try {
        console.log("Creating order matching task...");

        const tx = await darkpoolServiceManager.createOrderMatchingTask(
            orderData
        );
        const receipt = await tx.wait();

        console.log(`✅ Order matching task created: ${tx.hash}`);
        console.log(
            `Block: ${receipt.blockNumber}, Gas used: ${receipt.gasUsed}`
        );

        return receipt;
    } catch (error) {
        console.error("❌ Failed to create order matching task:", error);
        throw error;
    }
}

// Create batch commitment task
async function createBatchCommitmentTask(
    batchData: string,
    merkleRoot: string
) {
    try {
        console.log("Creating batch commitment task...");

        const tx = await darkpoolServiceManager.createBatchCommitmentTask(
            batchData,
            merkleRoot
        );
        const receipt = await tx.wait();

        console.log(`✅ Batch commitment task created: ${tx.hash}`);
        console.log(
            `Block: ${receipt.blockNumber}, Gas used: ${receipt.gasUsed}`
        );

        return receipt;
    } catch (error) {
        console.error("❌ Failed to create batch commitment task:", error);
        throw error;
    }
}

// Function to continuously create random tasks
function startCreatingTasks() {
    console.log("🚀 Starting to create random dark pool tasks...");

    setInterval(async () => {
        try {
            const taskType = Math.random() > 0.5 ? "order" : "batch";

            if (taskType === "order") {
                // Create order matching task
                const order = generateRandomOrder();
                const orderData = JSON.stringify(order);

                console.log(
                    `\n📋 Creating order matching task for ${order.trader.slice(
                        0,
                        8
                    )}...`
                );
                console.log(
                    `Order: ${ethers.formatEther(
                        order.amountIn
                    )} ${order.tokenIn.slice(0, 8)}... → ${order.tokenOut.slice(
                        0,
                        8
                    )}...`
                );

                await createOrderMatchingTask(orderData);
            } else {
                // Create batch commitment task
                const batchData = JSON.stringify({
                    orders: [generateRandomOrder(), generateRandomOrder()],
                    timestamp: Math.floor(Date.now() / 1000),
                    batchId: Math.floor(Math.random() * 1000000),
                });

                // Generate mock merkle root
                const merkleRoot = ethers.keccak256(
                    ethers.toUtf8Bytes(batchData)
                );

                console.log(`\n📦 Creating batch commitment task...`);
                console.log(`Merkle root: ${merkleRoot.slice(0, 10)}...`);

                await createBatchCommitmentTask(batchData, merkleRoot);
            }
        } catch (error) {
            console.error("❌ Error creating task:", error);
        }
    }, 15000); // Create new task every 15 seconds
}

// Test function to create a single task
async function createSingleTask() {
    console.log("🧪 Creating a single test task...");

    const order = generateRandomOrder();
    const orderData = JSON.stringify(order);

    console.log("Test order:", {
        trader: order.trader.slice(0, 8) + "...",
        tokenIn: order.tokenIn.slice(0, 8) + "...",
        tokenOut: order.tokenOut.slice(0, 8) + "...",
        amountIn: ethers.formatEther(order.amountIn),
        minAmountOut: ethers.formatEther(order.minAmountOut),
    });

    await createOrderMatchingTask(orderData);
}

// Main function
const main = async () => {
    console.log("🎯 DarkPool Task Creator");
    console.log("Creator Address:", wallet.address);
    console.log("DarkPool Service Manager:", darkpoolServiceManagerAddress);

    try {
        // Check if we should create a single task or continuous tasks
        const args = process.argv.slice(2);

        if (args.includes("--single")) {
            await createSingleTask();
            process.exit(0);
        } else {
            startCreatingTasks();
            console.log("✅ Task creator is running. Press Ctrl+C to stop.");
        }
    } catch (error) {
        console.error("❌ Task creator failed to start:", error);
        process.exit(1);
    }
};

// Handle graceful shutdown
process.on("SIGINT", () => {
    console.log("\n👋 Shutting down task creator...");
    process.exit(0);
});

// Start the task creator
main().catch(console.error);
