// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/INftStaking.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonNftStaking is INftStaking, Ownable, Recoverable {
    address public immutable WMC;
    address public NFT;

    // Mapping from token ID to staker address
    mapping(uint256 => address) private _tokenStaker;

    constructor(address token_) {
        WMC = token_;
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _tokenStaker[tokenId];
    }

    function setNft(address newNft) external onlyOwner {
        NFT = newNft;
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
