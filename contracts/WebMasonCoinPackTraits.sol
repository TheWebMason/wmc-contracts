// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinPackTraits is Ownable {
    address public immutable NFT;
    address public immutable TOKEN;

    constructor(address nft_, address token_) {
        NFT = nft_;
        TOKEN = token_;
    }
}
