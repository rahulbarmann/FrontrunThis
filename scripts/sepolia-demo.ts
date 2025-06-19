import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

// Sepolia deployment details
const SEPOLIA_CONTRACT_ADDRESS = "0x1f81Ce633E74577F43D56FB15858dB972690e089";
const SEPOLIA_RPC_URL =
    "https://eth-sepolia.g.alchemy.com/v2/Qni5DNYIj8aY6BZJAAicj";
const PRIVATE_KEY =
    "0xbf93dac6b885bd4a4fb152463d0e641c4a12d90dcea6cd74a8b0da459a0cd4ce";

// Demo token addresses (using well-known Sepolia addresses for visibility)
const DEMO_TOKENS = {
    USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", // Sepolia USDC
    WETH: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14", // Sepolia WETH
    DAI: "0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6", // Sepolia DAI
    USDT: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0", // Sepolia USDT
};

async function main() {
    console.log("🚀 DarkPool v4 Sepolia Testnet Comprehensive Demo");
    console.log("=".repeat(60));
    console.log(`📍 Contract Address: ${SEPOLIA_CONTRACT_ADDRESS}`);
    console.log(`🔗 Network: Sepolia Testnet (Chain ID: 11155111)`);
    console.log(
        `🌐 Explorer: https://sepolia.etherscan.io/address/${SEPOLIA_CONTRACT_ADDRESS}`
    );
    console.log("=".repeat(60));

    const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    console.log(`\n🏛️ Deployer Address: ${wallet.address}`);
    console.log(
        `💰 Balance: ${ethers.formatEther(
            await provider.getBalance(wallet.address)
        )} ETH`
    );

    // Load ABI
    const abiPath = path.join(__dirname, "..", "abis", "SimpleDarkPool.json");
    const abi = JSON.parse(fs.readFileSync(abiPath, "utf8"));
    const darkPool = new ethers.Contract(SEPOLIA_CONTRACT_ADDRESS, abi, wallet);

    console.log("\n📋 CONTRACT FUNCTIONALITY DEMONSTRATION");
    console.log("=".repeat(60));

    try {
        // Get current nonce for transaction management
        let currentNonce = await provider.getTransactionCount(wallet.address);
        console.log(`📊 Starting nonce: ${currentNonce}`);

        // === STEP 1: OPERATOR REGISTRATION ===
        console.log("\n🔐 STEP 1: OPERATOR REGISTRATION");
        console.log("-".repeat(40));

        const isOperator = await darkPool.operators(wallet.address);
        if (!isOperator) {
            console.log("📝 Registering as operator...");
            const registerTx = await darkPool.registerOperator({
                value: ethers.parseEther("0.1"), // 0.1 ETH stake
                nonce: currentNonce,
                gasLimit: 150000,
            });

            console.log(`   ⏳ Transaction sent: ${registerTx.hash}`);
            console.log(
                `   🔍 View on Etherscan: https://sepolia.etherscan.io/tx/${registerTx.hash}`
            );

            const receipt = await registerTx.wait();
            currentNonce++;

            console.log(
                `   ✅ Registered! Block: ${receipt.blockNumber}, Gas: ${receipt.gasUsed}`
            );
        } else {
            console.log("   ✅ Already registered as operator");
        }

        // Verify operator status
        const operatorStake = await darkPool.operatorStakes(wallet.address);
        console.log(
            `   💰 Operator stake: ${ethers.formatEther(operatorStake)} ETH`
        );

        // === STEP 2: ORDER SUBMISSION ===
        console.log("\n📋 STEP 2: ORDER SUBMISSION");
        console.log("-".repeat(40));

        const baseTimestamp = Math.floor(Date.now() / 1000);
        const orders = [
            {
                name: "BUY WETH with USDC",
                order: {
                    trader: wallet.address,
                    tokenIn: DEMO_TOKENS.USDC,
                    tokenOut: DEMO_TOKENS.WETH,
                    amountIn: ethers.parseEther("2000"), // 2000 USDC
                    minAmountOut: ethers.parseEther("1"), // 1 WETH minimum
                    nonce: BigInt(baseTimestamp * 1000 + 100),
                    deadline: baseTimestamp + 3600, // 1 hour
                    isBuy: true,
                },
            },
            {
                name: "SELL WETH for USDC",
                order: {
                    trader: wallet.address,
                    tokenIn: DEMO_TOKENS.WETH,
                    tokenOut: DEMO_TOKENS.USDC,
                    amountIn: ethers.parseEther("1"), // 1 WETH
                    minAmountOut: ethers.parseEther("1900"), // 1900 USDC minimum
                    nonce: BigInt(baseTimestamp * 1000 + 200),
                    deadline: baseTimestamp + 3600,
                    isBuy: false,
                },
            },
            {
                name: "BUY DAI with USDT",
                order: {
                    trader: wallet.address,
                    tokenIn: DEMO_TOKENS.USDT,
                    tokenOut: DEMO_TOKENS.DAI,
                    amountIn: ethers.parseEther("1000"), // 1000 USDT
                    minAmountOut: ethers.parseEther("990"), // 990 DAI minimum
                    nonce: BigInt(baseTimestamp * 1000 + 300),
                    deadline: baseTimestamp + 3600,
                    isBuy: true,
                },
            },
        ];

        const orderHashes: string[] = [];

        for (let i = 0; i < orders.length; i++) {
            const { name, order } = orders[i];
            console.log(`\n📝 Submitting Order ${i + 1}: ${name}`);
            console.log(
                `   Amount In: ${ethers.formatEther(
                    order.amountIn
                )} ${getTokenSymbol(order.tokenIn)}`
            );
            console.log(
                `   Min Out: ${ethers.formatEther(
                    order.minAmountOut
                )} ${getTokenSymbol(order.tokenOut)}`
            );
            console.log(`   Type: ${order.isBuy ? "BUY" : "SELL"}`);
            console.log(
                `   Deadline: ${new Date(order.deadline * 1000).toISOString()}`
            );

            const orderTx = await darkPool.submitOrder(order, {
                nonce: currentNonce,
                gasLimit: 200000,
            });

            console.log(`   ⏳ Transaction: ${orderTx.hash}`);
            console.log(
                `   🔍 Etherscan: https://sepolia.etherscan.io/tx/${orderTx.hash}`
            );

            const receipt = await orderTx.wait();
            currentNonce++;

            // Extract order hash from events
            let orderHash = "";
            for (const log of receipt.logs) {
                try {
                    const parsed = darkPool.interface.parseLog(log);
                    if (parsed && parsed.name === "OrderSubmitted") {
                        orderHash = parsed.args[0];
                        orderHashes.push(orderHash);
                        break;
                    }
                } catch (e) {
                    // Skip unparseable logs
                }
            }

            console.log(`   ✅ Order Hash: ${orderHash}`);
            console.log(
                `   📊 Block: ${receipt.blockNumber}, Gas: ${receipt.gasUsed}`
            );
        }

        // === STEP 3: ORDER VERIFICATION ===
        console.log("\n🔍 STEP 3: ORDER VERIFICATION");
        console.log("-".repeat(40));

        for (let i = 0; i < orderHashes.length; i++) {
            const orderHash = orderHashes[i];
            console.log(
                `\n📋 Verifying Order ${i + 1}: ${orderHash.slice(0, 10)}...`
            );

            try {
                const storedOrder = await darkPool.getOrder(orderHash);
                console.log(`   ✅ Order found in contract`);
                console.log(`   👤 Trader: ${storedOrder.trader}`);
                console.log(
                    `   💱 Pair: ${getTokenSymbol(
                        storedOrder.tokenIn
                    )} → ${getTokenSymbol(storedOrder.tokenOut)}`
                );
                console.log(
                    `   💰 Amount: ${ethers.formatEther(storedOrder.amountIn)}`
                );
                console.log(
                    `   📈 Type: ${storedOrder.isBuy ? "BUY" : "SELL"}`
                );
            } catch (error) {
                console.log(`   ❌ Error fetching order: ${error}`);
            }
        }

        // === STEP 4: BATCH CREATION AND COMMITMENT ===
        console.log("\n📦 STEP 4: BATCH CREATION AND COMMITMENT");
        console.log("-".repeat(40));

        // Create a trade between the first two orders
        const trade = {
            buyOrderHash: orderHashes[0] || ethers.ZeroHash,
            sellOrderHash: orderHashes[1] || ethers.ZeroHash,
            price: ethers.parseEther("2000"), // 2000 USDC per WETH
            quantity: ethers.parseEther("1"), // 1 WETH
            timestamp: Math.floor(Date.now() / 1000),
        };

        console.log("🔨 Creating trade batch...");
        console.log(`   Buy Order: ${trade.buyOrderHash.slice(0, 10)}...`);
        console.log(`   Sell Order: ${trade.sellOrderHash.slice(0, 10)}...`);
        console.log(
            `   Price: ${ethers.formatEther(trade.price)} USDC per WETH`
        );
        console.log(`   Quantity: ${ethers.formatEther(trade.quantity)} WETH`);

        // Generate trade hash for merkle tree
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

        const merkleRoot = tradeHash; // Single trade = merkle root
        console.log(`   📋 Trade Hash: ${tradeHash}`);
        console.log(`   🌳 Merkle Root: ${merkleRoot.slice(0, 10)}...`);

        // Commit the batch
        console.log("\n📤 Committing batch to contract...");
        const commitTx = await darkPool.commitBatch(merkleRoot, 1, {
            nonce: currentNonce,
            gasLimit: 200000,
        });

        console.log(`   ⏳ Transaction: ${commitTx.hash}`);
        console.log(
            `   🔍 Etherscan: https://sepolia.etherscan.io/tx/${commitTx.hash}`
        );

        const commitReceipt = await commitTx.wait();
        currentNonce++;

        console.log(
            `   ✅ Batch committed! Block: ${commitReceipt.blockNumber}, Gas: ${commitReceipt.gasUsed}`
        );

        // === STEP 5: BATCH VERIFICATION ===
        console.log("\n✅ STEP 5: BATCH VERIFICATION");
        console.log("-".repeat(40));

        const batch = await darkPool.getBatch(merkleRoot);
        console.log(`📦 Batch Details:`);
        console.log(`   Operator: ${batch.operator}`);
        console.log(`   Trade Count: ${batch.tradeCount}`);
        console.log(`   Committed: ${batch.isCommitted}`);
        console.log(
            `   Commitment Time: ${new Date(
                Number(batch.commitmentTime) * 1000
            ).toISOString()}`
        );

        // === STEP 6: TRADE SETTLEMENT ===
        console.log("\n⚖️ STEP 6: TRADE SETTLEMENT");
        console.log("-".repeat(40));

        console.log("🔧 Settling trade with merkle proof verification...");
        const proof: string[] = []; // Empty proof for single leaf tree

        const settleTx = await darkPool.settleTrade(trade, proof, merkleRoot, {
            nonce: currentNonce,
            gasLimit: 300000,
        });

        console.log(`   ⏳ Transaction: ${settleTx.hash}`);
        console.log(
            `   🔍 Etherscan: https://sepolia.etherscan.io/tx/${settleTx.hash}`
        );

        const settleReceipt = await settleTx.wait();
        currentNonce++;

        console.log(
            `   ✅ Trade settled! Block: ${settleReceipt.blockNumber}, Gas: ${settleReceipt.gasUsed}`
        );

        // === STEP 7: SETTLEMENT VERIFICATION ===
        console.log("\n🔍 STEP 7: SETTLEMENT VERIFICATION");
        console.log("-".repeat(40));

        const isSettled = await darkPool.isTradeSettled(tradeHash);
        console.log(
            `✅ Trade Settlement Status: ${isSettled ? "SETTLED" : "PENDING"}`
        );

        // Check for settlement events
        const settleEvents = await darkPool.queryFilter(
            darkPool.filters.TradeSettled(),
            settleReceipt.blockNumber,
            settleReceipt.blockNumber
        );

        if (settleEvents.length > 0) {
            console.log(`📊 Settlement Events Found: ${settleEvents.length}`);
            for (const event of settleEvents) {
                if ("args" in event) {
                    console.log(`   🎯 Event - Trade Hash: ${event.args[0]}`);
                    console.log(
                        `   💰 Value: ${ethers.formatEther(event.args[3])} WETH`
                    );
                }
            }
        }

        // === STEP 8: CONTRACT STATE SUMMARY ===
        console.log("\n📊 STEP 8: FINAL CONTRACT STATE");
        console.log("-".repeat(40));

        const finalBalance = await provider.getBalance(wallet.address);
        const operatorFinalStake = await darkPool.operatorStakes(
            wallet.address
        );

        console.log(`🏛️ Contract Summary:`);
        console.log(`   📍 Address: ${SEPOLIA_CONTRACT_ADDRESS}`);
        console.log(`   🔗 Network: Sepolia Testnet`);
        console.log(`   👤 Operator: ${wallet.address}`);
        console.log(
            `   💰 Operator Stake: ${ethers.formatEther(
                operatorFinalStake
            )} ETH`
        );
        console.log(`   📋 Orders Submitted: ${orderHashes.length}`);
        console.log(`   📦 Batches Committed: 1`);
        console.log(`   ⚖️ Trades Settled: 1`);
        console.log(
            `   💳 Deployer Balance: ${ethers.formatEther(finalBalance)} ETH`
        );

        console.log("\n🎉 DEMO COMPLETED SUCCESSFULLY!");
        console.log("=".repeat(60));
        console.log(
            "🔍 All transactions are now visible on Sepolia Etherscan:"
        );
        console.log(
            `   📋 Contract: https://sepolia.etherscan.io/address/${SEPOLIA_CONTRACT_ADDRESS}`
        );
        console.log(
            `   📊 All transactions can be viewed in the contract's transaction history`
        );
        console.log("\n✨ What was demonstrated:");
        console.log("   ✅ Operator registration with ETH stake");
        console.log("   ✅ Order submission (3 different trading pairs)");
        console.log("   ✅ Order verification and storage");
        console.log("   ✅ Trade matching and merkle tree generation");
        console.log("   ✅ Batch commitment with cryptographic proofs");
        console.log("   ✅ Trade settlement with merkle proof verification");
        console.log("   ✅ Settlement status verification");
        console.log("   ✅ Complete audit trail on-chain");

        // === RETURN SUMMARY FOR VERIFICATION ===
        return {
            contractAddress: SEPOLIA_CONTRACT_ADDRESS,
            network: "Sepolia Testnet",
            orderHashes,
            tradeHash,
            merkleRoot,
            transactions: {
                registerOperator: isOperator
                    ? "Already registered"
                    : "New registration",
                orders: orderHashes.length,
                batchCommit: commitTx.hash,
                tradeSettle: settleTx.hash,
            },
            finalState: {
                operatorStake: ethers.formatEther(operatorFinalStake),
                tradesSettled: 1,
                isOperator: await darkPool.operators(wallet.address),
            },
        };
    } catch (error) {
        console.error("❌ Demo failed:", error);
        throw error;
    }
}

function getTokenSymbol(address: string): string {
    const symbols: { [key: string]: string } = {
        [DEMO_TOKENS.USDC]: "USDC",
        [DEMO_TOKENS.WETH]: "WETH",
        [DEMO_TOKENS.DAI]: "DAI",
        [DEMO_TOKENS.USDT]: "USDT",
    };
    return symbols[address] || "UNKNOWN";
}

if (require.main === module) {
    main()
        .then((result) => {
            console.log("\n📈 Demo Results:", JSON.stringify(result, null, 2));
            process.exit(0);
        })
        .catch((error) => {
            console.error("❌ Demo failed:", error);
            process.exit(1);
        });
}

export { main as sepoliaDemoMain };
