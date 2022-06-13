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
contract WebMasonStalkerClan is
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

    // OpenSea
    address private _proxyRegistry;

    // Mint
    address public immutable wallet;
    address public signer;
    mapping(address => uint256) public mintNonce;

    // Burn
    bool public burnAllowed = false;

    // Staking
    address public staking;

    constructor(
        address token_,
        address wallet_,
        address signer_,
        address proxyRegistry_
    ) ERC721A("WebMason Stalker Clan", "WM-STALKER") {
        WMC = token_;
        wallet = wallet_;
        signer = signer_;
        _proxyRegistry = proxyRegistry_;
    }

    function mintAirdrop(address[] memory accounts, uint256[] memory quantities)
        external
        onlyOwner
    {
        require(accounts.length == quantities.length, "Mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            _mint(accounts[i], quantities[i]);
        }
    }

    function mint(
        uint256 quantity,
        uint256 amount_,
        uint256 nonce_,
        bytes memory signature_
    ) external payable nonReentrant {
        _checkSignature(_msgSender(), quantity, amount_, nonce_, signature_);
        _sendEth(wallet, amount_);
        _mint(_msgSender(), quantity);
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
        _burn(tokenId, true);
    }

    function allowBurn() external onlyOwner {
        burnAllowed = true;
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
        // Staking
        else return super.isApprovedForAll(owner, operator);
    }

    function unsetProxyRegistry() external onlyOwner {
        _proxyRegistry = address(0);
    }

    // Staking
    function ownerOrStakerOf(uint256 tokenId) public pure returns (address) {
        address tokenOwner = ownerOf(tokenId);
        if (tokenOwner != staking) return tokenOwner;
        return tokenOwner;
    }

    function setStaking(address newStaking) external onlyOwner {
        staking = newStaking;
    }

    // Extra
    function setOwnersExplicit(uint256 quantity) external {
        _setOwnersExplicit(quantity);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
