// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "./Recoverable.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoin is ERC20, ERC20Permit, ERC20VotesComp, Recoverable {
    struct VestingParams {
        uint256 lockup;
        uint256 cliff;
        uint256 vesting;
    }
    VestingParams public vestingParams =
        VestingParams({
            lockup: 6 * 30 * 24 * 60 * 60, // 6 months
            cliff: 1 * 30 * 24 * 60 * 60, // 1 month
            vesting: 5 * 12 * 30 * 24 * 60 * 60 // 5 years
        });

    struct Vesting {
        uint256 amount;
        uint256 at;
    }
    mapping(address => Vesting) public vesting;

    mapping(address => bool) public isAirdropper;

    event Airdrop(address indexed recipients, uint256 amount, uint256 time);

    constructor() ERC20("WebMasonCoin", "WMC") ERC20Permit("WebMasonCoin") {
        _mint(_msgSender(), 10_000_000_000 * 10**decimals());
        isAirdropper[_msgSender()] = true;
    }

    function multiTransfer(
        address[] memory recipients,
        uint256[] memory amounts
    ) public {
        require(
            recipients.length == amounts.length,
            "ERC20: multiTransfer mismatch"
        );
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], amounts[i]);
        }
    }

    // Airdrop
    modifier onlyAirdropper() {
        require(
            isAirdropper[_msgSender()],
            "Airdroppable: caller is not allowed"
        );
        _;
    }

    function setAirdropper(address account, bool status) public onlyOwner {
        isAirdropper[account] = status;
    }

    function airdrop(address[] memory recipients, uint256[] memory amounts)
        public
        onlyAirdropper
    {
        require(recipients.length == amounts.length, "ERC20: airdrop mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            vesting[recipients[i]].at = block.timestamp;
            vesting[recipients[i]].amount += amounts[i];
            transfer(recipients[i], amounts[i]);
            emit Airdrop(recipients[i], amounts[i], block.timestamp);
        }
    }

    function isVested(address account) public view returns (bool) {
        return vesting[account].amount > 0;
    }

    function lockedOf(address account) public view returns (uint256) {
        if (!isVested(account)) return 0;

        if (
            (block.timestamp - vesting[account].at) >=
            (vestingParams.lockup + vestingParams.vesting)
        ) return 0;

        if (
            (block.timestamp - vesting[account].at) <=
            vestingParams.lockup + vestingParams.cliff
        ) return vesting[account].amount;

        return
            vesting[account].amount -
            (vesting[account].amount *
                (block.timestamp -
                    vesting[account].at -
                    vestingParams.lockup)) /
            vestingParams.vesting;
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (isVested(from)) {
            uint256 lockedAmount = lockedOf(from);
            if (lockedAmount == 0) {
                delete vesting[from];
            } else {
                require(
                    (balanceOf(from) - amount) >= lockedAmount,
                    "Amount exceeds locked amount"
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
