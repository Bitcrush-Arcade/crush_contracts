// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NiceToken.sol";

contract GalacticChef is Ownable, ReentrancyGuard {
  using SafeERC20 for NiceToken;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint amount; //Staked Amount
    uint accClaim; //ClaimedReward accumulation
  }

  struct PoolInfo{
    bool poolType;
    uint mult;
    uint fee;
    IERC20 token;
    uint accRewardPerShare;
    uint lastRewardTs;
  }
  /*
  ** We have two different types of pools: Regular False, Third True
  ** Nice has a fixed emission given per second due to tokenomics
  ** So we decided to give a FIXED percentage reward to some pools
  ** REGULAR pools distribute the remaining reward amongst their allocation
  ** Third Party doesn't keep track of the user's info, but rather only keeps track of the rewards being given.
  */

  uint constant public PERCENT = 1e12; // Divisor for percentage calculations
  uint constant public FEE_DIV = 10000; // Divisor for fee percentage 100.00
  uint constant public maxMult = 1000000; // Max Multiplier 100.0000
  uint public currentMax; // The current multiplier total. Always <= maxMult
  address public feeAddress; // Address where fees will be sent to for Distribution/Reallocation

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
  mapping( address => uint) public tokenPools; // tokenAddress => poolId

  event PoolAdded(address token, uint multiplier, uint fee, bool _type, uint _pid);
  event Deposit( address indexed user, uint indexed pid, uint amount);
  event Withdraw( address indexed user, uint indexed pid, uint amount);
  event EmergencyWithdraw( address indexed user, uint indexed pid, uint amount);
  event UpdatePool( uint indexed pid, uint mult, uint fee);
  
  constructor(address _niceToken){
    NICE = NiceToken(_niceToken);
    feeAddress = msg.sender;
  }
  /// @notice Add Farm of a specific token
  /// @param _token the token that will be collected, Taken as address since ThirdParty pools will handle their own logic
  /// @param _mult the multiplier the pool will have
  /// @param _fee the fee to deposit on the pool
  /// @param _type is it a regular pool or a third party pool ( TRUE = ThirdParty )
  function addPool(
    address _token,
    uint _mult,
    uint _fee,
    bool _type,
    uint[] calldata _pidEdit,
    uint[] calldata _pidMulEdit
  ) external onlyOwner {
    require( _pidEdit.length == _pidMulEdit.length, "add: wrong edits");
    require( _fee < 5001, "add: check fee");
    require( tokenPools[_token] == 0, "add: token repeated");
    //update multipliers and current Max
    getTotalMultiplier(_pidEdit, _pidMulEdit);
    require(currentMax + _mult <= maxMult, "add: wrong multiplier");
    currentMax = currentMax + _mult;
    poolCounter ++;
    poolInfo[poolCounter] = PoolInfo(_type, _mult, _fee, IERC20(_token), 0, block.timestamp);
    tokenPools[_token] = poolCounter;
    emit PoolAdded(_token, _mult, _fee, _type, poolCounter);
  }
  // Make sure multipliers match
  /// @notice update the multipliers used
  function getTotalMultiplier(uint[] calldata _pidEdit, uint[] calldata _pidMulEdit) internal {
    if(_pidEdit.length == 0)
      return;
      // updateValues
    for(uint i = 0; i < _pidEdit.length; i++){
      poolInfo[_pidEdit[i]].mult = _pidMulEdit[i];
    }
    // calc new multiplier
    uint newMax;
    for(uint i = 1; i <= poolCounter; i++){
      newMax = poolInfo[i].mult + newMax;
    }
    currentMax = newMax;
  }

  /// @notice this is for frontend only, calculates the pending reward for a particular user in a specific pool.
  /// @param _user User to calculate rewards to
  /// @param _pid Pool Id to calculate rewards of
  function pendingRewards(address _user, uint _pid) external view returns(uint _pendingRewards) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    if(user.amount == 0){
      return 0;
    }
    uint updatedPerShare = pool.accRewardPerShare;
    uint tokenSupply = pool.token.balanceOf(address(this));
    if(block.timestamp > pool.lastRewardTs && tokenSupply > 0){
      uint multiplier = maxEmissions * (block.timestamp - pool.lastRewardTs) * PERCENT * pool.mult;
      uint maxMultiplier = (currentMax < maxMult ? currentMax : maxMult) * tokenSupply;
      updatedPerShare = updatedPerShare + (multiplier/maxMultiplier);
    }
    _pendingRewards = (updatedPerShare * user.amount - user.accClaim) / PERCENT;
  }
  /// @notice Update the accRewardPerShare for a specific pool
  /// @param _pid Pool Id to update the accumulated rewards of
  function updatePool(uint _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    uint selfBal = pool.token.balanceOf(address(this));
    if(pool.mult == 0 || selfBal == 0 || block.timestamp <= pool.lastRewardTs)
      return;
    uint maxMultiplier = (currentMax < maxMult ? currentMax : maxMult) * selfBal;
    uint periodReward = maxEmissions * (block.timestamp - pool.lastRewardTs) * PERCENT * pool.mult / maxMultiplier;
    pool.accRewardPerShare = pool.accRewardPerShare + periodReward;
    pool.lastRewardTs = block.timestamp;
  }

  /// @notice This is for Third party pools only. this handles the reward 
  function mintRewards(uint _pid) external nonReentrant{
    PoolInfo storage pool = poolInfo[_pid];
    require(pool.poolType && tpPools[_pid] == msg.sender, "Not tp pool");
    if(block.timestamp <= pool.lastRewardTs)
      return;
    pool.lastRewardTs = block.timestamp;
    uint maxMultiplier = currentMax < maxMult ? currentMax : maxMult;
    uint amount = (block.timestamp - pool.lastRewardTs) * maxEmissions * pool.mult / maxMultiplier;
    NICE.mint(address(pool.token), amount);
  }

  function deposit(uint _amount, uint _pid) external nonReentrant{
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(pool.mult > 0, "Deposit: Pool disabled");
    require(!pool.poolType, "Deposit: Tp Pool");
    updatePool(_pid);
    //Harvest Rewards
    if(user.amount > 0){
      uint pending = (user.amount * pool.accRewardPerShare / PERCENT) - user.accClaim;
      if(pending > 0)
        NICE.mint(msg.sender, pending);
    }
    uint usedAmount = _amount;
    if(usedAmount > 0){
      if(pool.fee > 0){
        usedAmount = usedAmount * pool.fee / FEE_DIV;
        pool.token.safeTransferFrom(address(msg.sender), feeAddress, usedAmount);
        usedAmount = _amount - usedAmount;
      }
      user.amount = user.amount + usedAmount;
      pool.token.safeTransferFrom(address(msg.sender), address(this), usedAmount);
    }
    user.accClaim = user.amount * pool.accRewardPerShare / PERCENT;
    emit Deposit(msg.sender, _pid, _amount);
  }

  function withdraw(uint _amount, uint _pid) external nonReentrant{
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(!pool.poolType, "withdraw: Tp Pool");
    require(user.amount >= _amount, "Withdraw: invalid amount");
    updatePool(_pid);
    uint pending = user.amount * pool.accRewardPerShare / PERCENT - user.accClaim;
    if(pending > 0){
      NICE.mint(msg.sender, pending);
    }
    if(_amount > 0){
      user.amount = user.amount - _amount;
      pool.token.safeTransfer(address(msg.sender), _amount);
    }
    user.accClaim = user.amount * pool.accRewardPerShare / PERCENT;
    emit Withdraw(msg.sender, _pid, _amount);
  }

  function emergencyWithdraw(uint _pid) external nonReentrant{
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(!pool.poolType, "withdraw: Tp Pool");
    require(user.amount > 0, "Withdraw: invalid amount");
    uint _amount = user.amount;
    userInfo[_pid][msg.sender] = UserInfo(0,0);
    pool.token.safeTransfer(address(msg.sender), _amount);
    emit EmergencyWithdraw(msg.sender, _pid, _amount);
  }

  function editPoolMult(
    uint _pid,
    uint _mult,
    uint[] calldata _pidEdit,
    uint[] calldata _pidMulEdit
  ) external onlyOwner{
    PoolInfo storage pool = poolInfo[_pid];
    require(address(pool.token) != address(0), "edit: invalid");
    getTotalMultiplier(_pidEdit, _pidMulEdit);
    require(currentMax + _mult <= maxMult, "edit: wrong multiplier");
    pool.mult = _mult;
    emit UpdatePool(_pid, _mult, pool.fee);
  }
  function editPoolFee(
    uint _pid,
    uint _fee
  ) external onlyOwner{
    PoolInfo storage pool = poolInfo[_pid];
    require(address(pool.token) != address(0), "edit: invalid");
    require( _fee < 2500, "edit: high fee");
    pool.fee = _fee;
    emit UpdatePool(_pid, pool.mult, _fee);
  }

}