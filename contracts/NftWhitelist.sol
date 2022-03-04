// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NftWhitelist is Ownable{

  uint public whitelisters;
  uint public buyers;
  address[] public allWhitelisters;
  mapping(address => uint) public bought;
  mapping(address => bool) public whitelist;
  bool public wlStart;
  bool public wlOver;
  bool public claimed;
  bool public buyersUpdated;
  uint public requiredAmount = 0.1 ether; // 0.1BNB as minimum variable
  address public fundsAddress;

  // EVENTS
  event WhitelistUser(address _user);
  event ChangeRequired(uint _amount);
  event BuyerUpdate(uint added, uint total);
  event BuyersFullyAdded(bool _added);
  event WhitelistOver(bool _isOver);
  event ClaimUsedBnb(uint amount);

  constructor(address payable _fundReceiver){
    fundsAddress = _fundReceiver;
  }

  //UserFunctions
  function reserveSpot() external payable{
    require(!wlOver && wlStart, "Whitelist Over");
    require(!whitelist[msg.sender], "Already whitelisted");
    require(msg.value == requiredAmount, "Check sent eth");
    whitelist[msg.sender] = true;
    allWhitelisters.push(msg.sender);
    whitelisters ++;
    emit WhitelistUser(msg.sender);
  }

  fallback() external payable{
    revert("Keep your money");
  }

  function spotRefund() external {
    require(wlOver && buyersUpdated, "Not done updating buyers");
    require(bought[msg.sender] == 0, "You bought an Emperor");
    require(whitelist[msg.sender], "Not whitelisted");
    require(address(this).balance > requiredAmount, "Insufficient Funds");
    whitelist[msg.sender] = false;
    (bool success,) = msg.sender.call{value: requiredAmount}("");
    require(success, "Failed To refund");
  }

  //OWNER FUNCTIONS
  function updateBuyers(address[] calldata _usersBought, uint[] calldata nftIds) external onlyOwner{
    uint nftsAdded = nftIds.length;
    uint usersBought = _usersBought.length;
    require( nftsAdded == usersBought, "Mismatch ID and Users");
    require(usersBought > 0, "No users added");
    buyers += usersBought;
    uint diff;
    for( uint i = 0; i < usersBought; i++){
      if(bought[ _usersBought[i] ] > 0){
        diff ++;
        continue;
      }
      bought[ _usersBought[i] ] = nftIds[i];
    }
    if(diff > 0)
      buyers -= diff;
    emit BuyerUpdate(usersBought - diff, buyers);
  }

  function whitelistIsOver() external onlyOwner{
    require(!wlOver && wlStart, "Already over");
    wlOver = true;
    emit WhitelistOver(wlOver);
  }
  function allBuyersAdded() external onlyOwner{
    require(!buyersUpdated, "No turning back");
    buyersUpdated = !buyersUpdated;
    emit BuyersFullyAdded(buyersUpdated);

  }

  function setRequiredAmount(uint _newRequired) external onlyOwner{
    require(_newRequired > 0 && !wlStart, "not a giveaway");
    requiredAmount = _newRequired;
    emit ChangeRequired(_newRequired);
  }

  function startWhitelist() external onlyOwner{
    require(!wlStart, "Whitelist started");
    wlStart = true;
  }

  function claimLockedAmount() external onlyOwner{
    require(wlOver && buyersUpdated && !claimed, "Something's missing");
    require(buyers > 0, "No one bought :(");
    claimed = true;
    uint sendAmount = buyers * requiredAmount;
    (bool success,) = payable(fundsAddress).call{value: sendAmount}("");
    require(success, "Couldnt send");
    emit ClaimUsedBnb(sendAmount);
  }

}