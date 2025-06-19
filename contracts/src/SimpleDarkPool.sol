// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SimpleDarkPool
/// @notice A simplified dark pool implementation for testing and demonstration
/// @dev This is a self-contained version without external dependencies
contract SimpleDarkPool {
    struct Order {
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 nonce;
        uint256 deadline;
        bool isBuy;
    }

    struct Trade {
        bytes32 buyOrderHash;
        bytes32 sellOrderHash;
        uint256 price;
        uint256 quantity;
        uint256 timestamp;
    }

    struct Batch {
        bytes32 merkleRoot;
        uint256 tradeCount;
        uint256 timestamp;
        address operator;
        bool isCommitted;
        bool isSettled;
    }

    // Events
    event OrderSubmitted(bytes32 indexed orderHash, address indexed trader);
    event BatchCommitted(
        bytes32 indexed merkleRoot,
        address indexed operator,
        uint256 tradeCount
    );
    event TradeSettled(
        bytes32 indexed tradeHash,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 quantity
    );

    // State variables
    mapping(bytes32 => Order) public orders;
    mapping(bytes32 => bool) public orderExists;
    mapping(bytes32 => Batch) public batches;
    mapping(bytes32 => bool) public settledTrades;
    mapping(address => bool) public operators;
    mapping(address => uint256) public operatorStake;

    address public owner;
    uint256 public constant MIN_OPERATOR_STAKE = 1 ether;
    uint256 public constant BATCH_TIMEOUT = 1 hours;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "Only operator");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Register as an operator
    function registerOperator() external payable {
        require(msg.value >= MIN_OPERATOR_STAKE, "Insufficient stake");
        operators[msg.sender] = true;
        operatorStake[msg.sender] = msg.value;
    }

    /// @notice Submit an order to the dark pool
    function submitOrder(Order calldata order) external returns (bytes32) {
        require(order.trader == msg.sender, "Invalid trader");
        require(order.deadline > block.timestamp, "Order expired");

        bytes32 orderHash = keccak256(abi.encode(order));
        require(!orderExists[orderHash], "Order already exists");

        orders[orderHash] = order;
        orderExists[orderHash] = true;

        emit OrderSubmitted(orderHash, msg.sender);
        return orderHash;
    }

    /// @notice Commit a batch of matched trades (off-chain matching)
    function commitBatch(
        bytes32 merkleRoot,
        uint256 tradeCount
    ) external onlyOperator {
        require(merkleRoot != bytes32(0), "Invalid merkle root");
        require(tradeCount > 0, "No trades");

        batches[merkleRoot] = Batch({
            merkleRoot: merkleRoot,
            tradeCount: tradeCount,
            timestamp: block.timestamp,
            operator: msg.sender,
            isCommitted: true,
            isSettled: false
        });

        emit BatchCommitted(merkleRoot, msg.sender, tradeCount);
    }

    /// @notice Settle a trade with merkle proof
    function settleTrade(
        Trade calldata trade,
        bytes32[] memory proof,
        bytes32 batchRoot
    ) external {
        Batch storage batch = batches[batchRoot];
        require(batch.isCommitted, "Batch not committed");
        require(!batch.isSettled, "Already settled");
        require(
            block.timestamp < batch.timestamp + BATCH_TIMEOUT,
            "Batch expired"
        );

        bytes32 tradeHash = keccak256(abi.encode(trade));
        require(!settledTrades[tradeHash], "Trade already settled");

        // Verify merkle proof (simplified)
        require(
            _verifyMerkleProof(proof, batchRoot, tradeHash),
            "Invalid proof"
        );

        // Mark as settled
        settledTrades[tradeHash] = true;

        // Get orders
        Order storage buyOrder = orders[trade.buyOrderHash];
        Order storage sellOrder = orders[trade.sellOrderHash];

        require(orderExists[trade.buyOrderHash], "Buy order not found");
        require(orderExists[trade.sellOrderHash], "Sell order not found");

        emit TradeSettled(
            tradeHash,
            buyOrder.trader,
            sellOrder.trader,
            trade.price,
            trade.quantity
        );
    }

    /// @notice Simple merkle proof verification
    function _verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        return computedHash == root;
    }

    /// @notice Get order by hash
    function getOrder(bytes32 orderHash) external view returns (Order memory) {
        require(orderExists[orderHash], "Order not found");
        return orders[orderHash];
    }

    /// @notice Get batch by merkle root
    function getBatch(bytes32 merkleRoot) external view returns (Batch memory) {
        return batches[merkleRoot];
    }

    /// @notice Check if trade is settled
    function isTradeSettled(bytes32 tradeHash) external view returns (bool) {
        return settledTrades[tradeHash];
    }

    /// @notice Check if address is an operator
    function isOperator(address addr) external view returns (bool) {
        return operators[addr];
    }
}
