// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRecoverable {
    event RecoveredFunds(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    function recoverFunds(
        address token,
        uint256 amount,
        address recipient
    ) external returns (bool);
}
