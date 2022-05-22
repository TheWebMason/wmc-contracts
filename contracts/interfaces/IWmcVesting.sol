// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWmcVesting {
    struct VestingParams {
        uint64 lockup;
        uint64 vesting;
    }
    struct Vesting {
        uint128 amount;
        uint64 at;
    }

    event AirdropperUpdated(address indexed account, bool status);
    event Airdrop(address indexed account, uint256 amount, uint256 time);

    function isVested(address account) external view returns (bool);

    function lockedOf(address account) external view returns (uint256);

    function vestingOf(address account)
        external
        view
        returns (
            uint256 balance,
            bool isvested,
            uint64 at,
            uint256 total,
            uint256 locked,
            uint256 unlocked
        );

    function transferBatch(address[] memory accounts, uint256[] memory amounts)
        external
        returns (bool);

    function airdrop(address account, uint256 amount) external returns (bool);

    function airdropBatch(address[] memory accounts, uint256[] memory amounts)
        external
        returns (bool);
}
