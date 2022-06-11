// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./ERC721A.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/ProxyRegistry.sol";
import "./utils/Recoverable.sol";
import "./interfaces/IVesting.sol";

interface INftDescriptor {
    function contractURI() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface IWebMasonCoinPackage {
    function lockedOf(uint256 tokenId) external view returns (uint256);

    function claimedOf(uint256 tokenId) external view returns (uint256);

    function unclaimedOf(uint256 tokenId) external view returns (uint256);
}

/// @custom:security-contact support@webmason.io
contract WebMasonCoinPackage is ERC721A, Recoverable, IWebMasonCoinPackage {
    address public immutable TOKEN;
    uint8 private constant _DECIMALS = 18;

    uint8 private constant _totalPackages = 7;
    uint96[_totalPackages] public PACKAGE = [
        uint96(10_000 * 10**_DECIMALS),
        uint96(25_000 * 10**_DECIMALS),
        uint96(50_000 * 10**_DECIMALS),
        uint96(100_000 * 10**_DECIMALS),
        uint96(250_000 * 10**_DECIMALS),
        uint96(500_000 * 10**_DECIMALS),
        uint96(1_000_000 * 10**_DECIMALS)
    ];

    struct VestingParams {
        bool isAllowed;
        uint32 lockup;
        uint32 vesting;
    }
    VestingParams public vestingParams =
        VestingParams({
            isAllowed: false,
            lockup: 6 * 30 * 24 * 60 * 60, // 6 months
            vesting: 5 * 12 * 30 * 24 * 60 * 60 // 5 years
        });

    struct VestingStats {
        uint96 total;
        uint96 claimed;
    }
    VestingStats public vestingStats;

    // tokenId => claimed token amount
    mapping(uint256 => uint96) internal _claimedOf;

    // Metadata
    address private _descriptor;

    // OpenSea
    address private _proxyRegistry;

    constructor(address token_, address proxyRegistry_)
        ERC721A("WebMasonCoin Package", "WMC-PACK")
    {
        TOKEN = token_;
        _proxyRegistry = proxyRegistry_;
    }

    modifier checkQuantity(uint256 quantity) {
        require(quantity > 0, "Invalid quantity");
        _;
    }

    modifier checkPackageNumber(uint8 packageNumber) {
        require(packageNumber < _totalPackages, "Invalid package number");
        _;
    }

    modifier checkTokens(uint8 packageNumber, uint256 quantity) {
        vestingStats.total += PACKAGE[packageNumber] * uint96(quantity);
        require(
            IERC20(TOKEN).balanceOf(address(this)) >=
                (vestingStats.total - vestingStats.claimed),
            "Insufficient tokens"
        );
        _;
    }

    function mintAirdrop(uint8 packageNumber, address[] memory accounts)
        external
        onlyOwner
        checkQuantity(accounts.length)
        checkPackageNumber(packageNumber)
        checkTokens(packageNumber, accounts.length)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            _safeMint(accounts[i], packageNumber, 1);
        }
    }

    function mint(uint8 packageNumber, uint256 quantity)
        external
        payable
        checkQuantity(quantity)
        checkPackageNumber(packageNumber)
        checkTokens(packageNumber, quantity)
    {
        _safeMint(_msgSender(), packageNumber, quantity);
    }

    /**
     * @dev Pack ERC20 tokens into a ERC721 package
     */
    function pack(uint8 packageNumber, uint256 quantity)
        external
        checkQuantity(quantity)
        checkPackageNumber(packageNumber)
    {
        uint96 amount = PACKAGE[packageNumber] * uint96(quantity);
        vestingStats.total += amount;
        require(
            IERC20(TOKEN).transferFrom(_msgSender(), address(this), amount),
            "TRANSFER_FAILED"
        );
        _safeMint(_msgSender(), packageNumber, quantity);
    }

    // Vesting
    function lockedOf(uint256 tokenId) public view override returns (uint256) {
        TokenOwnership memory ownership = _ownershipOf(tokenId);
        return
            _lockedOf(
                vestingParams.lockup,
                vestingParams.vesting,
                uint64(block.timestamp) - ownership.mintedAt,
                PACKAGE[ownership.package]
            );
    }

    function _lockedOf(
        uint64 lockupTime,
        uint64 vestingTime,
        uint64 passedTime,
        uint256 amount
    ) private pure returns (uint256) {
        //uint64 passedTime = uint64(block.timestamp - mintedAt);
        if (passedTime >= (lockupTime + vestingTime)) return 0;
        if (passedTime <= lockupTime) return amount;
        return amount - (amount * (passedTime - lockupTime)) / vestingTime;
    }

    function claimedOf(uint256 tokenId) public view override returns (uint256) {
        return _claimedOf[tokenId];
    }

    function unclaimedOf(uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        TokenOwnership memory ownership = _ownershipOf(tokenId);
        uint256 vestedAmount = PACKAGE[ownership.package];
        return
            vestedAmount -
            claimedOf(tokenId) -
            _lockedOf(
                vestingParams.lockup,
                vestingParams.vesting,
                uint64(block.timestamp) - ownership.mintedAt,
                vestedAmount
            );
    }

    function dataOf(uint256 tokenId)
        external
        view
        returns (
            address token,
            address owner,
            uint64 mintedAt,
            uint8 package,
            uint256 vested,
            uint256 claimed,
            uint256 unclaimed
        )
    {
        // override
        TokenOwnership memory ownership = _ownershipOf(tokenId);

        token = TOKEN;
        owner = ownership.owner;
        mintedAt = ownership.mintedAt;
        package = ownership.package;

        vested = PACKAGE[ownership.package];
        claimed = claimedOf(tokenId);
        unclaimed =
            vested -
            claimed -
            _lockedOf(
                vestingParams.lockup,
                vestingParams.vesting,
                uint64(block.timestamp) - mintedAt,
                vested
            );
    }

    /*function claim(uint256 tokenId) public {
        //TokenOwnership memory ownership = _ownershipOf(tokenId);
        //claimedOf(tokenId);
        // проверка owner
        //uint96 unClaimed = 0; // ?
        //_transferErc20(TOKEN, unClaimed, ownership.owner);
    }*/

    function burn(uint256 tokenId) external {
        // override
        // if alloved burn
        //TokenOwnership memory ownership = _ownershipOf(tokenId);
        //uint256 vestedAmount = PACKAGE[ownership.package];
        //uint96 claimed = 0; // ?
        //uint96 unClaimed = 0; // ?

        // начисление токенов если есть
        //claim(tokenId);

        // создание эйрдропа
        /*IWmcVesting(TOKEN).airdrop(
            0,
            0,
            ownership.owner,
            vestedAmount - claimed - unClaimed
        );*/

        // Update statistics
        //vestingStats.total -= vestedAmount;
        //vestingStats.claimed -= claimed;
        _burn(tokenId, true);
    }

    function setDescriptor(address descriptor_) external onlyOwner {
        _descriptor = descriptor_;
    }

    // Metadata
    function contractURI() external view returns (string memory) {
        return INftDescriptor(_descriptor).contractURI();
    }

    /**
     * @dev Unset OpenSea ProxyRegistry. When threatened by OpenSea.
     */
    function unsetProxyRegistry() external onlyOwner {
        _proxyRegistry = address(0);
    }

    // The following functions are overrides required by Solidity.
    function tokenURI(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        return INftDescriptor(_descriptor).tokenURI(tokenId);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (
            _proxyRegistry != address(0) &&
            address(ProxyRegistry(_proxyRegistry).proxies(owner)) == operator
        ) return true;
        return super.isApprovedForAll(owner, operator);
    }

    function _getRecoverableAmount(address token)
        internal
        view
        override
        returns (uint256)
    {
        if (token == address(0)) return 0;
        else if (token == TOKEN)
            return
                IERC20(token).balanceOf(address(this)) -
                (vestingStats.total - vestingStats.claimed);
        else return IERC20(token).balanceOf(address(this));
    }
}
