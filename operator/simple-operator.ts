import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

async function main() {
    console.log("🤖 Simple DarkPool Operator Starting...");

    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    const wallet = new ethers.Wallet(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        provider
    );

    console.log("Operator address:", wallet.address);

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

    try {
        // Register as operator if not already
        const isOperator = await darkPool.operators(wallet.address);
        if (!isOperator) {
            console.log("📝 Registering as operator...");
            const tx = await darkPool.registerOperator({
                value: ethers.parseEther("1"),
            });
            await tx.wait();
            console.log("✅ Registered as operator");
        } else {
            console.log("✅ Already registered as operator");
        }

        console.log("👀 Monitoring for order submissions...");

        // Listen for order submissions
        darkPool.on(
            "OrderSubmitted",
            async (orderHash: string, trader: string) => {
                console.log(`📋 New order detected:`);
                console.log(`   Hash: ${orderHash.slice(0, 10)}...`);
                console.log(`   Trader: ${trader.slice(0, 8)}...`);

                try {
                    const order = await darkPool.getOrder(orderHash);
                    console.log(
                        `   Amount: ${ethers.formatEther(
                            order.amountIn
                        )} ${order.tokenIn.slice(0, 8)}...`
                    );
                    console.log(`   Target: ${order.tokenOut.slice(0, 8)}...`);
                } catch (err) {
                    console.log(`   (Could not fetch order details: ${err})`);
                }
            }
        );

        // Listen for batch commits
        darkPool.on(
            "BatchCommitted",
            async (
                merkleRoot: string,
                operator: string,
                tradeCount: bigint
            ) => {
                console.log(`📦 Batch committed:`);
                console.log(`   Merkle root: ${merkleRoot.slice(0, 10)}...`);
                console.log(`   Operator: ${operator.slice(0, 8)}...`);
                console.log(`   Trade count: ${tradeCount.toString()}`);
            }
        );

        // Listen for trade settlements
        darkPool.on(
            "TradeSettled",
            async (
                tradeHash: string,
                buyer: string,
                seller: string,
                price: bigint,
                quantity: bigint
            ) => {
                console.log(`⚖️ Trade settled:`);
                console.log(`   Hash: ${tradeHash.slice(0, 10)}...`);
                console.log(`   Buyer: ${buyer.slice(0, 8)}...`);
                console.log(`   Seller: ${seller.slice(0, 8)}...`);
                console.log(`   Price: ${ethers.formatEther(price)}`);
                console.log(`   Quantity: ${ethers.formatEther(quantity)}`);
            }
        );

        console.log("✅ Operator running. Press Ctrl+C to stop.");

        // Keep alive
        setInterval(() => {
            // Heartbeat
        }, 30000);
    } catch (error) {
        console.error("❌ Operator failed:", error);
        process.exit(1);
    }
}

// Handle graceful shutdown
process.on("SIGINT", () => {
    console.log("\n👋 Shutting down operator...");
    process.exit(0);
});

main().catch(console.error);
