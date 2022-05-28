// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVesting {
    struct VestingEntry {
        uint96 amount;
        uint64 start;
        uint32 lockup;
        uint32 cliff;
        uint32 vesting;
    }

    event AirdropperUpdated(address indexed account, bool status);
    event Airdrop(address indexed account, uint96 amount);
    event VestingEntryUpdated(
        address indexed account,
        uint96 amount,
        uint64 start,
        uint32 lockup,
        uint32 cliff,
        uint32 vesting
    );

    function vestingOf(address account)
        external
        view
        returns (
            uint64 start,
            uint32 lockup,
            uint32 cliff,
            uint32 vesting,
            uint96 balance,
            uint96 vested,
            uint96 locked,
            uint96 unlocked
        );

    function setVesting(
        address account,
        uint96 amount,
        uint64 start,
        uint32 lockup,
        uint32 cliff,
        uint32 vesting
    ) external returns (bool);

    function airdrop(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address account,
        uint96 amount
    ) external returns (bool);

    function airdropBatch(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting,
        address[] memory accounts,
        uint96[] memory amounts
    ) external returns (bool);
}
