// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IDarkPoolTaskManager.sol";
import "./interfaces/IDarkPoolServiceManager.sol";

/**
 * @title DarkPoolTaskManager
 * @dev Manages tasks for batch validation in the dark pool system
 */
contract DarkPoolTaskManager is IDarkPoolTaskManager {
    IDarkPoolServiceManager public immutable serviceManager;

    // Task tracking
    mapping(uint32 => Task) public tasks;
    mapping(uint32 => mapping(address => bool)) public hasResponded;
    mapping(uint32 => bytes32) public taskResponses;
    uint32 public latestTaskNum;

    // Constants
    uint32 public constant MIN_QUORUM_THRESHOLD = 50; // 50%
    uint256 public constant TASK_RESPONSE_WINDOW = 1 hours;

    modifier onlyValidOperator() {
        require(
            serviceManager.isValidOperator(msg.sender),
            "Not a valid operator"
        );
        _;
    }

    constructor(address _serviceManager) {
        serviceManager = IDarkPoolServiceManager(_serviceManager);
    }

    /**
     * @dev Create a new task for batch validation
     */
    function createNewTask(
        bytes32 batchHash,
        uint32 quorumThreshold,
        bytes calldata quorumNumbers
    ) external override onlyValidOperator {
        require(quorumThreshold >= MIN_QUORUM_THRESHOLD, "Quorum too low");
        require(batchHash != bytes32(0), "Invalid batch hash");

        uint32 taskIndex = latestTaskNum;

        tasks[taskIndex] = Task({
            batchHash: batchHash,
            quorumThreshold: quorumThreshold,
            quorumNumbers: quorumNumbers,
            createdBlock: block.number,
            creator: msg.sender,
            isCompleted: false
        });

        latestTaskNum++;

        emit TaskCreated(taskIndex, batchHash, msg.sender);
    }

    /**
     * @dev Respond to a task with signature
     */
    function respondToTask(
        bytes32 batchHash,
        bytes32 response,
        bytes calldata signature
    ) external override onlyValidOperator {
        // Find the task with matching batch hash
        uint32 taskIndex = _findTaskByBatchHash(batchHash);
        require(taskIndex < latestTaskNum, "Task not found");

        Task storage task = tasks[taskIndex];
        require(!task.isCompleted, "Task already completed");
        require(!hasResponded[taskIndex][msg.sender], "Already responded");
        require(
            block.number <= task.createdBlock + (TASK_RESPONSE_WINDOW / 12), // ~12s per block
            "Response window expired"
        );

        // Validate signature (simplified for now)
        require(signature.length > 0, "Invalid signature");

        hasResponded[taskIndex][msg.sender] = true;
        taskResponses[taskIndex] = response;

        emit TaskResponded(taskIndex, msg.sender, response);

        // Check if we have enough responses to complete task
        if (_checkQuorumReached(taskIndex)) {
            task.isCompleted = true;
            emit TaskCompleted(taskIndex, response);
        }
    }

    /**
     * @dev Get task details by index
     */
    function getTask(
        uint32 taskIndex
    ) external view override returns (Task memory) {
        require(taskIndex < latestTaskNum, "Task does not exist");
        return tasks[taskIndex];
    }

    /**
     * @dev Check if a task has received enough responses
     */
    function isTaskCompleted(uint32 taskIndex) external view returns (bool) {
        require(taskIndex < latestTaskNum, "Task does not exist");
        return tasks[taskIndex].isCompleted;
    }

    /**
     * @dev Get the response for a completed task
     */
    function getTaskResponse(uint32 taskIndex) external view returns (bytes32) {
        require(taskIndex < latestTaskNum, "Task does not exist");
        require(tasks[taskIndex].isCompleted, "Task not completed");
        return taskResponses[taskIndex];
    }

    /**
     * @dev Internal function to find task by batch hash
     */
    function _findTaskByBatchHash(
        bytes32 batchHash
    ) internal view returns (uint32) {
        for (uint32 i = 0; i < latestTaskNum; i++) {
            if (tasks[i].batchHash == batchHash && !tasks[i].isCompleted) {
                return i;
            }
        }
        revert("Task not found");
    }

    /**
     * @dev Internal function to check if quorum is reached (simplified)
     */
    function _checkQuorumReached(
        uint32 taskIndex
    ) internal view returns (bool) {
        // Simplified: just check if we have at least one response for now
        // In a real implementation, this would check against the actual quorum
        return true;
    }
}
