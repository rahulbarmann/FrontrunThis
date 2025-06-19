.PHONY: help install build test clean deploy

# Default target
help:
	@echo "🌊 DarkPool v4 Development Commands"
	@echo ""
	@echo "Setup Commands:"
	@echo "  install          Install all dependencies"
	@echo "  setup            Complete project setup"
	@echo ""
	@echo "Build Commands:"
	@echo "  build            Build all components"
	@echo "  build-contracts  Build Solidity contracts"
	@echo "  build-ts         Build TypeScript code"
	@echo ""
	@echo "Test Commands:"
	@echo "  test             Run all tests"
	@echo "  test-contracts   Run Solidity contract tests"
	@echo "  test-ts          Run TypeScript tests"
	@echo "  test-e2e         Run end-to-end tests"
	@echo "  test-coverage    Run tests with coverage"
	@echo ""
	@echo "Development Commands:"
	@echo "  start-anvil      Start local anvil chain"
	@echo "  deploy-local     Deploy contracts to local anvil"
	@echo "  start-operator   Start TypeScript operator"
	@echo "  start-traffic    Start task creation"
	@echo ""
	@echo "Demo Commands:"
	@echo "  demo-orders      Run order submission demo"
	@echo "  demo-settle      Run settlement demo"
	@echo "  demo-full        Run full demo workflow"
	@echo ""
	@echo "Utility Commands:"
	@echo "  extract-abis     Extract contract ABIs"
	@echo "  clean            Clean build artifacts"
	@echo "  lint             Run linter"

# Setup commands
install:
	@echo "📦 Installing dependencies..."
	npm install
	cd contracts && forge install

setup: install
	@echo "⚙️ Setting up environment..."
	cp .env.example .env
	@echo "✅ Setup complete! Edit .env file if needed."

# Build commands
build: build-contracts build-ts

build-contracts:
	@echo "🔨 Building contracts..."
	cd contracts && forge build

build-ts:
	@echo "🔧 Building TypeScript..."
	npm run build

# Test commands
test: test-contracts test-ts

test-contracts:
	@echo "🧪 Running contract tests..."
	cd contracts && forge test

test-ts:
	@echo "🧪 Running TypeScript tests..."
	npm run test

test-e2e:
	@echo "🧪 Running E2E tests..."
	npm run test:e2e

test-coverage:
	@echo "📊 Running tests with coverage..."
	cd contracts && forge coverage
	npm run test -- --coverage

# Development commands
start-anvil:
	@echo "⛓️ Starting local anvil chain..."
	anvil

deploy-local: build-contracts
	@echo "🚀 Deploying to local anvil..."
	npm run deploy:darkpool
	npm run extract:abis

start-operator:
	@echo "🤖 Starting TypeScript operator..."
	npm run start:operator

start-traffic:
	@echo "📋 Starting task creation..."
	npm run start:traffic

# Demo commands
demo-orders:
	@echo "🎯 Running order submission demo..."
	npm run demo:orders

demo-settle:
	@echo "⚡ Running settlement demo..."
	npm run demo:settle

demo-full: start-anvil-bg deploy-local demo-orders demo-settle
	@echo "🎪 Full demo complete!"

# Background anvil (for CI/automation)
start-anvil-bg:
	@echo "⛓️ Starting anvil in background..."
	anvil > /dev/null 2>&1 &
	sleep 2

# Utility commands
extract-abis:
	@echo "📄 Extracting contract ABIs..."
	npm run extract:abis

clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf node_modules dist coverage
	rm -rf contracts/out contracts/cache
	rm -rf abis/*.json

lint:
	@echo "🔍 Running linter..."
	npm run build && echo "TypeScript compilation successful"

# Quick development workflow
dev-start: start-anvil-bg deploy-local start-operator-bg start-traffic-bg
	@echo "🚀 Development environment started!"
	@echo "   - Anvil running on http://localhost:8545"
	@echo "   - Operator running in background"
	@echo "   - Task creation running in background"
	@echo "   - Press Ctrl+C to stop all processes"

start-operator-bg:
	npm run start:operator > operator.log 2>&1 &

start-traffic-bg:
	npm run start:traffic > traffic.log 2>&1 &

# Stop all background processes
stop-all:
	@echo "🛑 Stopping all processes..."
	pkill -f anvil || true
	pkill -f "ts-node operator" || true
	pkill -f "ts-node.*createTasks" || true

# Gas analysis
gas-report:
	@echo "⛽ Generating gas report..."
	cd contracts && forge test --gas-report

# Deploy to testnet (requires proper .env setup)
deploy-testnet:
	@echo "🌐 Deploying to testnet..."
	cd contracts && forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify

# Verify contracts on Etherscan
verify-contracts:
	@echo "✅ Verifying contracts..."
	cd contracts && forge verify-contract --chain-id 11155111 --num-of-optimizations 200 src/SimpleDarkPool.sol:SimpleDarkPool $(CONTRACT_ADDRESS)

# Format code
format:
	@echo "💅 Formatting code..."
	cd contracts && forge fmt
	npm run build

# Full test suite for CI
ci-test: build test test-e2e gas-report
	@echo "✅ All CI tests passed!"

# Development shortcuts
quick-test: build-contracts test-contracts
	@echo "⚡ Quick test cycle complete!"

restart-dev: stop-all dev-start
	@echo "🔄 Development environment restarted!" 