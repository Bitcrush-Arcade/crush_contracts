//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//BSC Address: 0x87F8e8f9616689808176d3a97a506c8cEeD32674

// openzeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// bitcrush
import "./NICEToken.sol";
import "./TestStaking2.sol";
import "./PrevSale.sol";
import "interfaces/IPresale.sol";

contract Presale is Ownable, ReentrancyGuard, IPresale {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    struct Buy {
        uint256 amountBought;
        uint256 amountClaimed;
        uint256 amountOwed;
    }

    uint256 public constant saleStart = 1645401600;
    StakingTest public immutable staking;
    NICEToken public niceToken;
    ERC20 public immutable busd;
    uint256 public totalSale = 26595745 ether;
    uint256 public constant vesting = 2500;
    uint256 public priceDec = 10000;
    uint256 public pricePerToken = 47;
    uint256 public maxRaise = 125000 ether;
    uint256 public currentRaised;
    bool public pause;

    address public immutable devAddress;

    PrevSale public prevSale;

    mapping(address => uint256) public whitelist;
    mapping(address => Buy) public userBought;

    // EVENTS
    event WhitelistStarted(bool status);
    event SaleStarts(uint256 startBlock);
    event NiceBought(address indexed buyer, uint256 busd, uint256 nice);
    event NiceClaimed(address indexed buyer, uint256 amount);
    event LogEvent(uint256 data1, string data2);

    constructor(address _prevSale) {
        prevSale = PrevSale(_prevSale);
        staking = prevSale.staking();
        busd = prevSale.busd();
        devAddress = 0xADdb2B59d1B782e8392Ee03d7E2cEaA240e7f1c0;
        pause = false;
    }

    /// @notice pause the presale
    function pauseSale() external onlyOwner {
        pause = true;
    }

    /// @notice qualify only checks quantity
    /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
    function qualify() public view override returns (bool _isQualified) {
        (, uint256 staked, , , , , , , ) = staking.stakings(msg.sender);
        _isQualified = staked >= 10000 ether;
    }

    function setNiceToken(address _tokenAddress) external onlyOwner {
        require(address(niceToken) == address(0), "$NICE already set");
        niceToken = NICEToken(_tokenAddress);
    }

    /// @notice get the total Raised amount
    function totalRaised() public view override returns (uint256 _total) {
        _total = prevSale.totalRaised() + currentRaised;
    }

    /// @notice User info
    function userData()
        public
        view
        override
        returns (
            uint256 _totalBought,
            uint256 _totalOwed,
            uint256 _totalClaimed
        )
    {
        (uint256 prevBuy, , uint256 prevOwed) = prevSale.userBought(msg.sender);
        Buy storage userInfo = userBought[msg.sender];
        _totalBought = userInfo.amountBought + prevBuy;
        _totalOwed = userInfo.amountOwed + prevOwed;
        _totalClaimed = userInfo.amountClaimed;
    }

    /// @notice Reserve NICE allocation with BUSD
    /// @param _amount Amount of BUSD to lock NICE amount
    /// @dev minimum of $100 BUSD, max of $5K BUSD
    /// @dev if maxRaise is exceeded we will allocate just a portion of that amount.
    function buyNice(uint256 _amount) external override nonReentrant {
        require(!pause, "Presale Over");
        require(_amount.mod(1 ether) == 0, "Exact amounts only");
        require(_amount >= 100 ether, "Minimum not met");
        (uint256 prevBought, , ) = prevSale.userBought(msg.sender);
        Buy storage userInfo = userBought[msg.sender];
        require(
            _amount <= 5000 ether &&
                _amount.add(prevBought).add(userInfo.amountBought) <=
                5000 ether,
            "Cap overflow"
        );
        uint256 totalRaise = totalRaised();
        require(totalRaise < maxRaise, "Limit Exceeded");
        uint256 amount = _amount;
        // When exceeding, send the rest to the user
        if (totalRaise.add(amount) > maxRaise) {
            amount = maxRaise.sub(totalRaise);
        }

        busd.safeTransferFrom(msg.sender, address(this), amount);
        userInfo.amountOwed = userInfo.amountOwed.add(
            amount.mul(priceDec).div(pricePerToken)
        );
        userInfo.amountBought = userInfo.amountBought.add(amount);
        currentRaised = currentRaised.add(amount);

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
        require(pause, "Sale Running");
        require(address(niceToken) != address(0), "Token Not added");
        (, uint256 claimed, uint256 owed) = userData();
        Buy storage userInfo = userBought[msg.sender];
        require(claimed == 0, "Already claimed");
        userInfo.amountClaimed = 1;
        niceToken.mint(msg.sender, owed);
        emit NiceClaimed(msg.sender, owed);
    }
}
