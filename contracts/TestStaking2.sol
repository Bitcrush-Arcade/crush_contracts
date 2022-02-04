// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingTest {
  ERC20 public token;
  struct staked {
    uint256 stakedAmount;
    uint256 claimedAmount;
    uint256 lastBlockCompounded;
    uint256 lastBlockStaked;
    uint256 index;
  }

  mapping(address => staked) public stakings;

  constructor(address _tokenAddress){
    token = ERC20(_tokenAddress);
  }

  function addFunds(uint _amount) external {
    token.transferFrom(msg.sender, address(this), _amount);
    stakings[msg.sender].stakedAmount = stakings[msg.sender].stakedAmount + _amount;
  }
}