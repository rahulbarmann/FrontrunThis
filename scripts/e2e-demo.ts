import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

async function main() {
    console.log("🎪 DarkPool v4 End-to-End Demo\n");

    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    const wallet = new ethers.Wallet(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        provider
    );

    // Get the latest deployed contract address from broadcast files
    const broadcastDir = path.join(
        __dirname,
        "..",
        "contracts",
        "broadcast",
        "DarkPoolDeployer.s.sol",
        "31337"
    );
    const latestFile = path.join(broadcastDir, "run-latest.json");

    let contractAddress: string;

    if (fs.existsSync(latestFile)) {
        const broadcastData = JSON.parse(fs.readFileSync(latestFile, "utf8"));
        contractAddress = broadcastData.transactions[0].contractAddress;
        console.log(
            "📄 Contract address loaded from broadcast:",
            contractAddress
        );
    } else {
        // Fallback to hardcoded address
        contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
        console.log("⚠️  Using fallback contract address:", contractAddress);
    }

    // Load ABI
    const abiPath = path.join(__dirname, "..", "abis", "SimpleDarkPool.json");
    const abi = JSON.parse(fs.readFileSync(abiPath, "utf8"));
    const darkPool = new ethers.Contract(contractAddress, abi, wallet);

    console.log("🔗 Connected to SimpleDarkPool");
    console.log("   Address:", contractAddress);
    console.log("   Operator:", wallet.address);

    try {
        // Step 1: Register as operator (if not already)
        console.log("\n📝 Step 1: Registering as operator...");

        // Get current nonce and track it
        let currentNonce = await provider.getTransactionCount(wallet.address);

        const isOperator = await darkPool.operators(wallet.address);

        if (!isOperator) {
            const registerTx = await darkPool.registerOperator({
                value: ethers.parseEther("1"),
                nonce: currentNonce,
            });
            await registerTx.wait();
            currentNonce++;
            console.log("   ✅ Registered as operator");
        } else {
            console.log("   ✅ Already registered as operator");
        }

        // Step 2: Submit multiple orders
        console.log("\n📋 Step 2: Submitting orders...");

        // Get current nonce to avoid conflicts
        const baseTimestamp = Math.floor(Date.now() / 1000);
        console.log(`   Current transaction nonce: ${currentNonce}`);

        const orders = [
            {
                trader: wallet.address,
                tokenIn: "0x1111111111111111111111111111111111111111", // USDC
                tokenOut: "0x2222222222222222222222222222222222222222", // WETH
                amountIn: ethers.parseEther("1000"),
                minAmountOut: ethers.parseEther("0.5"),
                nonce: BigInt(
                    baseTimestamp * 1000 +
                        100 +
                        Math.floor(Math.random() * 1000)
                ),
                deadline: Math.floor(Date.now() / 1000) + 3600,
                isBuy: true,
            },
            {
                trader: wallet.address, // Use same wallet for demo purposes
                tokenIn: "0x2222222222222222222222222222222222222222", // WETH
                tokenOut: "0x1111111111111111111111111111111111111111", // USDC
                amountIn: ethers.parseEther("0.5"),
                minAmountOut: ethers.parseEther("950"),
                nonce: BigInt(
                    baseTimestamp * 1000 +
                        200 +
                        Math.floor(Math.random() * 1000)
                ),
                deadline: Math.floor(Date.now() / 1000) + 3600,
                isBuy: false,
            },
        ];

        const orderHashes: string[] = [];

        for (let i = 0; i < orders.length; i++) {
            // For demo purposes, we'll sign the order as the wallet owner
            // In reality, each trader would sign their own order
            const orderTx = await darkPool.submitOrder(orders[i], {
                nonce: currentNonce,
            });
            const receipt = await orderTx.wait();
            currentNonce++;

            // Extract order hash from events
            const orderEvent = receipt.logs.find(
                (log: any) =>
                    log.topics[0] ===
                    darkPool.interface.getEvent("OrderSubmitted")?.topicHash
            );

            if (orderEvent) {
                const decoded = darkPool.interface.parseLog(orderEvent);
                if (decoded) {
                    orderHashes.push(decoded.args[0]);
                    console.log(
                        `   ✅ Order ${
                            i + 1
                        } submitted: ${decoded.args[0].slice(0, 10)}...`
                    );
                }
            }
        }

        // Step 3: Create and commit a batch
        console.log("\n📦 Step 3: Creating trade batch...");

        // Create a simple trade between the orders
        const trade = {
            buyOrderHash: orderHashes[0] || ethers.ZeroHash,
            sellOrderHash: orderHashes[1] || ethers.ZeroHash,
            price: ethers.parseEther("1900"), // 1900 USDC per WETH
            quantity: ethers.parseEther("0.5"),
            timestamp: Math.floor(Date.now() / 1000),
        };

        // Create merkle tree with single trade (simplified)
        const tradeHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
                ["bytes32", "bytes32", "uint256", "uint256", "uint256"],
                [
                    trade.buyOrderHash,
                    trade.sellOrderHash,
                    trade.price,
                    trade.quantity,
                    trade.timestamp,
                ]
            )
        );

        const merkleRoot = tradeHash; // Single leaf = root

        console.log("   📝 Trade created:");
        console.log(
            "      Price:",
            ethers.formatEther(trade.price),
            "USDC per WETH"
        );
        console.log(
            "      Quantity:",
            ethers.formatEther(trade.quantity),
            "WETH"
        );
        console.log("      Trade hash:", tradeHash.slice(0, 10) + "...");

        // Commit batch
        const commitTx = await darkPool.commitBatch(merkleRoot, 1, {
            nonce: currentNonce,
        });
        await commitTx.wait();
        currentNonce++;
        console.log(
            "   ✅ Batch committed with merkle root:",
            merkleRoot.slice(0, 10) + "..."
        );

        // Step 4: Settle the trade
        console.log("\n⚖️ Step 4: Settling trade...");

        const proof: string[] = []; // Empty proof for single leaf
        const settleTx = await darkPool.settleTrade(trade, proof, merkleRoot, {
            nonce: currentNonce,
        });
        const settleReceipt = await settleTx.wait();
        currentNonce++;

        console.log("   ✅ Trade settled successfully");
        console.log("   📊 Gas used:", settleReceipt.gasUsed.toString());

        // Step 5: Verify settlement
        console.log("\n✅ Step 5: Verifying settlement...");

        const isSettled = await darkPool.isTradeSettled(tradeHash);
        const batch = await darkPool.getBatch(merkleRoot);

        console.log("   Trade settled:", isSettled);
        console.log("   Batch committed:", batch.isCommitted);
        console.log("   Batch operator:", batch.operator);
        console.log("   Trade count:", batch.tradeCount.toString());

        console.log("\n🎉 End-to-End Demo Complete!");
        console.log("\n📊 Summary:");
        console.log("   ✅ Operator registration");
        console.log("   ✅ Order submission (2 orders)");
        console.log("   ✅ Trade matching");
        console.log("   ✅ Batch commitment");
        console.log("   ✅ Trade settlement with merkle proof");
        console.log("   ✅ Settlement verification");
    } catch (error) {
        console.error("❌ Demo failed:", error);
        process.exit(1);
    }
}

main().catch(console.error);
