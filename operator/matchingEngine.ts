import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

interface Order {
    trader: string;
    tokenIn: string;
    tokenOut: string;
    amountIn: bigint;
    minAmountOut: bigint;
    nonce: bigint;
    deadline: number;
    isBuy: boolean;
}

interface Trade {
    buyOrderHash: string;
    sellOrderHash: string;
    price: bigint;
    quantity: bigint;
    timestamp: number;
}

class SimpleMatchingEngine {
    private orders: Map<string, Order> = new Map();
    private darkPool: ethers.Contract;
    private wallet: ethers.Wallet;

    constructor(darkPool: ethers.Contract, wallet: ethers.Wallet) {
        this.darkPool = darkPool;
        this.wallet = wallet;
    }

    addOrder(orderHash: string, order: Order) {
        this.orders.set(orderHash, order);
        console.log(`📝 Added order: ${orderHash.slice(0, 10)}...`);

        // Try to match immediately
        this.tryMatch();
    }

    private tryMatch() {
        const buyOrders = Array.from(this.orders.entries()).filter(
            ([_, order]) => order.isBuy
        );
        const sellOrders = Array.from(this.orders.entries()).filter(
            ([_, order]) => !order.isBuy
        );

        for (const [buyHash, buyOrder] of buyOrders) {
            for (const [sellHash, sellOrder] of sellOrders) {
                if (this.canMatch(buyOrder, sellOrder)) {
                    console.log(
                        `🔄 Matching orders: ${buyHash.slice(
                            0,
                            8
                        )}... ↔ ${sellHash.slice(0, 8)}...`
                    );

                    const trade: Trade = {
                        buyOrderHash: buyHash,
                        sellOrderHash: sellHash,
                        price: this.calculatePrice(buyOrder, sellOrder),
                        quantity: this.calculateQuantity(buyOrder, sellOrder),
                        timestamp: Math.floor(Date.now() / 1000),
                    };

                    this.createBatch([trade]);

                    // Remove matched orders
                    this.orders.delete(buyHash);
                    this.orders.delete(sellHash);

                    return; // Match one pair at a time for simplicity
                }
            }
        }
    }

    private canMatch(buyOrder: Order, sellOrder: Order): boolean {
        // Check if tokens are compatible (buy WETH with USDC, sell WETH for USDC)
        return (
            buyOrder.tokenIn === sellOrder.tokenOut &&
            buyOrder.tokenOut === sellOrder.tokenIn &&
            buyOrder.deadline > Math.floor(Date.now() / 1000) &&
            sellOrder.deadline > Math.floor(Date.now() / 1000)
        );
    }

    private calculatePrice(buyOrder: Order, sellOrder: Order): bigint {
        // Simple price calculation - could be more sophisticated
        const buyPrice =
            (buyOrder.amountIn * ethers.parseEther("1")) /
            buyOrder.minAmountOut;
        const sellPrice =
            (sellOrder.minAmountOut * ethers.parseEther("1")) /
            sellOrder.amountIn;

        // Use the midpoint
        return (buyPrice + sellPrice) / 2n;
    }

    private calculateQuantity(buyOrder: Order, sellOrder: Order): bigint {
        // Use minimum of what's available
        return buyOrder.minAmountOut < sellOrder.amountIn
            ? buyOrder.minAmountOut
            : sellOrder.amountIn;
    }

    private async createBatch(trades: Trade[]) {
        try {
            console.log(`📦 Creating batch with ${trades.length} trade(s)...`);

            // Create merkle root from trades
            const tradeHashes = trades.map((trade) =>
                ethers.keccak256(
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
                )
            );

            const merkleRoot = tradeHashes[0]; // Simplified for single trade

            const tx = await this.darkPool.commitBatch(
                merkleRoot,
                trades.length
            );
            await tx.wait();

            console.log(`✅ Batch committed: ${merkleRoot.slice(0, 10)}...`);

            // Settle the trade
            if (trades.length > 0) {
                const proof: string[] = []; // Empty proof for single leaf
                const settleTx = await this.darkPool.settleTrade(
                    trades[0],
                    proof,
                    merkleRoot
                );
                await settleTx.wait();
                console.log(
                    `⚖️ Trade settled: ${tradeHashes[0].slice(0, 10)}...`
                );
            }
        } catch (error) {
            console.error("❌ Batch creation failed:", error);
        }
    }
}

async function main() {
    console.log("🧮 Simple Matching Engine Starting...");

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
    console.log("🤖 Engine address:", wallet.address);

    const engine = new SimpleMatchingEngine(darkPool, wallet);

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

        // Listen for order submissions and add them to matching engine
        darkPool.on(
            "OrderSubmitted",
            async (orderHash: string, trader: string) => {
                try {
                    const order = await darkPool.getOrder(orderHash);
                    engine.addOrder(orderHash, {
                        trader: order.trader,
                        tokenIn: order.tokenIn,
                        tokenOut: order.tokenOut,
                        amountIn: order.amountIn,
                        minAmountOut: order.minAmountOut,
                        nonce: order.nonce,
                        deadline: Number(order.deadline),
                        isBuy: order.isBuy,
                    });
                } catch (error) {
                    console.error("❌ Failed to fetch order:", error);
                }
            }
        );

        console.log("✅ Matching engine running. Press Ctrl+C to stop.");

        // Keep alive
        setInterval(() => {
            console.log(`📊 Orders in pool: ${engine["orders"].size}`);
        }, 30000);
    } catch (error) {
        console.error("❌ Matching engine failed:", error);
        process.exit(1);
    }
}

// Handle graceful shutdown
process.on("SIGINT", () => {
    console.log("\n👋 Shutting down matching engine...");
    process.exit(0);
});

main().catch(console.error);
