// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TEST
import "./TestStaking2.sol";

contract Presale is Ownable {

  using SafeMath for uint;

  // StakingContract Struct
  struct UserStaking {
    uint stakedAmount;
  }

  bool public saleStart;
  uint public saleEnd;
  StakingTest public staking;
  ERC721 public immutable crushGod;
  ERC20 public niceToken;
  uint public constant saleDuration = 100;//129600; // Duration in Blocks ( 3 blocks per second ) 12 hours



  // EVENTS
  event UpdateSaleStatus(bool status);

  constructor( address crushGodNft, address stakingV2 ){
    crushGod = ERC721(crushGodNft);
    staking = StakingTest(stakingV2);
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
      UserStaking memory staked = staking.stakings(msg.sender);
      _isQualified = 
        crushGod.ownerOf(tokenId) == msg.sender 
        && 
        staked.stakedAmount >= 10000 ether;
    }
  }

}