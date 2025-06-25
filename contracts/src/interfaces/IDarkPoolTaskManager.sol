// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IDarkPoolTaskManager
 * @dev Interface for the DarkPool task manager
 */
interface IDarkPoolTaskManager {
    // Task structure
    struct Task {
        bytes32 batchHash;
        uint32 quorumThreshold;
        bytes quorumNumbers;
        uint256 createdBlock;
        address creator;
        bool isCompleted;
    }

    // Events
    event TaskCreated(
        uint32 indexed taskIndex,
        bytes32 indexed batchHash,
        address indexed creator
    );
    event TaskResponded(
        uint32 indexed taskIndex,
        address indexed operator,
        bytes32 response
    );
    event TaskCompleted(uint32 indexed taskIndex, bytes32 response);

    /**
     * @dev Create a new task for batch validation
     */
    function createNewTask(
        bytes32 batchHash,
        uint32 quorumThreshold,
        bytes calldata quorumNumbers
    ) external;

    /**
     * @dev Respond to a task with signature
     */
    function respondToTask(
        bytes32 batchHash,
        bytes32 response,
        bytes calldata signature
    ) external;

    /**
     * @dev Get the latest task number
     */
    function latestTaskNum() external view returns (uint32);

    /**
     * @dev Get task details by index
     */
    function getTask(uint32 taskIndex) external view returns (Task memory);
}
