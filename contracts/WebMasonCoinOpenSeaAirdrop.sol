// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/Recoverable.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinOpenSeaAirdrop is Ownable, Recoverable {
    address public immutable WMC;

    // WMC vesting parameters
    uint256 private _initTime;
    uint256 public vestingStart = 1669852800; // 2022-12-01T00:00:00.000Z
    uint32 private constant _vesting = 5 * 12 * 30 * 24 * 60 * 60; // 60mo = 5y

    constructor(address token_) {
        _initTime = block.timestamp;
        WMC = token_;
    }

    function setVestingStart(uint256 newTime) external onlyOwner {
        require(
            newTime < vestingStart && newTime >= _initTime,
            "The new time must be less than the old vesting start time"
        );
        vestingStart = newTime;
    }

    function _getRecoverableAmount(address token)
        internal
        view
        override
        returns (uint256)
    {
        if (token == WMC) return 0;
        else if (token == address(0)) return address(this).balance;
        else return IERC20(token).balanceOf(address(this));
    }
}
