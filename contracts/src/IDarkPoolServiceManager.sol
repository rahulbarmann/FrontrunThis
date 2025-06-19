// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IDarkPoolServiceManager {
    /* STRUCTS */

    /// @notice A task for operators to match orders
    struct Task {
        bytes32[] orderHashes; // Array of order hashes to match
        uint32 taskCreatedBlock; // Block number when task was created
    }

    /// @notice Response from an operator for a task
    struct TaskResponse {
        uint32 referenceTaskIndex; // Index of the task being responded to
        TradeMatch[] matches; // Array of matched trades
        bytes32 merkleRoot; // Merkle root of the matches
    }

    /// @notice A matched trade between two orders
    struct TradeMatch {
        bytes32 buyOrderHash; // Hash of the buy order
        bytes32 sellOrderHash; // Hash of the sell order
        uint256 matchedAmount; // Amount that was matched
        uint256 matchedPrice; // Price at which the trade was matched
    }

    /* EVENTS */

    event NewTaskCreated(uint32 indexed taskIndex, Task task);
    event TaskResponded(uint32 indexed taskIndex, Task task, address operator);
    event OperatorSlashed(address indexed operator, uint32 indexed taskIndex);

    /* FUNCTIONS */

    /// @notice Creates a new dark pool matching task
    function createNewTask(
        bytes32[] calldata orderHashes
    ) external returns (Task memory task);

    /// @notice Allows operators to respond to a task
    function respondToTask(
        Task calldata task,
        TaskResponse calldata taskResponse,
        uint32 referenceTaskIndex,
        bytes calldata signature
    ) external;

    /// @notice Slash an operator for not responding to a task
    function slashOperator(
        address operator,
        Task calldata task,
        uint32 referenceTaskIndex
    ) external;

    /// @notice Get the latest task number
    function latestTaskNum() external view returns (uint32);

    /// @notice Get the task hash for a given task index
    function getTaskHash(uint32 taskIndex) external view returns (bytes32);

    /// @notice Get the task response for a given task index
    function getTaskResponse(
        uint32 taskIndex
    ) external view returns (bytes memory);

    /// @notice Check if a task has been completed
    function isTaskCompleted(uint32 taskIndex) external view returns (bool);
}
