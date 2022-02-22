// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NICEToken.sol";
// TEST
import "./TestStaking2.sol";
import "./PrevSale.sol";

contract Presale is Ownable, ReentrancyGuard {

  using SafeMath for uint;
  using SafeERC20 for ERC20;

  struct Buy { 
    uint amountBought;
    uint amountClaimed;
    uint amountOwed;
  }

  uint public constant saleStart = 1645401600;
  StakingTest public immutable staking;
  NICEToken public niceToken;
  ERC20 public immutable busd;
  uint public totalSale = 26595745 ether;
  uint public constant vesting = 2500;
  uint public priceDec = 10000;
  uint public pricePerToken = 47;
  uint public maxRaise =  125000 ether;
  uint public currentRaised;
  bool public pause;

  address public immutable devAddress;

  PrevSale public prevSale;

  mapping(address => uint) public whitelist;
  mapping(address => Buy) public userBought;

  // EVENTS
  event WhitelistStarted(bool status);
  event SaleStarts(uint startBlock);
  event NiceBought(address indexed buyer, uint busd, uint nice);
  event NiceClaimed( address indexed buyer, uint amount);
  event LogEvent(uint data1, string data2);

  constructor( address _prevSale){
    prevSale = PrevSale(_prevSale);
    staking = prevSale.staking();
    busd = prevSale.busd();
    devAddress = 0xADdb2B59d1B782e8392Ee03d7E2cEaA240e7f1c0;
    pause = false;
  }
  /// @notice pause the presale
  function pauseSale() external onlyOwner{
    pause = true;
  }
  /// @notice qualify only checks quantity
  /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
  function qualify() public view returns(bool _isQualified){
      (,uint staked,,,,,,,) = staking.stakings(msg.sender);
      _isQualified = staked >= 10000 ether;
  }

  function setNiceToken(address _tokenAddress) onlyOwner external {
    require(address(niceToken) == address(0), "$NICE already set");
    niceToken = NICEToken(_tokenAddress);
  }
  /// @notice get the total Raised amount
  function totalRaised() public view returns(uint _total){
    _total = prevSale.totalRaised() + currentRaised;
  }
  /// @notice User info
  function userData() public view returns(uint _totalBought, uint _totalOwed, uint _totalClaimed){
    (uint prevBuy,,uint prevOwed) = prevSale.userBought(msg.sender);
    Buy storage userInfo = userBought[msg.sender];
    _totalBought = userInfo.amountBought + prevBuy;
    _totalOwed = userInfo.amountOwed + prevOwed;
    _totalClaimed = userInfo.amountClaimed;

  }
  /// @notice Reserve NICE allocation with BUSD
  /// @param _amount Amount of BUSD to lock NICE amount
  /// @dev minimum of $100 BUSD, max of $5K BUSD
  /// @dev if maxRaise is exceeded we will allocate just a portion of that amount.
  function buyNice(uint _amount) external nonReentrant{
    require(!pause, "Presale Over");
    require(_amount.mod(1 ether) == 0, "Exact amounts only");
    require(_amount >= 100 ether, "Minimum not met");
    (uint prevBought, , ) = prevSale.userBought(msg.sender);
    Buy storage userInfo = userBought[msg.sender];
    require(_amount <= 5000 ether && _amount.add(prevBought).add(userInfo.amountBought) <= 5000 ether, "Cap overflow");
    uint totalRaise = totalRaised();
    require(totalRaise < maxRaise, "Limit Exceeded");
    uint amount = _amount;
    // When exceeding, send the rest to the user
    if(totalRaise.add(amount) > maxRaise){
      amount = maxRaise.sub(totalRaise);
    }

    busd.safeTransferFrom(msg.sender, address(this), amount);
    userInfo.amountOwed = userInfo.amountOwed.add( amount.mul(priceDec).div(pricePerToken) );
    userInfo.amountBought = userInfo.amountBought.add( amount );
    currentRaised = currentRaised.add(amount);

    emit NiceBought(msg.sender, amount, amount.mul(priceDec).div(pricePerToken));
  }
  /// 
  function claimRaised() external onlyOwner{
    uint currentBalance = busd.balanceOf(address(this));
    busd.safeTransfer(devAddress, currentBalance);
  }
  /// @notice function that gets available tokens to the user.
  /// @dev transfers NICE to the user directly by minting straight to their wallets
  function claimTokens() external nonReentrant{
    require(pause, "Sale Running");
    require( address(niceToken) != address(0), "Token Not added");
    (, uint claimed, uint owed) = userData();
    Buy storage userInfo = userBought[msg.sender];
    require( claimed == 0 , "Already claimed");
    userInfo.amountClaimed = 1;
    niceToken.mint(msg.sender,owed);
    emit NiceClaimed(msg.sender, owed);
  }
}