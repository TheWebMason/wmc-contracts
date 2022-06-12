// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/IERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "erc721a/contracts/extensions/ERC721AOwnersExplicit.sol";
import "./utils/Recoverable.sol";
import "./interfaces/IVesting.sol";
import "./utils/ProxyRegistry.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinSafe is
    ERC721A,
    ERC721AQueryable,
    ERC721AOwnersExplicit,
    IERC721ABurnable,
    Recoverable,
    ReentrancyGuard
{
    using Strings for uint256;

    // Metadata
    string private _contractURI = "";
    string private _base = "";
    string private _ext = ".json";
    bool public revealed = false;
    string private _notRevealedURI = "";

    bool public burnAllowed = false;
    address public immutable WMC;
    uint256 private constant _wmcAmount = 200_000 * 10**18;

    // WMC vesting parameters
    uint256 private _initTime;
    uint256 public vestingStart = 1669852800; // 2022-12-01T00:00:00.000Z
    uint32 private constant _vesting = 5 * 12 * 30 * 24 * 60 * 60;

    // OpenSea
    address private _proxyRegistry;

    // Mint
    address public signer; // TODO
    address public immutable wallet; // TODO
    mapping(address => uint256) public mintNonce;

    constructor(
        address token_,
        address wallet_,
        address proxyRegistry_
    ) ERC721A("WebMasonCoin Safe", "WMC-SAFE") {
        _initTime = block.timestamp;

        WMC = token_;
        wallet = wallet_;
        signer = _msgSender();
        _proxyRegistry = proxyRegistry_;
    }

    function mintAirdrop(address[] memory accounts, uint256[] memory quantities)
        external
        onlyOwner
    {
        require(accounts.length == quantities.length, "Mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            _checkTokenRestAmount(quantities[i]);
            _mint(accounts[i], quantities[i]);
        }
    }

    function mint(
        uint256 quantity,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) external payable nonReentrant {
        _checkTokenRestAmount(quantity);
        _checkSignature(_msgSender(), quantity, amount_, nonce_, signature_);
        _sendEth(wallet, amount_);
        _mint(_msgSender(), quantity);
    }

    function _checkTokenRestAmount(uint256 quantity) private view {
        require(
            (totalSupply() + quantity) * _wmcAmount <=
                IERC20(WMC).balanceOf(address(this)),
            "Insufficient WMC tokens for mint this quantity of NFTs"
        );
    }

    function _sendEth(address recipient, uint256 amount) private {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAILED");
    }

    // Signature
    function setSigner(address newSigner) public onlyOwner {
        signer = newSigner;
    }

    function signatureWallet(
        address wallet_,
        uint256 quantity_,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) public pure returns (address) {
        return
            ECDSA.recover(
                keccak256(abi.encode(wallet_, quantity_, amount_, nonce_)),
                signature_
            );
    }

    function _checkSignature(
        address wallet_,
        uint256 quantity_,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) private {
        require(
            mintNonce[wallet_] < nonce_,
            "Can not repeat a prior transaction!"
        );
        require(
            signatureWallet(wallet_, quantity_, amount_, nonce_, signature_) ==
                signer,
            "Not authorized to mint"
        );
        mintNonce[wallet_] = nonce_;
    }

    // Burn
    function burn(uint256 tokenId) public override {
        require(burnAllowed, "Burn not allowed");
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId, true);

        (uint64 tStart, , , uint32 tVesting, , , , ) = IVesting(WMC).vestingOf(
            tokenOwner
        );
        uint256 endTime = vestingStart + _vesting;

        if (block.timestamp >= endTime) {
            // If the vesting has already ended, then we do an airdrop without vesting.
            IVesting(WMC).airdrop(0, 0, 0, tokenOwner, uint96(_wmcAmount));
            return;
        }

        if (tStart == 0) {
            // If vesting is not set.
            if (vestingStart >= block.timestamp) {
                // If time is less than vestingStart. Then we set up a new vesting.
                IVesting(WMC).airdrop(
                    uint32(vestingStart - block.timestamp),
                    0,
                    _vesting,
                    tokenOwner,
                    uint96(_wmcAmount)
                );
                return;
            }
            if (vestingStart < block.timestamp) {
                // If time is greater than vestingStart.
                // We increase the vested amount or set vesting.
                uint256 remainingTime = 0;
                uint256 locked = 0;

                // Recalculate and set the vesting.
                remainingTime = endTime - block.timestamp;
                locked = (_wmcAmount * remainingTime) / _vesting;
                // Set vesting
                IVesting(WMC).airdrop(
                    0,
                    0,
                    uint32(remainingTime),
                    tokenOwner,
                    uint96(locked)
                );

                // Airdrop of unlocked amount
                IVesting(WMC).airdrop(
                    0,
                    0,
                    0,
                    tokenOwner,
                    uint96(_wmcAmount - locked)
                );
                return;
            }
        } else {
            /**
             * If vesting is set.
             * Option 1. tVesting is 5 years. The vesting was set before the tokens were unlocked.
             * Then we add the quantity to the old quantity. Tokens will be unlocked automatically.
             * Option 2. tVesting less than 5 years. The vesting was set after the tokens were unlocked.
             * Then we airdrop the unlocked amount and add the remaining amount.
             */
            uint256 locked = _wmcAmount;
            if (tVesting < _vesting) {
                uint256 unlocked = (_wmcAmount * (_vesting - tVesting)) /
                    _vesting;
                locked = _wmcAmount - unlocked;
                // Airdrop of unlocked amount.
                IVesting(WMC).airdrop(0, 0, 0, tokenOwner, uint96(unlocked));
            }
            // Add the remaining amount.
            IVesting(WMC).airdrop(0, 0, 1, tokenOwner, uint96(locked));
            return;
        }
    }

    function allowBurn() external onlyOwner {
        burnAllowed = true;
    }

    function setVestingStart(uint256 newTime) external onlyOwner {
        require(
            newTime < vestingStart && newTime >= _initTime,
            "The new time must be less than the old vesting start time"
        );
        vestingStart = newTime;
    }

    // Metadata
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A, IERC721Metadata)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        if (!revealed) return _notRevealedURI;

        return
            bytes(_base).length != 0
                ? string(abi.encodePacked(_base, tokenId.toString(), _ext))
                : "";
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function setNotRevealedURI(string memory uri_) external onlyOwner {
        _notRevealedURI = uri_;
    }

    function setContractURI(string memory uri_) external onlyOwner {
        _contractURI = uri_;
    }

    function setBaseURI(string memory uri_) external onlyOwner {
        _base = uri_;
    }

    function setBaseExtension(string memory fileExtension) external onlyOwner {
        _ext = fileExtension;
    }

    // OpenSea
    function isApprovedForAll(address owner, address operator)
        public
        view
        override(ERC721A, IERC721)
        returns (bool)
    {
        if (
            _proxyRegistry != address(0) &&
            address(ProxyRegistry(_proxyRegistry).proxies(owner)) == operator
        ) return true;
        else return super.isApprovedForAll(owner, operator);
    }

    function unsetProxyRegistry() external onlyOwner {
        _proxyRegistry = address(0);
    }

    // Extra
    function setOwnersExplicit(uint256 quantity) external {
        _setOwnersExplicit(quantity);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
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
