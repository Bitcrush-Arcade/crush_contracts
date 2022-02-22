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

contract PrevSale is Ownable, ReentrancyGuard {

  using SafeMath for uint;
  using SafeERC20 for ERC20;

  uint public constant DIVISOR = 10000;

  struct Buy { 
    uint amountBought;
    uint amountClaimed;
    uint amountOwed;
  }

  uint public constant saleStart = 1645401600;
  uint public constant saleEnd = 1645660800;
  uint public constant vestingDuration = 2 weeks;
  StakingTest public immutable staking;
  ERC721 public immutable crushGod;
  NICEToken public niceToken;
  ERC20 public immutable busd;
  uint public totalSale = 26595745 ether;
  uint public constant vesting = 2500;
  uint public priceDec = 10000;
  uint public pricePerToken = 47;
  uint public maxRaise =  125000 ether;
  uint public totalRaised;

  address public immutable devAddress;

  mapping(address => uint) public whitelist;
  mapping(uint => address) public nftUsed;
  mapping(address => Buy) public userBought;

  // EVENTS
  event WhitelistStarted(bool status);
  event SaleStarts(uint startBlock);
  event NiceBought(address indexed buyer, uint busd, uint nice);
  event NiceClaimed( address indexed buyer, uint amount);
  event LogEvent(uint data1, string data2);

  constructor( address crushGodNft, address stakingV2, address _busd ){
    crushGod = ERC721(crushGodNft);
    staking = StakingTest(stakingV2);
    busd = ERC20(_busd);
    devAddress = 0xADdb2B59d1B782e8392Ee03d7E2cEaA240e7f1c0;
  }
  /// @notice qualify only checks quantity
  /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
  function qualify() public view returns(bool _isQualified){
      (,uint staked,,,,,,,) = staking.stakings(msg.sender);
      uint nfts = crushGod.balanceOf(msg.sender);
      _isQualified = nfts > 0 && staked >= 10000 ether;
  }
  /// @notice user will need to self whitelist prior to the sale
  /// @param tokenId the NFT Id to register with
  /// @dev once whitelisted, the token locked to that wallet.
  function whitelistSelf(uint tokenId) public {
    bool isQualified = qualify();
    require(isQualified, "Unqualified");
    require(whitelist[msg.sender] == 0, "Already whitelisted");
    require(nftUsed[tokenId] == address(0), "Token already used");
    require(crushGod.ownerOf(tokenId) == msg.sender, "Illegal owner");
    whitelist[msg.sender] = tokenId;
    nftUsed[tokenId] = msg.sender;
  }

  function setNiceToken(address _tokenAddress) onlyOwner external {
    require(address(niceToken) == address(0), "$NICE already set");
    niceToken = NICEToken(_tokenAddress);
  }
  /// @notice Reserve NICE allocation with BUSD
  /// @param _amount Amount of BUSD to lock NICE amount
  /// @dev minimum of $100 BUSD, max of $5K BUSD
  /// @dev if maxRaise is exceeded we will allocate just a portion of that amount.
  function buyNice(uint _amount) external nonReentrant{
    require(_amount.mod(1 ether) == 0, "Exact amounts only");
    require(whitelist[msg.sender]  > 0, "Whitelist only");
    require(block.timestamp < saleEnd, "SaleEnded");
    require(_amount >= 100 ether, "Minimum not met");
    Buy storage userInfo = userBought[msg.sender];
    require(_amount <= 5000 ether && _amount.add(userInfo.amountBought) <= 5000 ether, "Cap overflow");
    require(totalRaised < maxRaise, "Limit Exceeded");
    uint amount = _amount;
    // When exceeding, send the rest to the user
    if(totalRaised.add(amount) > maxRaise){
      amount = maxRaise.sub(totalRaised);
    }

    busd.safeTransferFrom(msg.sender, address(this), amount);
    userInfo.amountOwed = userInfo.amountOwed.add( amount.mul(priceDec).div(pricePerToken) );
    userInfo.amountBought = userInfo.amountBought.add( amount );
    totalRaised = totalRaised.add(amount);

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
    Buy storage userInfo = userBought[msg.sender];
    require(saleEnd > 0 && block.timestamp > saleEnd.add(vestingDuration), "Claim Unavailable");
    require( address(niceToken) != address(0), "Token Not added");
    uint claimable = availableAmount();
    require( userInfo.amountClaimed < claimable, "Already claimed");
    // Make sure we're not claiming more than available
    claimable = claimable.sub(userInfo.amountClaimed);
    userInfo.amountClaimed = userInfo.amountClaimed.add(claimable);
    claimable = userInfo.amountOwed.mul(claimable).div(DIVISOR);
    niceToken.mint(msg.sender,claimable);
    emit NiceClaimed(msg.sender, claimable);
  }

  /// @notice get claimable percentage after sale end
  /// @return _avail percentage available to claim
  /// @dev this function checks if time has passed to set the max amount claimable
  function availableAmount() public view returns(uint _avail) {
    if(saleEnd > 0 && block.timestamp > saleEnd){
      if(block.timestamp > saleEnd.add(vestingDuration))
        _avail = _avail.add(vesting);
      if(block.timestamp > saleEnd.add(vestingDuration.mul(2)))
        _avail = _avail.add(vesting);
      if(block.timestamp > saleEnd.add(vestingDuration.mul(3)))
        _avail = _avail.add(vesting);
      if(block.timestamp > saleEnd.add(vestingDuration.mul(4)))
        _avail = _avail.add(vesting);
    }
  }
}