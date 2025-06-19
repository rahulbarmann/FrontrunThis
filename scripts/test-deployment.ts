import { ethers } from "ethers";
import dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";

dotenv.config();

async function main() {
    console.log("🧪 Testing SimpleDarkPool Deployment");

    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    const wallet = new ethers.Wallet(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        provider
    );

    // Load the ABI
    const abiPath = path.join(__dirname, "..", "abis", "SimpleDarkPool.json");
    const abi = JSON.parse(fs.readFileSync(abiPath, "utf8"));

    // Contract address from deployment
    const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

    const darkPool = new ethers.Contract(contractAddress, abi, wallet);

    console.log("Contract address:", contractAddress);
    console.log("Wallet address:", wallet.address);

    try {
        // Test 1: Check contract owner
        const owner = await darkPool.owner();
        console.log("✅ Contract owner:", owner);

        // Test 2: Register as operator
        console.log("📝 Registering as operator...");
        const registerTx = await darkPool.registerOperator({
            value: ethers.parseEther("1"),
        });
        await registerTx.wait();
        console.log("✅ Registered as operator");

        // Test 3: Check operator status
        const isOperator = await darkPool.operators(wallet.address);
        const stake = await darkPool.operatorStake(wallet.address);
        console.log("✅ Operator status:", isOperator);
        console.log("✅ Operator stake:", ethers.formatEther(stake), "ETH");

        // Test 4: Submit an order
        console.log("📋 Submitting a test order...");
        const order = {
            trader: wallet.address,
            tokenIn: "0x1111111111111111111111111111111111111111",
            tokenOut: "0x2222222222222222222222222222222222222222",
            amountIn: ethers.parseEther("100"),
            minAmountOut: ethers.parseEther("0.05"),
            nonce: Date.now(),
            deadline: Math.floor(Date.now() / 1000) + 3600,
            isBuy: true,
        };

        const submitTx = await darkPool.submitOrder(order);
        const receipt = await submitTx.wait();
        console.log("✅ Order submitted, tx hash:", receipt.hash);

        // Extract order hash from events
        const orderSubmittedEvent = receipt.logs.find(
            (log: any) =>
                log.topics[0] ===
                darkPool.interface.getEvent("OrderSubmitted")?.topicHash
        );

        if (orderSubmittedEvent) {
            const decodedEvent =
                darkPool.interface.parseLog(orderSubmittedEvent);
            if (decodedEvent) {
                const orderHash = decodedEvent.args[0];
                console.log("✅ Order hash:", orderHash);

                // Test 5: Retrieve the order
                const retrievedOrder = await darkPool.getOrder(orderHash);
                console.log(
                    "✅ Retrieved order trader:",
                    retrievedOrder.trader
                );
                console.log(
                    "✅ Retrieved order amount:",
                    ethers.formatEther(retrievedOrder.amountIn)
                );
            }
        }

        console.log(
            "\n🎉 All tests passed! SimpleDarkPool is working correctly."
        );
    } catch (error) {
        console.error("❌ Test failed:", error);
        process.exit(1);
    }
}

main().catch(console.error);
