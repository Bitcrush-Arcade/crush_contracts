// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NiceToken.sol";

contract GalacticChef is Ownable {
  using SafeMath for uint;
  using SafeERC20 for NiceToken;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint amount; //Staked Amount
    uint rewardAcc; //ClaimedReward accumulation
  }

  struct PoolInfo{
    uint8 poolType;
    uint alloc;
    uint fee;
    IERC20 token;
  }
  /*
  ** We have three different types of pools: Regular 0, Fixed 1, Third Party 2
  ** Nice has a fixed emission given per second due to tokenomics
  ** So we decided to give a FIXED percentage reward to some pools
  ** REGULAR pools distribute the remaining reward amongst their allocation
  ** Third Party doesn't keep track of the user's info, but rather only keeps track of the rewards being given.
  */

  uint constant public PERCENT = 1e12; // Divisor for percentage calculations
  uint constant public DIVISOR = 100000; // Divisor for fee percentage

  uint public regularAlloc;
  uint public fixedAlloc;
  /*
  ** Reward Calculation:
  ** Fixed Pool Rewards = Emission*allocation / PERCENT
  ** Regular Pool Rewards = Emission*( 1e12 - fixedAlloc*1e12/PERCENT) * allocation/regularAlloc / 1e12 
  ** 1e12 is used to cover for fraction issues
  */
  uint public poolCounter;

  // Reward Token
  NiceToken public NICE;

  mapping( uint => mapping( address => UserInfo)) public userInfo; // PID => USER_ADDRESS => userInfo
  mapping( uint => PoolInfo) public poolInfo; // PID => PoolInfo
  mapping( uint => address ) public tpPools; //  PID => poolAddress

  event AddPool(address token, uint allocation, uint fee, uint8 _type);

  constructor(address _niceToken){
    NICE = NiceToken(_niceToken);
  }

  function addRegular(IERC20 _token, uint _fee, uint _alloc) external onlyOwner{
    require( _fee < 20000, "add: invalid fee");
    regularAlloc = regularAlloc.add(_alloc);
    poolCounter ++;
    poolInfo[poolCounter] = PoolInfo(0,_alloc,_fee,_token);
    emit AddPool(_token, _alloc, _fee, 0);
  }
}