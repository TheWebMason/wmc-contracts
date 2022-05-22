// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "./Recoverable.sol";
import "./interfaces/ITransferBatch.sol";
import "./interfaces/IWmcVesting.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoin is
    ERC20,
    ERC20Permit,
    ERC20VotesComp,
    Recoverable,
    ITransferBatch,
    IWmcVesting
{
    mapping(address => VestingEntry) private _vestingOf;
    mapping(address => bool) private _isAirdropper;

    constructor() ERC20("WebMasonCoin", "WMC") ERC20Permit("WebMasonCoin") {
        _mint(_msgSender(), 10_000_000_000 * 10**decimals());

        _isAirdropper[_msgSender()] = true;
        emit AirdropperUpdated(_msgSender(), true);
    }

    function transferBatch(address[] memory accounts, uint256[] memory amounts)
        external
        override
        returns (bool)
    {
        require(accounts.length == amounts.length, "Mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            transfer(accounts[i], amounts[i]);
        }
        return true;
    }

    // Vesting
    function vestingOf(address account)
        external
        view
        override
        returns (
            bool isVested,
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
        isVested = _isVested(account);
        if (isVested) {
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
        return _vestingOf[account].amount > 0;
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

    function _vestingTimeLeft(address account) private view returns (uint32) {
        return
            _pureVestingTimeLeft(
                _vestingOf[account].lockup,
                _vestingOf[account].cliff,
                _vestingOf[account].vesting,
                uint64(block.timestamp) - _vestingOf[account].start
            );
    }

    function _pureVestingTimeLeft(
        uint32 lockupTime,
        uint32 cliffTime,
        uint32 vestingTime,
        uint64 passedTime
    ) private pure returns (uint32) {
        if (passedTime >= (lockupTime + vestingTime)) return 0;
        if (passedTime <= (lockupTime + cliffTime)) return vestingTime;
        return vestingTime - uint32(passedTime - lockupTime);
    }

    // Airdrop
    function setAirdropper(address account, bool status) external onlyOwner {
        _isAirdropper[account] = status;
        emit AirdropperUpdated(account, status);
    }

    function airdrop(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address account,
        uint96 amount
    ) external override {
        _airdrop(lockup, cliff, vesting, account, amount);
    }

    function airdropBatch(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address[] memory accounts,
        uint96[] memory amounts
    ) external override {
        require(accounts.length == amounts.length, "Mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            _airdrop(lockup, cliff, vesting, accounts[i], amounts[i]);
        }
    }

    modifier onlyAirdropper() {
        require(_isAirdropper[_msgSender()], "Caller is not allowed");
        _;
    }

    function _airdrop(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address account,
        uint96 amount
    ) private onlyAirdropper {
        if (vesting != 0 || lockup != 0) {
            _vestingOf[account].amount = uint96(_lockedOf(account) + amount);
            _vestingOf[account].start = uint64(block.timestamp);
            _vestingOf[account].lockup = lockup;
            _vestingOf[account].cliff = cliff;
            _vestingOf[account].vesting = _vestingTimeLeft(account) + vesting;
        }

        transfer(account, amount);
        emit Airdrop(
            account,
            amount,
            _vestingOf[account].start,
            _vestingOf[account].lockup,
            _vestingOf[account].cliff,
            _vestingOf[account].vesting
        );
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

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
