// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "./Recoverable.sol";
import "./interfaces/IWmcVesting.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoin is
    ERC20,
    ERC20Permit,
    ERC20VotesComp,
    Recoverable,
    IWmcVesting
{
    VestingParams public vestingParams =
        VestingParams({
            lockup: 15552000, // 6 * 30 * 24 * 60 * 60, // 6 months
            vesting: 155520000 // 5 * 12 * 30 * 24 * 60 * 60 // 5 years
        });
    mapping(address => Vesting) private _vesting;
    mapping(address => bool) public isAirdropper;

    constructor() ERC20("WebMasonCoin", "WMC") ERC20Permit("WebMasonCoin") {
        _mint(_msgSender(), 10_000_000_000 * 10**decimals());

        isAirdropper[_msgSender()] = true;
        emit AirdropperUpdated(_msgSender(), true);
    }

    // Vesting
    function isVested(address account) public view override returns (bool) {
        return _vesting[account].amount > 0;
    }

    function lockedOf(address account) public view override returns (uint256) {
        if (!isVested(account)) return 0;
        return
            _lockedOf(
                vestingParams.lockup,
                vestingParams.vesting,
                uint64(block.timestamp) - _vesting[account].at,
                uint256(_vesting[account].amount)
            );
    }

    function _lockedOf(
        uint64 lockupTime,
        uint64 vestingTime,
        uint64 passedTime,
        uint256 amount
    ) private pure returns (uint256) {
        if (passedTime >= (lockupTime + vestingTime)) return 0;
        if (passedTime <= lockupTime) return amount;
        return amount - (amount * (passedTime - lockupTime)) / vestingTime;
    }

    function vestingOf(address account)
        external
        view
        override
        returns (
            uint256 balance,
            bool isvested,
            uint64 at,
            uint256 total,
            uint256 locked,
            uint256 unlocked
        )
    {
        balance = balanceOf(account);
        isvested = isVested(account);
        if (isvested) {
            at = _vesting[account].at;
            total = uint256(_vesting[account].amount);
            locked = _lockedOf(
                vestingParams.lockup,
                vestingParams.vesting,
                uint64(block.timestamp) - at,
                total
            );
        }
        unlocked = balance - locked;
    }

    function transferBatch(address[] memory accounts, uint256[] memory amounts)
        external
        override
        returns (bool)
    {
        require(accounts.length == amounts.length, "TransferBatch mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            transfer(accounts[i], amounts[i]);
        }
        return true;
    }

    function setLockup(uint64 lockup) external onlyOwner {
        vestingParams.lockup = lockup;
    }

    // Airdrop
    modifier onlyAirdropper() {
        require(isAirdropper[_msgSender()], "Caller is not allowed");
        _;
    }

    function setAirdropper(address account, bool status) external onlyOwner {
        isAirdropper[account] = status;
        emit AirdropperUpdated(account, status);
    }

    function airdrop(address account, uint256 amount)
        external
        override
        returns (bool)
    {
        _airdrop(account, amount);
        return true;
    }

    function airdropBatch(address[] memory accounts, uint256[] memory amounts)
        external
        override
        returns (bool)
    {
        require(accounts.length == amounts.length, "Airdrop mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            _airdrop(accounts[i], amounts[i]);
        }
        return true;
    }

    function _airdrop(address account, uint256 amount) private onlyAirdropper {
        _vesting[account].amount = uint128(lockedOf(account) + amount);
        _vesting[account].at = uint64(block.timestamp);
        transfer(account, amount);
        emit Airdrop(account, amount, block.timestamp);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (isVested(from)) {
            uint256 lockedAmount = _lockedOf(
                vestingParams.lockup,
                vestingParams.vesting,
                uint64(block.timestamp) - _vesting[from].at,
                uint256(_vesting[from].amount)
            );
            if (lockedAmount == 0) {
                delete _vesting[from];
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
