// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ITransferBatch.sol";

abstract contract TransferBatch is ERC20, ITransferBatch {
    modifier checkMismatch(
        address[] memory accounts,
        uint256[] memory amounts
    ) {
        require(accounts.length == amounts.length, "Mismatch");
        _;
    }

    function transferBatch(address[] memory accounts, uint256[] memory amounts)
        external
        override
        checkMismatch(accounts, amounts)
        returns (bool)
    {
        address from = _msgSender();
        for (uint256 i = 0; i < accounts.length; i++) {
            _transfer(from, accounts[i], amounts[i]);
        }
        return true;
    }

    function transferBatchFrom(
        address from,
        address[] memory accounts,
        uint256[] memory amounts
    ) external override checkMismatch(accounts, amounts) returns (bool) {
        address spender = _msgSender();
        for (uint256 i = 0; i < accounts.length; i++) {
            _spendAllowance(from, spender, amounts[i]);
            _transfer(from, accounts[i], amounts[i]);
        }
        return true;
    }
}
