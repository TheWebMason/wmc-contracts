// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWmcVesting.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinOpenSeaAirdrop is Ownable {
    address public immutable TOKEN;
    bytes32 public merkleRoot;
    uint256 public endTime;
    mapping(address => bool) claimed;

    event Claimed(address indexed account, uint96 amount);

    constructor(address token_) public {
        TOKEN = token_;
    }

    function setRoot(bytes32 merkleRoot_) external onlyOwner {
        merkleRoot = merkleRoot_;
        endTime = block.timestamp + 365 * 24 * 60 * 60;
    }

    function claim(
        address account,
        uint96 amount,
        bytes32[] calldata merkleProof
    ) external {
        require(!claimed[account], "Already claimed");
        require(
            _verify(_leaf(account, amount), merkleProof),
            "MerkleDistributor: Invalid proof."
        );

        require(
            IWmcVesting(TOKEN).airdrop(
                6 * 30 * 24 * 60 * 60, // lockup
                0, // cliff
                5 * 365 * 24 * 60 * 60, // vesting
                account,
                amount
            ),
            "TRANSFER_FAILED"
        );

        claimed[account] = true;
        emit Claimed(account, amount);
    }

    function _leaf(address account, uint256 amount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account, amount));
    }

    function _verify(bytes32 leaf, bytes32[] memory merkleProof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    modifier isEnded() {
        require(block.timestamp >= endTime, "Too early");
        _;
    }

    function claim_rest_of_tokens_and_selfdestruct()
        external
        onlyOwner
        isEnded
    {
        require(
            IERC20(TOKEN).transfer(
                owner(),
                IERC20(TOKEN).balanceOf(address(this))
            )
        );
        selfdestruct;
    }
}
