// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/Vesting.sol";
import "./utils/Recoverable.sol";
import "./utils/TransferBatch.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoin is
    ERC20,
    ERC20Permit,
    Ownable,
    Vesting,
    Recoverable,
    TransferBatch
{
    constructor() ERC20("WebMasonCoin", "WMC") ERC20Permit("WebMasonCoin") {
        _mint(_msgSender(), 10_000_000_000 * 10**decimals());
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, Vesting) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
