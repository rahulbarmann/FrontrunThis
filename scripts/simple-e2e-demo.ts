import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

async function main() {
    console.log("🎪 Simple DarkPool Demo\n");

    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    const wallet = new ethers.Wallet(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        provider
    );

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
        console.error("❌ No deployment found");
        process.exit(1);
    }

    const broadcastData = JSON.parse(fs.readFileSync(latestFile, "utf8"));
    const contractAddress = broadcastData.transactions[0].contractAddress;

    // Load ABI
    const abiPath = path.join(__dirname, "..", "abis", "SimpleDarkPool.json");
    const abi = JSON.parse(fs.readFileSync(abiPath, "utf8"));
    const darkPool = new ethers.Contract(contractAddress, abi, wallet);

    console.log("🔗 Connected to SimpleDarkPool:", contractAddress);

    try {
        // Check current nonce
        let currentNonce = await provider.getTransactionCount(wallet.address);
        console.log(`📋 Current nonce: ${currentNonce}`);

        // Step 1: Register as operator if needed
        const isOperator = await darkPool.operators(wallet.address);
        if (!isOperator) {
            console.log("📝 Registering as operator...");
            const tx = await darkPool.registerOperator({
                value: ethers.parseEther("1"),
                nonce: currentNonce,
            });
            await tx.wait();
            currentNonce++;
            console.log("   ✅ Registered");
        } else {
            console.log("✅ Already registered as operator");
        }

        // Step 2: Submit a single order
        console.log("\n📋 Submitting test order...");

        // Use order nonce (not transaction nonce) - this is different and can be any unique value
        const orderNonce = BigInt(
            Math.floor(Date.now() / 1000) * 1000 +
                Math.floor(Math.random() * 1000)
        );

        const order = {
            trader: wallet.address,
            tokenIn: "0x1111111111111111111111111111111111111111",
            tokenOut: "0x2222222222222222222222222222222222222222",
            amountIn: ethers.parseEther("100"),
            minAmountOut: ethers.parseEther("0.05"),
            nonce: orderNonce, // This is the order nonce, not transaction nonce
            deadline: Math.floor(Date.now() / 1000) + 3600,
            isBuy: true,
        };

        const orderTx = await darkPool.submitOrder(order, {
            nonce: currentNonce,
        });
        const receipt = await orderTx.wait();
        currentNonce++;

        // Extract order hash
        let orderHash = "";
        for (const log of receipt.logs) {
            try {
                const parsed = darkPool.interface.parseLog(log);
                if (parsed && parsed.name === "OrderSubmitted") {
                    orderHash = parsed.args[0];
                    break;
                }
            } catch (e) {
                // Skip unparseable logs
            }
        }

        console.log("   ✅ Order submitted:", orderHash.slice(0, 10) + "...");

        // Step 3: Create and commit a simple batch
        console.log("\n📦 Committing batch...");
        const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test-batch"));

        const commitTx = await darkPool.commitBatch(merkleRoot, 1, {
            nonce: currentNonce,
        });
        await commitTx.wait();
        currentNonce++;
        console.log("   ✅ Batch committed:", merkleRoot.slice(0, 10) + "...");

        // Step 4: Verify batch
        console.log("\n✅ Verifying batch...");
        const batch = await darkPool.getBatch(merkleRoot);
        console.log("   Operator:", batch.operator.slice(0, 8) + "...");
        console.log("   Trade count:", batch.tradeCount.toString());
        console.log("   Committed:", batch.isCommitted);

        console.log("\n🎉 Demo Complete!");
        console.log("📊 Summary:");
        console.log("   ✅ Operator registration");
        console.log("   ✅ Order submission");
        console.log("   ✅ Batch commitment");
        console.log("   ✅ State verification");
    } catch (error) {
        console.error("❌ Demo failed:", error);
        process.exit(1);
    }
}

main().catch(console.error);
