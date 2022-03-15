//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//BSC Address 0x87F8e8f9616689808176d3a97a506c8cEeD32674
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//bitcrush
import "./NICEToken.sol";
import "interfaces/IPrevSale.sol";
// TEST
import "./TestStaking2.sol";

contract PrevSale is Ownable, ReentrancyGuard, IPrevSale {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 public constant DIVISOR = 10000;

    struct Buy {
        uint256 amountBought;
        uint256 amountClaimed;
        uint256 amountOwed;
    }

    uint256 public constant saleStart = 1645401600;
    uint256 public constant saleEnd = 1645660800;
    uint256 public constant vestingDuration = 2 weeks;
    StakingTest public immutable staking;
    ERC721 public immutable crushGod;
    NICEToken public niceToken;
    ERC20 public immutable busd;
    uint256 public totalSale = 26595745 ether;
    uint256 public constant vesting = 2500;
    uint256 public priceDec = 10000;
    uint256 public pricePerToken = 47;
    uint256 public maxRaise = 125000 ether;
    uint256 public totalRaised;

    address public immutable devAddress;

    mapping(address => uint256) public whitelist;
    mapping(uint256 => address) public nftUsed;
    mapping(address => Buy) public userBought;

    // EVENTS
    event WhitelistStarted(bool status);
    event SaleStarts(uint256 startBlock);
    event NiceBought(address indexed buyer, uint256 busd, uint256 nice);
    event NiceClaimed(address indexed buyer, uint256 amount);
    event LogEvent(uint256 data1, string data2);

    constructor(
        address crushGodNft,
        address stakingV2,
        address _busd
    ) {
        crushGod = ERC721(crushGodNft);
        staking = StakingTest(stakingV2);
        busd = ERC20(_busd);
        devAddress = 0xADdb2B59d1B782e8392Ee03d7E2cEaA240e7f1c0;
    }

    /// @notice qualify only checks quantity
    /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
    function qualify() public view override returns (bool _isQualified) {
        (, uint256 staked, , , , , , , ) = staking.stakings(msg.sender);
        uint256 nfts = crushGod.balanceOf(msg.sender);
        _isQualified = nfts > 0 && staked >= 10000 ether;
    }

    /// @notice user will need to self whitelist prior to the sale
    /// @param tokenId the NFT Id to register with
    /// @dev once whitelisted, the token locked to that wallet.
    function whitelistSelf(uint256 tokenId) public override {
        bool isQualified = qualify();
        require(isQualified, "Unqualified");
        require(whitelist[msg.sender] == 0, "Already whitelisted");
        require(nftUsed[tokenId] == address(0), "Token already used");
        require(crushGod.ownerOf(tokenId) == msg.sender, "Illegal owner");
        whitelist[msg.sender] = tokenId;
        nftUsed[tokenId] = msg.sender;
    }

    function setNiceToken(address _tokenAddress) external override onlyOwner {
        require(address(niceToken) == address(0), "$NICE already set");
        niceToken = NICEToken(_tokenAddress);
    }

    /// @notice Reserve NICE allocation with BUSD
    /// @param _amount Amount of BUSD to lock NICE amount
    /// @dev minimum of $100 BUSD, max of $5K BUSD
    /// @dev if maxRaise is exceeded we will allocate just a portion of that amount.
    function buyNice(uint256 _amount) external override nonReentrant {
        require(_amount.mod(1 ether) == 0, "Exact amounts only");
        require(whitelist[msg.sender] > 0, "Whitelist only");
        require(block.timestamp < saleEnd, "SaleEnded");
        require(_amount >= 100 ether, "Minimum not met");
        Buy storage userInfo = userBought[msg.sender];
        require(
            _amount <= 5000 ether &&
                _amount.add(userInfo.amountBought) <= 5000 ether,
            "Cap overflow"
        );
        require(totalRaised < maxRaise, "Limit Exceeded");
        uint256 amount = _amount;
        // When exceeding, send the rest to the user
        if (totalRaised.add(amount) > maxRaise) {
            amount = maxRaise.sub(totalRaised);
        }

        busd.safeTransferFrom(msg.sender, address(this), amount);
        userInfo.amountOwed = userInfo.amountOwed.add(
            amount.mul(priceDec).div(pricePerToken)
        );
        userInfo.amountBought = userInfo.amountBought.add(amount);
        totalRaised = totalRaised.add(amount);

        emit NiceBought(
            msg.sender,
            amount,
            amount.mul(priceDec).div(pricePerToken)
        );
    }

    ///
    function claimRaised() external override onlyOwner {
        uint256 currentBalance = busd.balanceOf(address(this));
        busd.safeTransfer(devAddress, currentBalance);
    }

    /// @notice function that gets available tokens to the user.
    /// @dev transfers NICE to the user directly by minting straight to their wallets
    function claimTokens() external override nonReentrant {
        Buy storage userInfo = userBought[msg.sender];
        require(
            saleEnd > 0 && block.timestamp > saleEnd.add(vestingDuration),
            "Claim Unavailable"
        );
        require(address(niceToken) != address(0), "Token Not added");
        uint256 claimable = availableAmount();
        require(userInfo.amountClaimed < claimable, "Already claimed");
        // Make sure we're not claiming more than available
        claimable = claimable.sub(userInfo.amountClaimed);
        userInfo.amountClaimed = userInfo.amountClaimed.add(claimable);
        claimable = userInfo.amountOwed.mul(claimable).div(DIVISOR);
        niceToken.mint(msg.sender, claimable);
        emit NiceClaimed(msg.sender, claimable);
    }

    /// @notice get claimable percentage after sale end
    /// @return _avail percentage available to claim
    /// @dev this function checks if time has passed to set the max amount claimable
    function availableAmount() public view override returns (uint256 _avail) {
        if (saleEnd > 0 && block.timestamp > saleEnd) {
            if (block.timestamp > saleEnd.add(vestingDuration))
                _avail = _avail.add(vesting);
            if (block.timestamp > saleEnd.add(vestingDuration.mul(2)))
                _avail = _avail.add(vesting);
            if (block.timestamp > saleEnd.add(vestingDuration.mul(3)))
                _avail = _avail.add(vesting);
            if (block.timestamp > saleEnd.add(vestingDuration.mul(4)))
                _avail = _avail.add(vesting);
        }
    }
}
