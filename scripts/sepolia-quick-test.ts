import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

// Sepolia deployment details
const SEPOLIA_CONTRACT_ADDRESS = "0x1f81Ce633E74577F43D56FB15858dB972690e089";
const SEPOLIA_RPC_URL =
    "https://eth-sepolia.g.alchemy.com/v2/Qni5DNYIj8aY6BZJAAicj";
const PRIVATE_KEY =
    "0xbf93dac6b885bd4a4fb152463d0e641c4a12d90dcea6cd74a8b0da459a0cd4ce";

async function quickTest() {
    console.log("🧪 DarkPool v4 Sepolia Quick Test");
    console.log("=".repeat(50));

    try {
        console.log("🔗 Connecting to Sepolia...");
        const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);

        // Test connection
        const blockNumber = await provider.getBlockNumber();
        console.log(`✅ Connected! Current block: ${blockNumber}`);

        const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
        const balance = await provider.getBalance(wallet.address);
        console.log(`💰 Wallet balance: ${ethers.formatEther(balance)} ETH`);

        // Load ABI and connect to contract
        const abiPath = path.join(
            __dirname,
            "..",
            "abis",
            "SimpleDarkPool.json"
        );
        const abi = JSON.parse(fs.readFileSync(abiPath, "utf8"));
        const darkPool = new ethers.Contract(
            SEPOLIA_CONTRACT_ADDRESS,
            abi,
            wallet
        );

        console.log(`📋 Contract: ${SEPOLIA_CONTRACT_ADDRESS}`);
        console.log(`👤 Wallet: ${wallet.address}`);

        // Test 1: Check if operator
        console.log("\n🔍 Test 1: Checking operator status...");
        const isOperator = await darkPool.operators(wallet.address);
        console.log(`   Is operator: ${isOperator}`);

        if (isOperator) {
            const stake = await darkPool.operatorStake(wallet.address);
            console.log(`   Stake: ${ethers.formatEther(stake)} ETH`);
        }

        // Test 2: Submit a single order (if not operator, register first)
        if (!isOperator) {
            console.log("\n📝 Test 2: Registering as operator...");
            const nonce = await provider.getTransactionCount(wallet.address);

            const registerTx = await darkPool.registerOperator({
                value: ethers.parseEther("1.0"), // 1.0 ETH (minimum required)
                nonce: nonce,
                gasLimit: 150000,
            });

            console.log(`   ⏳ Tx: ${registerTx.hash}`);
            console.log(
                `   🔍 Etherscan: https://sepolia.etherscan.io/tx/${registerTx.hash}`
            );

            const receipt = await registerTx.wait();
            console.log(`   ✅ Registered! Block: ${receipt.blockNumber}`);
        }

        // Test 3: Submit test order
        console.log("\n📋 Test 3: Submitting test order...");
        const currentNonce = await provider.getTransactionCount(wallet.address);

        const testOrder = {
            trader: wallet.address,
            tokenIn: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", // Sepolia USDC
            tokenOut: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14", // Sepolia WETH
            amountIn: ethers.parseEther("100"),
            minAmountOut: ethers.parseEther("0.05"),
            nonce: BigInt(
                Math.floor(Date.now() / 1000) * 1000 +
                    Math.floor(Math.random() * 1000)
            ),
            deadline: Math.floor(Date.now() / 1000) + 3600,
            isBuy: true,
        };

        const orderTx = await darkPool.submitOrder(testOrder, {
            nonce: currentNonce,
            gasLimit: 200000,
        });

        console.log(`   ⏳ Tx: ${orderTx.hash}`);
        console.log(
            `   🔍 Etherscan: https://sepolia.etherscan.io/tx/${orderTx.hash}`
        );

        const orderReceipt = await orderTx.wait();
        console.log(
            `   ✅ Order submitted! Block: ${orderReceipt.blockNumber}`
        );

        // Extract order hash
        let orderHash = "";
        for (const log of orderReceipt.logs) {
            try {
                const parsed = darkPool.interface.parseLog(log);
                if (parsed && parsed.name === "OrderSubmitted") {
                    orderHash = parsed.args[0];
                    break;
                }
            } catch (e) {
                // Skip
            }
        }

        if (orderHash) {
            console.log(`   📋 Order Hash: ${orderHash}`);

            // Test 4: Verify order storage
            console.log("\n✅ Test 4: Verifying order storage...");
            const storedOrder = await darkPool.getOrder(orderHash);
            console.log(`   Trader: ${storedOrder.trader}`);
            console.log(
                `   Amount: ${ethers.formatEther(storedOrder.amountIn)} USDC`
            );
            console.log(
                `   Min Out: ${ethers.formatEther(
                    storedOrder.minAmountOut
                )} WETH`
            );
        }

        console.log("\n🎉 Quick test completed successfully!");
        console.log(
            `🔗 View contract on Etherscan: https://sepolia.etherscan.io/address/${SEPOLIA_CONTRACT_ADDRESS}`
        );

        return {
            success: true,
            contractAddress: SEPOLIA_CONTRACT_ADDRESS,
            walletAddress: wallet.address,
            isOperator: await darkPool.operators(wallet.address),
            lastOrderHash: orderHash,
        };
    } catch (error) {
        console.error("❌ Quick test failed:", error);
        throw error;
    }
}

if (require.main === module) {
    quickTest()
        .then((result) => {
            console.log("\n📊 Test Results:", JSON.stringify(result, null, 2));
        })
        .catch((error) => {
            console.error("Test error:", error);
            process.exit(1);
        });
}
