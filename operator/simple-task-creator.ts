import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

async function main() {
    console.log("🎯 Simple Task Creator Starting...");

    const provider = new ethers.JsonRpcProvider("http://localhost:8545");

    // Use different account for task creation
    const wallet = new ethers.Wallet(
        "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
        provider
    );

    console.log("Task creator address:", wallet.address);

    // Get contract address from broadcast
    const broadcastDir = path.join(
        __dirname,
        "..",
        "contracts",
        "broadcast",
        "DarkPoolDeployer.s.sol",
        "31337"
    );
    const latestFile = path.join(broadcastDir, "run-latest.json");

    if (!fs.existsSync(latestFile)) {
        console.error("❌ No deployment found. Deploy contracts first.");
        process.exit(1);
    }

    const broadcastData = JSON.parse(fs.readFileSync(latestFile, "utf8"));
    const contractAddress = broadcastData.transactions[0].contractAddress;

    // Load ABI
    const abiPath = path.join(__dirname, "..", "abis", "SimpleDarkPool.json");
    const abi = JSON.parse(fs.readFileSync(abiPath, "utf8"));
    const darkPool = new ethers.Contract(contractAddress, abi, wallet);

    console.log("📄 Contract address:", contractAddress);

    // Sample token addresses
    const TOKENS = [
        "0x1111111111111111111111111111111111111111", // Mock USDC
        "0x2222222222222222222222222222222222222222", // Mock WETH
        "0x3333333333333333333333333333333333333333", // Mock WBTC
        "0x4444444444444444444444444444444444444444", // Mock DAI
    ];

    const generateRandomOrder = () => {
        const tokenInIndex = Math.floor(Math.random() * TOKENS.length);
        let tokenOutIndex = Math.floor(Math.random() * TOKENS.length);

        // Ensure different tokens
        while (tokenOutIndex === tokenInIndex) {
            tokenOutIndex = Math.floor(Math.random() * TOKENS.length);
        }

        return {
            trader: wallet.address,
            tokenIn: TOKENS[tokenInIndex],
            tokenOut: TOKENS[tokenOutIndex],
            amountIn: ethers.parseEther((Math.random() * 100 + 1).toFixed(6)),
            minAmountOut: ethers.parseEther(
                (Math.random() * 50 + 1).toFixed(6)
            ),
            nonce: BigInt(
                Math.floor(Date.now() / 1000) * 1000 +
                    Math.floor(Math.random() * 1000)
            ),
            deadline: Math.floor(Date.now() / 1000) + 3600,
            isBuy: Math.random() > 0.5,
        };
    };

    const submitOrder = async () => {
        try {
            const order = generateRandomOrder();

            console.log(`\n📋 Submitting order:`);
            console.log(
                `   ${ethers.formatEther(order.amountIn)} ${order.tokenIn.slice(
                    0,
                    8
                )}... → ${order.tokenOut.slice(0, 8)}...`
            );
            console.log(
                `   Min output: ${ethers.formatEther(order.minAmountOut)}`
            );
            console.log(`   Type: ${order.isBuy ? "BUY" : "SELL"}`);

            const tx = await darkPool.submitOrder(order);
            const receipt = await tx.wait();

            console.log(`   ✅ Order submitted: ${tx.hash.slice(0, 10)}...`);
            console.log(`   📊 Gas used: ${receipt.gasUsed}`);
        } catch (error) {
            console.error("❌ Failed to submit order:", error);
        }
    };

    try {
        console.log("🚀 Starting periodic order submission...");
        console.log("   Submitting orders every 20 seconds");
        console.log("   Press Ctrl+C to stop");

        // Submit initial order
        await submitOrder();

        // Submit orders periodically
        setInterval(async () => {
            await submitOrder();
        }, 20000); // Every 20 seconds
    } catch (error) {
        console.error("❌ Task creator failed:", error);
        process.exit(1);
    }
}

// Handle graceful shutdown
process.on("SIGINT", () => {
    console.log("\n👋 Shutting down task creator...");
    process.exit(0);
});

main().catch(console.error);
