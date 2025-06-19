const fs = require("fs");
const path = require("path");

// Directories
const contractsDir = path.join(__dirname, "..", "contracts");
const artifactsDir = path.join(contractsDir, "out");
const abiDir = path.join(__dirname, "..", "abis");

// Ensure the abis directory exists
if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir);
}

function checkArtifactsDirectory() {
    if (!fs.existsSync(artifactsDir)) {
        console.error(
            `The artifacts directory '${artifactsDir}' does not exist.`
        );
        console.log('Please compile your contracts first using "forge build"');
        process.exit(1);
    }

    const files = fs.readdirSync(artifactsDir);
    if (files.length === 0) {
        console.error(`The artifacts directory '${artifactsDir}' is empty.`);
        console.log(
            'Please compile your contracts first using "forge build" or confirm the path is correct.'
        );
        process.exit(1);
    }
}

function extractAbi(contractName) {
    try {
        const outputPath = path.join(
            artifactsDir,
            `${contractName}.sol`,
            `${contractName}.json`
        );
        const abiOutputPath = path.join(abiDir, `${contractName}.json`);

        if (!fs.existsSync(outputPath)) {
            console.log(`Contract artifact not found: ${outputPath}`);
            return;
        }

        const contractData = JSON.parse(fs.readFileSync(outputPath, "utf8"));
        const abi = JSON.stringify(contractData.abi, null, 2);
        fs.writeFileSync(abiOutputPath, abi);
        console.log(`✅ Extracted ABI for ${contractName}`);
    } catch (error) {
        console.error(
            `❌ Error extracting ABI for ${contractName}:`,
            error.message
        );
    }
}

// Check artifacts directory
checkArtifactsDirectory();

// List of contracts to extract ABIs for
const contracts = [
    "SimpleDarkPool",
    // Removed non-existent contracts:
    // "DarkPoolServiceManager",
    // "DarkPoolTaskManager",
    // "IDelegationManager",
    // "IAVSDirectory",
    // "IECDSAStakeRegistry",
];

console.log("🔧 Extracting ABIs...");

// Extract ABIs for each contract
contracts.forEach((contractName) => {
    extractAbi(contractName);
});

console.log(
    '✅ ABI extraction complete. Check the "abis" directory for the output.'
);
