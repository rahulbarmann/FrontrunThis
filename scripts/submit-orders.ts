import { ethers } from "ethers";
import dotenv from "dotenv";

dotenv.config();

async function main() {
    console.log("🎯 DarkPool Order Submission Demo");

    const provider = new ethers.JsonRpcProvider(
        process.env.RPC_URL || "http://localhost:8545"
    );
    const wallet = new ethers.Wallet(
        process.env.PRIVATE_KEY ||
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        provider
    );

    console.log("Submitter address:", wallet.address);

    // Sample orders for testing
    const orders = [
        {
            trader: wallet.address,
            tokenIn: "0x1111111111111111111111111111111111111111", // Mock USDC
            tokenOut: "0x2222222222222222222222222222222222222222", // Mock WETH
            amountIn: ethers.parseEther("1000"), // 1000 USDC
            minAmountOut: ethers.parseEther("0.5"), // 0.5 WETH minimum
            deadline: Math.floor(Date.now() / 1000) + 3600,
            nonce: BigInt(1),
        },
        {
            trader: ethers.Wallet.createRandom().address,
            tokenIn: "0x2222222222222222222222222222222222222222", // Mock WETH
            tokenOut: "0x1111111111111111111111111111111111111111", // Mock USDC
            amountIn: ethers.parseEther("0.5"), // 0.5 WETH
            minAmountOut: ethers.parseEther("950"), // 950 USDC minimum
            deadline: Math.floor(Date.now() / 1000) + 3600,
            nonce: BigInt(2),
        },
    ];

    console.log("\n📋 Sample Orders:");
    orders.forEach((order, i) => {
        console.log(`\nOrder ${i + 1}:`);
        console.log(`  Trader: ${order.trader.slice(0, 8)}...`);
        console.log(
            `  ${ethers.formatEther(order.amountIn)} ${order.tokenIn.slice(
                0,
                8
            )}... → ${order.tokenOut.slice(0, 8)}...`
        );
        console.log(`  Min output: ${ethers.formatEther(order.minAmountOut)}`);
    });

    console.log("\n✅ Order submission simulation complete!");
    console.log("💡 In a real implementation, these orders would be:");
    console.log("   1. Signed by the traders");
    console.log("   2. Submitted to the AVS task manager");
    console.log("   3. Processed by the matching engine");
    console.log("   4. Committed to batches with privacy guarantees");
}

main().catch(console.error);
