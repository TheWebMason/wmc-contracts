// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IVesting.sol";

abstract contract Vesting is ERC20, Ownable, IVesting {
    mapping(address => VestingEntry) private _vestingOf;
    mapping(address => bool) private _isAirdropper;

    function vestingOf(address account)
        external
        view
        override
        returns (
            uint64 start,
            uint32 lockup,
            uint32 cliff,
            uint32 vesting,
            uint96 balance,
            uint96 vested,
            uint96 locked,
            uint96 unlocked
        )
    {
        if (_isVested(account)) {
            start = _vestingOf[account].start;
            lockup = _vestingOf[account].lockup;
            cliff = _vestingOf[account].cliff;
            vesting = _vestingOf[account].vesting;
            vested = _vestingOf[account].amount;
            locked = uint96(_lockedOf(account));
        }
        balance = uint96(balanceOf(account));
        unlocked = balance - locked;
    }

    function _isVested(address account) private view returns (bool) {
        return _vestingOf[account].amount != 0;
    }

    function _lockedOf(address account) private view returns (uint256) {
        return
            _pureLockedOf(
                _vestingOf[account].lockup,
                _vestingOf[account].cliff,
                _vestingOf[account].vesting,
                uint64(block.timestamp) - _vestingOf[account].start,
                uint256(_vestingOf[account].amount)
            );
    }

    function _pureLockedOf(
        uint32 lockupTime,
        uint32 cliffTime,
        uint32 vestingTime,
        uint64 passedTime,
        uint256 amount
    ) private pure returns (uint256) {
        if (passedTime >= (lockupTime + vestingTime)) return 0;
        if (passedTime <= (lockupTime + cliffTime)) return amount;
        return amount - (amount * (passedTime - lockupTime)) / vestingTime;
    }

    // Airdrop with vesting
    function setAirdropper(address account, bool status) external onlyOwner {
        _isAirdropper[account] = status;
        emit AirdropperUpdated(account, status);
    }

    modifier onlyAirdropper() {
        require(_isAirdropper[_msgSender()], "Caller is not allowed");
        _;
    }

    function airdrop(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address account,
        uint96 amount
    ) external override onlyAirdropper returns (bool) {
        _airdrop(
            _msgSender(),
            uint64(block.timestamp),
            lockup,
            cliff,
            vesting,
            account,
            amount
        );
        return true;
    }

    function airdropBatch(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address[] memory accounts,
        uint96[] memory amounts
    ) external override onlyAirdropper returns (bool) {
        require(accounts.length == amounts.length, "Mismatch");
        address from = _msgSender();
        uint64 start = uint64(block.timestamp);
        for (uint256 i = 0; i < accounts.length; i++) {
            _airdrop(
                from,
                start,
                lockup,
                cliff,
                vesting,
                accounts[i],
                amounts[i]
            );
        }
        return true;
    }

    function _airdrop(
        address from,
        uint64 start,
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address account,
        uint96 amount
    ) private {
        if (vesting != 0 || cliff != 0 || lockup != 0) {
            if (!_isVested(account)) {
                _vestingOf[account].start = start;
                _vestingOf[account].lockup = lockup;
                _vestingOf[account].cliff = cliff;
                _vestingOf[account].vesting = vesting;
            }
            _vestingOf[account].amount += amount;
            emit VestingEntryUpdated(
                account,
                _vestingOf[account].amount,
                _vestingOf[account].start,
                _vestingOf[account].lockup,
                _vestingOf[account].cliff,
                _vestingOf[account].vesting
            );
        }

        _transfer(from, account, amount);
        emit Airdrop(account, amount);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (_isVested(from)) {
            uint256 lockedAmount = _lockedOf(from);
            if (lockedAmount == 0) {
                delete _vestingOf[from];
            } else {
                require(
                    (balanceOf(from) - amount) >= lockedAmount,
                    "Transfer amount exceeds locked amount"
                );
            }
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}
