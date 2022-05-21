// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 @dev The contract is intendent to help recovering arbitrary ERC20 tokens and ETH accidentally transferred to the contract address
 */
abstract contract Recoverable is Ownable {
    event RecoveredFunds(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    function _getRecoverableAmount(address token)
        internal
        view
        virtual
        returns (uint256)
    {
        if (token == address(0)) return address(this).balance;
        else return IERC20(token).balanceOf(address(this));
    }

    /**
     @param token ERC20 token's address to recover or address(0) to recover ETH
     @param amount to recover from contract's address
     @param recipient address to receive tokens from the contract
     */
    function recoverFunds(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        uint256 recoverableAmount = _getRecoverableAmount(token);
        require(
            amount <= recoverableAmount,
            "Recoverable: RECOVERABLE_AMOUNT_NOT_ENOUGH"
        );
        if (token == address(0)) _transferEth(amount, recipient);
        else _transferErc20(token, amount, recipient);
        emit RecoveredFunds(token, amount, recipient);
    }

    function _transferEth(uint256 amount, address recipient) internal {
        address payable toPayable = payable(recipient);
        toPayable.transfer(amount);
    }

    function _transferErc20(
        address token,
        uint256 amount,
        address recipient
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, recipient, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Recoverable: TRANSFER_FAILED"
        );
    }
}
