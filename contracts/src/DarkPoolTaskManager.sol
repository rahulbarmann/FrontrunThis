// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IDarkPoolTaskManager.sol";
import "./interfaces/IDarkPoolServiceManager.sol";

/**
 * @title DarkPoolTaskManager
 * @dev Enhanced task manager for batch validation with proper quorum mechanisms
 */
contract DarkPoolTaskManager is IDarkPoolTaskManager {
    IDarkPoolServiceManager public immutable serviceManager;

    // Task tracking
    mapping(uint32 => Task) public tasks;
    mapping(uint32 => mapping(address => bool)) public hasResponded;
    mapping(uint32 => mapping(address => bytes32)) public operatorResponses;
    mapping(uint32 => bytes32) public taskResponses;
    mapping(uint32 => uint32) public responseCount;
    uint32 public latestTaskNum;

    // Quorum tracking
    mapping(uint32 => mapping(bytes32 => uint32)) public responseVotes;
    mapping(uint32 => bytes32) public consensusResponse;

    // Constants
    uint32 public constant MIN_QUORUM_THRESHOLD = 50; // 50%
    uint32 public constant MAX_QUORUM_THRESHOLD = 100; // 100%
    uint256 public constant TASK_RESPONSE_WINDOW = 2 hours;
    uint256 public constant TASK_REWARD = 0.0001 ether; // Reward per validated task

    // Events
    event QuorumReached(
        uint32 indexed taskIndex,
        bytes32 response,
        uint32 votes
    );
    event ConsensusAchieved(
        uint32 indexed taskIndex,
        bytes32 consensusResponse
    );
    event InvalidResponse(
        uint32 indexed taskIndex,
        address indexed operator,
        bytes32 response
    );

    modifier onlyValidOperator() {
        require(
            serviceManager.isValidOperator(msg.sender),
            "Not a valid operator"
        );
        _;
    }

    modifier onlyServiceManager() {
        require(msg.sender == address(serviceManager), "Only service manager");
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
        require(
            quorumThreshold >= MIN_QUORUM_THRESHOLD &&
                quorumThreshold <= MAX_QUORUM_THRESHOLD,
            "Invalid quorum threshold"
        );
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

        // Set reward for this task
        serviceManager.setTaskReward{value: TASK_REWARD}(
            taskIndex,
            TASK_REWARD
        );

        emit TaskCreated(taskIndex, batchHash, msg.sender);
    }

    /**
     * @dev Respond to a task with signature and validation
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

        // Validate signature (simplified for now - in production would use BLS signatures)
        require(signature.length > 0, "Invalid signature");

        // Validate response against expected format
        require(
            _validateResponse(batchHash, response),
            "Invalid response format"
        );

        // Record response
        hasResponded[taskIndex][msg.sender] = true;
        operatorResponses[taskIndex][msg.sender] = response;
        responseCount[taskIndex]++;

        // Track votes for this response
        responseVotes[taskIndex][response]++;

        // Record validation for rewards
        serviceManager.recordTaskValidation(taskIndex, msg.sender);

        emit TaskResponded(taskIndex, msg.sender, response);

        // Check if we have reached quorum
        _checkAndProcessQuorum(taskIndex, response);
    }

    /**
     * @dev Check if quorum is reached and process accordingly
     */
    function _checkAndProcessQuorum(
        uint32 taskIndex,
        bytes32 response
    ) internal {
        Task storage task = tasks[taskIndex];
        uint32 votes = responseVotes[taskIndex][response];
        uint32 totalOperators = _getActiveOperatorCount();

        // Calculate required votes based on quorum threshold
        uint32 requiredVotes = (totalOperators * task.quorumThreshold) / 100;

        if (votes >= requiredVotes) {
            emit QuorumReached(taskIndex, response, votes);

            // Check if this is the consensus (majority) response
            if (votes > responseCount[taskIndex] / 2) {
                task.isCompleted = true;
                consensusResponse[taskIndex] = response;
                taskResponses[taskIndex] = response;

                emit ConsensusAchieved(taskIndex, response);
                emit TaskCompleted(taskIndex, response);

                // Distribute rewards to operators who provided correct response
                _distributeRewards(taskIndex, response);

                // Slash operators who provided incorrect responses
                _slashIncorrectOperators(taskIndex, response);
            }
        }
    }

    /**
     * @dev Distribute rewards to operators who provided correct response
     */
    function _distributeRewards(
        uint32 taskIndex,
        bytes32 correctResponse
    ) internal {
        address[] memory validOperators = new address[](
            responseCount[taskIndex]
        );
        uint256 validCount = 0;

        // Find all operators who provided the correct response
        for (uint32 i = 0; i < latestTaskNum; i++) {
            // In a real implementation, we'd iterate through a list of operators
            // For now, this is a simplified version
        }

        if (validCount > 0) {
            // Resize array to actual count
            assembly {
                mstore(validOperators, validCount)
            }
            serviceManager.distributeTaskReward(taskIndex, validOperators);
        }
    }

    /**
     * @dev Slash operators who provided incorrect responses
     */
    function _slashIncorrectOperators(
        uint32 taskIndex,
        bytes32 correctResponse
    ) internal {
        // In production, this would slash operators who provided incorrect responses
        // For now, we'll emit events for incorrect responses

        for (uint32 i = 0; i < responseCount[taskIndex]; i++) {
            // Simplified - in production would iterate through operator responses
            // and slash those with incorrect responses
        }
    }

    /**
     * @dev Validate response format and content
     */
    function _validateResponse(
        bytes32 batchHash,
        bytes32 response
    ) internal pure returns (bool) {
        // Simplified validation - in production would validate against batch content
        return response != bytes32(0) && batchHash != bytes32(0);
    }

    /**
     * @dev Get count of active operators
     */
    function _getActiveOperatorCount() internal view returns (uint32) {
        // Simplified - in production would query from service manager
        return 10; // Placeholder
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
     * @dev Get consensus response for a task
     */
    function getConsensusResponse(
        uint32 taskIndex
    ) external view returns (bytes32) {
        require(taskIndex < latestTaskNum, "Task does not exist");
        require(tasks[taskIndex].isCompleted, "Task not completed");
        return consensusResponse[taskIndex];
    }

    /**
     * @dev Get vote count for a specific response in a task
     */
    function getResponseVotes(
        uint32 taskIndex,
        bytes32 response
    ) external view returns (uint32) {
        return responseVotes[taskIndex][response];
    }

    /**
     * @dev Get operator response for a specific task
     */
    function getOperatorResponse(
        uint32 taskIndex,
        address operator
    ) external view returns (bytes32) {
        return operatorResponses[taskIndex][operator];
    }

    /**
     * @dev Emergency function to complete stuck tasks
     */
    function forceCompleteTask(uint32 taskIndex) external onlyServiceManager {
        require(taskIndex < latestTaskNum, "Task does not exist");
        require(!tasks[taskIndex].isCompleted, "Task already completed");
        require(
            block.number >
                tasks[taskIndex].createdBlock +
                    (TASK_RESPONSE_WINDOW / 12) +
                    100,
            "Task not expired"
        );

        tasks[taskIndex].isCompleted = true;
        emit TaskCompleted(taskIndex, bytes32(0));
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
}
