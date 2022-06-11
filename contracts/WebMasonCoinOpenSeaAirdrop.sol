// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVesting.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinOpenSeaAirdrop is Ownable {
    address public immutable TOKEN;
    bytes32 public merkleRoot;
    uint256 public endTime;

    struct VestingParams {
        uint32 lockup;
        uint32 cliff;
        uint32 vesting;
    }
    VestingParams public vestingParams =
        VestingParams({
            lockup: 6 * 30 * 24 * 60 * 60,
            cliff: 0,
            vesting: 5 * 365 * 24 * 60 * 60
        });

    mapping(address => bool) public claimed;
    event Claimed(address indexed account, uint256 amount);

    constructor(address token_) {
        TOKEN = token_;
    }

    function setRoot(bytes32 merkleRoot_, uint256 duration) external onlyOwner {
        merkleRoot = merkleRoot_;
        endTime = block.timestamp + duration;
    }

    function setVestingParams(
        uint32 lockup,
        uint32 cliff,
        uint32 vesting
    ) external onlyOwner {
        vestingParams = VestingParams({
            lockup: lockup,
            cliff: cliff,
            vesting: vesting
        });
    }

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

        require(
            IVesting(TOKEN).airdrop(
                vestingParams.lockup,
                vestingParams.cliff,
                vestingParams.vesting,
                account,
                uint96(amount)
            ),
            "AIRDROP_FAILED"
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

    function claim_rest_of_tokens_and_selfdestruct() external onlyOwner {
        require(block.timestamp >= endTime, "Too early");
        require(
            IERC20(TOKEN).transfer(
                owner(),
                IERC20(TOKEN).balanceOf(address(this))
            )
        );
        selfdestruct(payable(owner()));
    }
}
