// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NiceToken.sol";

contract GalacticChef is Ownable {
  using SafeERC20 for NiceToken;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint amount; //Staked Amount
    uint rewardAcc; //ClaimedReward accumulation
  }

  struct PoolInfo{
    uint8 poolType;
    uint mult;
    IERC20 token;
    uint accRewardPerShare;
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
  uint constant public maxMult = 1000000; // Max Multiplier 100.0000
  uint public currentMax; // The current multiplier total. Always <= maxMult

  // The number of chains where a GalacticChef exists. This helps have a consistent emission across all chains.
  uint public chains;
  // Emissions per second. Since we'll have multiple Chefs across chains the emission set per second
  uint public maxEmissions;

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

  event AddPool(address token, uint multiplier, uint8 _type);

  constructor(address _niceToken){
    NICE = NiceToken(_niceToken);
  }
  /// @notice Add Farm of a specific token
  /// @param _token the token that will be collected, Taken as address since ThirdParty pools will handle their own logic
  /// @param _mult the multiplier the pool will have
  /// @param _type is it a regular pool or a third party pool ( TRUE = ThirdParty )
  function addPool(address _token, uint _mult, bool _type,uint[] calldata _pidEdit, uint[] calldata _pidMulEdit) external onlyOwner returns(uint _pid){
  }
  /// @notice this is for frontend only, calculates the pending reward for a particular user in a specific pool. This does not affect with 
  function pendingRewards(address _user, uint _pid)external {}

  /// @notice This is for Third party pools only. this handles the reward 
  function mintRewards(uint _pid) external{}

  function deposit(uint _amount, uint _pid) external{}

  function withdraw(uint _amount, uint _pid) external{}

  function emergencyWithdraw(uint _amount, uint _pid) external{}

  function editPool(uint _pid, uint _mult, uint[] calldata _pidEdit, uint[] calldata _pidMulEdit ) external onlyOwner{}

}