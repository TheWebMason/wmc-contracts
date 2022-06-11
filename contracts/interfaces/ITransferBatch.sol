// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITransferBatch {
    function transferBatch(address[] memory accounts, uint256[] memory amounts)
        external
        returns (bool);

    function transferBatchFrom(
        address from,
        address[] memory accounts,
        uint256[] memory amounts
    ) external returns (bool);
}
