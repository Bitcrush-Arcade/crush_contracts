// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Presale is Ownable {

  using SafeMath for uint;

  bool public saleStart;
  uint public saleEnd;
  ERC721 public immutable crushGod;
  uint public constant saleDuration = 100;//129600; // Duration in Blocks ( 3 blocks per second ) 12 hours



  // EVENTS
  event UpdateSaleStatus(bool status);

  constructor( address crushGodNft ){
    crushGod = ERC721(crushGodNft);
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
    _isQualified = crushGod.ownerOf(tokenId) == msg.sender;
  }

}