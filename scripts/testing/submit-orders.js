#!/usr/bin/env node

const { ethers } = require("ethers");
const axios = require("axios");
const chalk = require("chalk");

// Configuration
const AVS_URL = process.env.AVS_HOST || "http://localhost:8080";

// Test token addresses (use appropriate addresses for your testnet)
const TOKEN_A = "0xA0b86a33E6441e8e8E4C5C2e8bE2B4C88a2E2e8a";
const TOKEN_B = "0xB0b86a33E6441e8e8E4C5C2e8bE2B4C88a2E2e8b";

async function main() {
    console.log(chalk.blue("🚀 Submitting test orders to DarkPool AVS"));
    console.log(chalk.gray(`AVS URL: ${AVS_URL}`));

    try {
        // Create test orders
        const orders = [
            {
                user_address: "0x1111111111111111111111111111111111111111",
                token_a: TOKEN_A,
                token_b: TOKEN_B,
                amount_a: ethers.parseEther("100").toString(),
                amount_b: ethers.parseEther("200").toString(),
                side: "Buy",
                expiry: new Date(Date.now() + 3600000).toISOString(), // 1 hour from now
                signature: "0x" + "0".repeat(130), // Mock signature
                nonce: "1",
            },
            {
                user_address: "0x2222222222222222222222222222222222222222",
                token_a: TOKEN_A,
                token_b: TOKEN_B,
                amount_a: ethers.parseEther("50").toString(),
                amount_b: ethers.parseEther("100").toString(),
                side: "Sell",
                expiry: new Date(Date.now() + 3600000).toISOString(),
                signature: "0x" + "0".repeat(130), // Mock signature
                nonce: "2",
            },
            {
                user_address: "0x3333333333333333333333333333333333333333",
                token_a: TOKEN_A,
                token_b: TOKEN_B,
                amount_a: ethers.parseEther("75").toString(),
                amount_b: ethers.parseEther("150").toString(),
                side: "Buy",
                expiry: new Date(Date.now() + 3600000).toISOString(),
                signature: "0x" + "0".repeat(130), // Mock signature
                nonce: "3",
            },
        ];

        console.log(
            chalk.yellow(`\n📝 Submitting ${orders.length} test orders...`)
        );

        for (let i = 0; i < orders.length; i++) {
            const order = orders[i];
            console.log(
                `\n${chalk.cyan(`Order ${i + 1}:`)} ${
                    order.side
                } ${ethers.formatEther(
                    order.amount_a
                )} TokenA for ${ethers.formatEther(order.amount_b)} TokenB`
            );

            try {
                const response = await axios.post(`${AVS_URL}/orders`, order, {
                    headers: {
                        "Content-Type": "application/json",
                    },
                });

                if (response.data.status === "success") {
                    console.log(
                        chalk.green(
                            `  ✅ Order submitted successfully: ${response.data.order_id}`
                        )
                    );
                } else {
                    console.log(
                        chalk.red(`  ❌ Order failed: ${response.data.message}`)
                    );
                }
            } catch (error) {
                console.log(
                    chalk.red(`  ❌ Error submitting order: ${error.message}`)
                );
            }

            // Small delay between orders
            await new Promise((resolve) => setTimeout(resolve, 500));
        }

        // Check order book
        console.log(chalk.yellow("\n📊 Checking order book..."));
        try {
            const orderbookResponse = await axios.get(
                `${AVS_URL}/orderbook/${TOKEN_A}/${TOKEN_B}`
            );
            console.log(chalk.blue("Order Book:"));
            console.log("Bids:", orderbookResponse.data.bids);
            console.log("Asks:", orderbookResponse.data.asks);
            console.log("Spread:", orderbookResponse.data.spread);
        } catch (error) {
            console.log(
                chalk.red(`Error fetching order book: ${error.message}`)
            );
        }

        // Try to create a batch
        console.log(chalk.yellow("\n📦 Creating batch..."));
        try {
            const batchResponse = await axios.post(`${AVS_URL}/batches`);
            if (batchResponse.data.batch_id) {
                console.log(
                    chalk.green(
                        `✅ Batch created: ${batchResponse.data.batch_id}`
                    )
                );
                console.log(
                    `   Trade count: ${batchResponse.data.trade_count}`
                );
                console.log(
                    `   Merkle root: ${batchResponse.data.merkle_root}`
                );
            } else {
                console.log(chalk.yellow(`ℹ️  ${batchResponse.data.message}`));
            }
        } catch (error) {
            console.log(chalk.red(`Error creating batch: ${error.message}`));
        }

        console.log(chalk.green("\n✅ Order submission demo completed!"));
    } catch (error) {
        console.error(
            chalk.red("❌ Error in order submission demo:"),
            error.message
        );
        process.exit(1);
    }
}

// Check if AVS is running
async function checkAVSHealth() {
    try {
        const response = await axios.get(`${AVS_URL}/health`, {
            timeout: 5000,
        });
        console.log(chalk.green("✅ AVS is running"));
        return true;
    } catch (error) {
        console.log(
            chalk.red(
                "❌ AVS is not running. Please start it first with: npm run avs:start"
            )
        );
        console.log(chalk.gray("   Or check if the URL is correct:", AVS_URL));
        return false;
    }
}

// Run the demo
checkAVSHealth().then((isHealthy) => {
    if (isHealthy) {
        main().catch(console.error);
    } else {
        process.exit(1);
    }
});
