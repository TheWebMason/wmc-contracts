// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftStaking {
    function ownerOf(uint256 tokenId) external view returns (address);
}
