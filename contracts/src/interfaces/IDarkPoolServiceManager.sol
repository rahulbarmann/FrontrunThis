// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IDarkPoolServiceManager
 * @dev Interface for the DarkPool service manager
 */
interface IDarkPoolServiceManager {
    // Events
    event OperatorRegistered(address indexed operator, uint256 stake);
    event OperatorDeregistered(address indexed operator);
    event StakeUpdated(address indexed operator, uint256 newStake);
    event OperatorSlashed(address indexed operator, uint256 amount);
    event RewardDistributed(address indexed operator, uint256 amount);
    event TaskValidationRewarded(
        uint32 indexed taskIndex,
        address indexed operator,
        uint256 reward
    );

    /**
     * @dev Register as an operator with minimum stake
     */
    function registerOperator() external payable;

    /**
     * @dev Deregister operator and return stake
     */
    function deregisterOperator() external;

    /**
     * @dev Add more stake to existing registration
     */
    function addStake() external payable;

    /**
     * @dev Check if an address is a valid operator
     */
    function isValidOperator(address operator) external view returns (bool);

    /**
     * @dev Get operator stake amount
     */
    function getOperatorStake(address operator) external view returns (uint256);

    /**
     * @dev Record task validation by operator
     */
    function recordTaskValidation(uint32 taskIndex, address operator) external;

    /**
     * @dev Set reward amount for a task
     */
    function setTaskReward(
        uint32 taskIndex,
        uint256 rewardAmount
    ) external payable;

    /**
     * @dev Distribute rewards to operators who validated tasks correctly
     */
    function distributeTaskReward(
        uint32 taskIndex,
        address[] calldata validOperators
    ) external;
}
