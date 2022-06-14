// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/Recoverable.sol";
import "./interfaces/IVesting.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinOpenSeaAirdrop is Ownable, Recoverable {
    address public immutable WMC;

    // WMC vesting parameters
    uint256 private _initTime;
    uint256 public vestingStart = 1669852800; // 2022-12-01T00:00:00.000Z
    uint32 private constant _vesting = 5 * 12 * 30 * 24 * 60 * 60; // 60mo = 5y

    // Airdrop
    bytes32 public merkleRoot;
    uint256 public endTime;

    mapping(address => bool) public claimed;
    event AirdropClaimed(address indexed account, uint256 amount);

    constructor(address token_) {
        _initTime = block.timestamp;
        WMC = token_;
    }

    // Airdrop
    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        require(!claimed[account], "Already claimed");
        require(
            _verify(_leaf(account, amount), merkleProof),
            "MerkleDistributor: Invalid  merkle proof"
        );

        claimed[account] = true;
        emit AirdropClaimed(account, amount);
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

    function setRoot(bytes32 merkleRoot_, uint256 duration) external onlyOwner {
        merkleRoot = merkleRoot_;
        endTime = block.timestamp + duration;
    }

    function claim_rest_of_tokens_and_selfdestruct() external onlyOwner {
        require(block.timestamp >= endTime, "Too early");
        require(
            IERC20(WMC).transfer(owner(), IERC20(WMC).balanceOf(address(this)))
        );
        selfdestruct(payable(owner()));
    }

    // Vesting
    function setVestingStart(uint256 newTime) external onlyOwner {
        require(
            newTime < vestingStart && newTime >= _initTime,
            "The new time must be less than the old vesting start time"
        );
        vestingStart = newTime;
    }

    // Extra
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
