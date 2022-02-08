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

  bool public saleStart;
  uint public saleEnd;
  StakingTest public staking;
  ERC721 public immutable crushGod;
  ERC20 public niceToken;
  ERC20 public usdt;
  ERC20 public busd;
  uint public constant saleDuration = 100;//129600; // Duration in Blocks ( 3 blocks per second ) 12 hours
  uint public totalSale = 26595745 ether;
  uint public available = 25;
  uint public pricePerToken = 4700000 gwei;

  mapping(address => bool) public whitelist;


  // EVENTS
  event UpdateSaleStatus(bool status);

  constructor( address crushGodNft, address stakingV2, address _usdt, address _busd ){
    crushGod = ERC721(crushGodNft);
    staking = StakingTest(stakingV2);
    usdt = ERC20(_usdt);
    busd = ERC20(_busd);
  }

  function toggleSaleStart() external onlyOwner {
    if(!saleStart && saleEnd == 0){
      saleEnd = block.number.add(saleDuration);
    }
    else{
      require(saleStart, "No restart");
      require(saleEnd <= block.number, "Sale running");
    }
    saleStart = !saleStart;
    emit UpdateSaleStatus(saleStart);
  }

  function qualify(uint tokenId) public view returns(bool _isQualified){
    if( address(niceToken) == address(0)){
      _isQualified = false;
    }
    else{
      (uint staked,,,,) = staking.stakings(msg.sender);

      try crushGod.ownerOf(tokenId) returns(address nftOwner){
        _isQualified = 
          nftOwner == msg.sender
          && 
          staked >= 10000 ether;
      }
      catch{
        _isQualified= false;
      }
    }
  }

  function setNiceToken(address _tokenAddress) onlyOwner external {
    require(address(niceToken) == address(0), "$NICE already set");
    niceToken = ERC20(_tokenAddress);
  }

  function buyNice(uint amount, address _tokenAddress, uint nftId) external{

  }

}