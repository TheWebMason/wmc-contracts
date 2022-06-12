// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/utils/Strings.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/IERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "erc721a/contracts/extensions/ERC721AOwnersExplicit.sol";
import "./utils/Recoverable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVesting.sol";
import "./utils/ProxyRegistry.sol";

/// @custom:security-contact support@webmason.io
contract WebMasonCoinSafe is
    ERC721A,
    ERC721AQueryable,
    ERC721AOwnersExplicit,
    IERC721ABurnable,
    Recoverable
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
    uint256 public vestingStart = 1669852800; // 2022-12-01T00:00:00.000Z
    uint32 private constant _vesting = 5 * 12 * 30 * 24 * 60 * 60;

    // OpenSea
    address private _proxyRegistry;

    constructor(address token_, address proxyRegistry_)
        ERC721A("WebMasonCoin Safe", "WMC-SAFE")
    {
        WMC = token_;
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

    function mint(uint256 quantity) external payable {
        _checkTokenRestAmount(quantity);
        _mint(_msgSender(), quantity);
    }

    function _checkTokenRestAmount(uint256 quantity) private view {
        require(
            (totalSupply() + quantity) * _wmcAmount <=
                IERC20(WMC).balanceOf(address(this)),
            "Insufficient WMC tokens for mint this quantity of NFTs"
        );
    }

    function burn(uint256 tokenId) external {
        require(burnAllowed, "Burn not allowed");
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId, true);
        IVesting(WMC).airdrop(
            (vestingStart > block.timestamp)
                ? uint32(vestingStart - block.timestamp)
                : 0,
            0,
            _vesting,
            tokenOwner,
            uint96(_wmcAmount)
        );
    }

    function allowBurn() external onlyOwner {
        burnAllowed = true;
    }

    function setVestingStart(uint256 newTime) external onlyOwner {
        require(
            newTime < vestingStart,
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
