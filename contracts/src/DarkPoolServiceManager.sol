// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IDarkPoolServiceManager.sol";

/**
 * @title DarkPoolServiceManager
 * @dev Enhanced service manager for the DarkPool AVS with full EigenLayer integration
 */
contract DarkPoolServiceManager is IDarkPoolServiceManager {
    // EigenLayer core contracts (will be set via constructor)
    address public immutable delegationManager;
    address public immutable avsDirectory;
    address public immutable registryCoordinator;

    // Minimum stake required for operators (0.001 ETH for testing)
    uint256 public constant MIN_OPERATOR_STAKE = 1e15; // 0.001 ETH

    // Slashing parameters
    uint256 public constant SLASHING_PERCENTAGE = 1000; // 10% (basis points)
    uint256 public constant MAX_SLASHING_PERCENTAGE = 10000; // 100%

    // Operator tracking
    mapping(address => bool) public operators;
    mapping(address => uint256) public operatorStake;
    mapping(address => bool) public isSlashed;
    mapping(address => uint256) public rewardAccumulated;
    uint256 public operatorCount;

    // Task validation tracking
    mapping(uint32 => mapping(address => bool)) public hasValidated;
    mapping(uint32 => uint256) public taskRewards;

    modifier onlyValidOperator() {
        require(
            operators[msg.sender] && !isSlashed[msg.sender],
            "Invalid or slashed operator"
        );
        _;
    }

    modifier onlyRegistryCoordinator() {
        require(msg.sender == registryCoordinator, "Only registry coordinator");
        _;
    }

    constructor(
        address _delegationManager,
        address _avsDirectory,
        address _registryCoordinator
    ) {
        delegationManager = _delegationManager;
        avsDirectory = _avsDirectory;
        registryCoordinator = _registryCoordinator;
    }

    /**
     * @dev Register as an operator with minimum stake
     */
    function registerOperator() external payable override {
        require(msg.value >= MIN_OPERATOR_STAKE, "Insufficient stake");
        require(!operators[msg.sender], "Already registered");

        operators[msg.sender] = true;
        operatorStake[msg.sender] = msg.value;
        operatorCount++;

        // TODO: Integrate with EigenLayer delegation manager
        // IDelegationManager(delegationManager).registerAsOperator(...);

        emit OperatorRegistered(msg.sender, msg.value);
    }

    /**
     * @dev Deregister operator and return stake (if not slashed)
     */
    function deregisterOperator() external override {
        require(operators[msg.sender], "Not registered");
        require(!isSlashed[msg.sender], "Slashed operators cannot deregister");

        operators[msg.sender] = false;
        uint256 stake = operatorStake[msg.sender];
        operatorStake[msg.sender] = 0;
        operatorCount--;

        // Return stake
        payable(msg.sender).transfer(stake);

        emit OperatorDeregistered(msg.sender);
    }

    /**
     * @dev Add more stake to existing registration
     */
    function addStake() external payable override {
        require(operators[msg.sender], "Not registered");
        require(msg.value > 0, "No stake provided");

        operatorStake[msg.sender] += msg.value;
        emit StakeUpdated(msg.sender, operatorStake[msg.sender]);
    }

    /**
     * @dev Slash an operator for malicious behavior
     */
    function slashOperator(
        address operator,
        uint256 percentage
    ) external onlyRegistryCoordinator {
        require(operators[operator], "Operator not registered");
        require(!isSlashed[operator], "Already slashed");
        require(percentage <= MAX_SLASHING_PERCENTAGE, "Percentage too high");

        uint256 stakeToSlash = (operatorStake[operator] * percentage) /
            MAX_SLASHING_PERCENTAGE;
        operatorStake[operator] -= stakeToSlash;
        isSlashed[operator] = true;

        // Transfer slashed amount to protocol treasury (for now, keep in contract)
        emit OperatorSlashed(operator, stakeToSlash);
    }

    /**
     * @dev Distribute rewards to operators who validated tasks correctly
     */
    function distributeTaskReward(
        uint32 taskIndex,
        address[] calldata validOperators
    ) external onlyRegistryCoordinator {
        require(taskRewards[taskIndex] > 0, "No reward for this task");

        uint256 rewardPerOperator = taskRewards[taskIndex] /
            validOperators.length;

        for (uint256 i = 0; i < validOperators.length; i++) {
            address operator = validOperators[i];
            require(
                operators[operator] && !isSlashed[operator],
                "Invalid operator"
            );
            require(
                hasValidated[taskIndex][operator],
                "Operator did not validate"
            );

            rewardAccumulated[operator] += rewardPerOperator;
            emit TaskValidationRewarded(taskIndex, operator, rewardPerOperator);
        }
    }

    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external {
        uint256 reward = rewardAccumulated[msg.sender];
        require(reward > 0, "No rewards to claim");

        rewardAccumulated[msg.sender] = 0;
        payable(msg.sender).transfer(reward);

        emit RewardDistributed(msg.sender, reward);
    }

    /**
     * @dev Record task validation by operator
     */
    function recordTaskValidation(
        uint32 taskIndex,
        address operator
    ) external onlyRegistryCoordinator {
        hasValidated[taskIndex][operator] = true;
    }

    /**
     * @dev Set reward amount for a task
     */
    function setTaskReward(
        uint32 taskIndex,
        uint256 rewardAmount
    ) external payable onlyRegistryCoordinator {
        taskRewards[taskIndex] = rewardAmount;
    }

    /**
     * @dev Check if an address is a valid operator
     */
    function isValidOperator(
        address operator
    ) external view override returns (bool) {
        return
            operators[operator] &&
            operatorStake[operator] >= MIN_OPERATOR_STAKE &&
            !isSlashed[operator];
    }

    /**
     * @dev Get operator stake amount
     */
    function getOperatorStake(
        address operator
    ) external view override returns (uint256) {
        return operatorStake[operator];
    }

    /**
     * @dev Get operator status
     */
    function getOperatorStatus(
        address operator
    )
        external
        view
        returns (bool registered, bool slashed, uint256 stake, uint256 rewards)
    {
        return (
            operators[operator],
            isSlashed[operator],
            operatorStake[operator],
            rewardAccumulated[operator]
        );
    }
}
