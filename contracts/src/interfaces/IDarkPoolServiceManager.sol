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
}
