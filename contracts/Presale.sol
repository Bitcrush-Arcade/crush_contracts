// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// TEST
import "./TestStaking2.sol";

contract Presale is Ownable {

  using SafeMath for uint;
  using SafeERC20 for ERC20;

  uint public constant DIVISOR = 10000;

  struct Buy { 
    uint amountBought;
    uint amountClaimed;
    uint amountOwed;
  }

  uint public saleStart;
  uint public whitelistStart;
  uint public saleEnd;
  StakingTest public staking;
  ERC721 public immutable crushGod;
  ERC20 public niceToken;
  ERC20 public busd;
  uint public constant saleDuration = 100;//12 hours; // Duration in Blocks ( 3 blocks per second ) 12 hours
  uint public totalSale = 26595745 ether;
  uint public available = 2500;
  uint public pricePerToken = 4700000 gwei;
  uint public totalRaise =  125000 ether;

  mapping(address => uint) public whitelist;
  mapping(uint => address) public usedTokens;
  mapping(address => Buy) public userBought;

  // EVENTS
  event WhitelistStarted(bool status);
  event SaleStarts(uint startBlock);
  event LogEvent(uint data1, string data2);

  constructor( address crushGodNft, address stakingV2, address _busd ){
    crushGod = ERC721(crushGodNft);
    staking = StakingTest(stakingV2);
    busd = ERC20(_busd);
  }
  /// @notice start the sale 
  function startSale() external onlyOwner {
    require(saleStart == 0 && saleEnd == 0 && whitelistStart == 0, "Round already started");
    whitelistStart = block.timestamp;
    saleStart = block.timestamp.add(30 minutes);
    saleEnd = block.timestamp.add(saleDuration).add(30 minutes);
    emit SaleStarts(saleStart);
    emit WhitelistStarted(true);
  }
  /// @notice qualify only checks quantity
  /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
  function qualify() public view returns(bool _isQualified){
      (uint staked,,,,) = staking.stakings(msg.sender);
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
    require(usedTokens[tokenId] == address(0), "Token already used");
    require(crushGod.ownerOf(tokenId) == msg.sender, "Illegal owner");
    whitelist[msg.sender] = tokenId;
  }

  function setNiceToken(address _tokenAddress) onlyOwner external {
    require(address(niceToken) == address(0), "$NICE already set");
    niceToken = ERC20(_tokenAddress);
  }

  function buyNice(uint amount, address _tokenAddress, uint nftId) external{
    require(whitelist[msg.sender]  > 0, "Not Whitelisted");
  }

}