// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IDarkPoolServiceManager.sol";

/**
 * @title DarkPoolServiceManager
 * @dev Simplified service manager for the DarkPool AVS
 */
contract DarkPoolServiceManager is IDarkPoolServiceManager {
    // Minimum stake required for operators (0.001 ETH for testing)
    uint256 public constant MIN_OPERATOR_STAKE = 1e15; // 0.001 ETH

    // Operator tracking
    mapping(address => bool) public operators;
    mapping(address => uint256) public operatorStake;
    uint256 public operatorCount;

    // Events
    event OperatorRegistered(address indexed operator, uint256 stake);
    event OperatorDeregistered(address indexed operator);
    event StakeUpdated(address indexed operator, uint256 newStake);

    /**
     * @dev Register as an operator with minimum stake
     */
    function registerOperator() external payable override {
        require(msg.value >= MIN_OPERATOR_STAKE, "Insufficient stake");
        require(!operators[msg.sender], "Already registered");

        operators[msg.sender] = true;
        operatorStake[msg.sender] = msg.value;
        operatorCount++;

        emit OperatorRegistered(msg.sender, msg.value);
    }

    /**
     * @dev Deregister operator and return stake
     */
    function deregisterOperator() external override {
        require(operators[msg.sender], "Not registered");

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
     * @dev Check if an address is a valid operator
     */
    function isValidOperator(
        address operator
    ) external view override returns (bool) {
        return
            operators[operator] &&
            operatorStake[operator] >= MIN_OPERATOR_STAKE;
    }

    /**
     * @dev Get operator stake amount
     */
    function getOperatorStake(
        address operator
    ) external view override returns (uint256) {
        return operatorStake[operator];
    }
}
