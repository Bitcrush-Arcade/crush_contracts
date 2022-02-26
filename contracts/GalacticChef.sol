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
  uint constant year1 = 1640995200;
  uint constant year2 = 1672531200;
  uint constant year3 = 1704067200;
  uint constant year4 = 1735689600;
  uint constant year5 = 1767225600;
  uint constant year6 = 1798761600;

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
  event UpdatePools( uint[] pid, uint[] mult );
  event UpdatePool( uint indexed pid, uint mult, uint fee);
  event UpdateEmissions(uint amount);

  event LogEvent(uint number, string data);

  constructor(address _niceToken, uint _maxEmission, uint _chains){
    NICE = NiceToken(_niceToken);
    feeAddress = msg.sender;
    maxEmissions = _maxEmission ;
    chains = _chains;
  }
  /// @notice Add Farm of a specific token
  /// @param _token the token that will be collected, Taken as address since ThirdParty pools will handle their own logic
  /// @param _mult the multiplier the pool will have
  /// @param _fee the fee to deposit on the pool
  /// @param _type is it a regular pool or a third party pool ( TRUE = ThirdParty )
  /// @param _pidEdit is it a regular pool or a third party pool ( TRUE = ThirdParty )
  /// @param _pidMulEdit is it a regular pool or a third party pool ( TRUE = ThirdParty )
  function addPool(
    address _token,
    uint _mult,
    uint _fee,
    bool _type,
    uint[] calldata _pidEdit,
    uint[] calldata _pidMulEdit
  ) external onlyOwner {
    require( _pidEdit.length == _pidMulEdit.length, "add: wrong edits");
    require( _fee < 5001, "add: invalid fee");
    require( tokenPools[_token] == 0, "add: token repeated");
    //update multipliers and current Max
    updateMultipliers(_pidEdit, _pidMulEdit);
    require(currentMax + _mult <= maxMult, "add: wrong multiplier");
    currentMax = currentMax + _mult;
    poolCounter ++;
    poolInfo[poolCounter] = PoolInfo(_type, _mult, _fee, IERC20(_token), 0, block.timestamp);
    tokenPools[_token] = poolCounter;
    if(_type)
      tpPools[poolCounter] = _token;
    emit PoolAdded(_token, _mult, _fee, _type, poolCounter);
  }
  // Make sure multipliers match
  /// @notice update the multipliers used
  /// @param _pidEdit pool Id Array
  /// @param _pidMulEdit multipliers edit array
  /// @dev both param arrays must have matching lengths
  function updateMultipliers(uint[] calldata _pidEdit, uint[] calldata _pidMulEdit) internal {
    if(_pidEdit.length == 0)
      return;
      // updateValues
    uint newMax = currentMax;
    for(uint i = 0; i < _pidEdit.length; i++){
      require(address(poolInfo[_pidEdit[i]].token) != address(0), "mult: nonexistent pool");
      //Update the pool reward per share before editing the multiplier
      updatePool(_pidEdit[i]);
      newMax = newMax - poolInfo[_pidEdit[i]].mult + _pidMulEdit[i];
      //decrease old val and increase new val
      poolInfo[_pidEdit[i]].mult = _pidMulEdit[i];
    }
    require( newMax <= maxMult, "mult: exceeds max");
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
      uint multiplier = getTimeEmissions(pool) * pool.mult;
      uint maxMultiplier = currentMax * tokenSupply * PERCENT;
      updatedPerShare = updatedPerShare + (multiplier/maxMultiplier);
    }
    _pendingRewards = updatedPerShare * user.amount - user.accClaim;
  }
  /// @notice Update the accRewardPerShare for a specific pool
  /// @param _pid Pool Id to update the accumulated rewards of
  function updatePool(uint _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    uint selfBal = pool.token.balanceOf(address(this));
    if(pool.mult == 0 || selfBal == 0 || block.timestamp <= pool.lastRewardTs)
      return;
    uint maxMultiplier = currentMax * selfBal;
    uint periodReward = getTimeEmissions(pool) * pool.mult / maxMultiplier;
    pool.lastRewardTs = block.timestamp;
    pool.accRewardPerShare = pool.accRewardPerShare + periodReward;
  }

  function getCurrentEmissions(uint _pid) public view returns (uint _emissions){
    PoolInfo storage pool = poolInfo[_pid];
    if(address(pool.token) == address(0) || pool.mult == 0)
      return 0;
    _emissions = getTimeEmissions(pool);
  }

  function getTimeEmissions(PoolInfo storage _pool) internal view returns (uint _emissions){
    uint8 passingYears;
    uint8 poolYears;
    uint[6] memory checkYears = [year1, year2, year3, year4, year5, year6];
    for(uint8 i  = 0; i < checkYears.length; i ++){
        if(block.timestamp >= checkYears[i])
          passingYears ++;
        if(_pool.lastRewardTs >= checkYears[i])
          poolYears ++;
    }
    if(poolYears > 5)
      return 0;
    uint divPassing = passingYears == 1 ? 1 : (2 * (passingYears - 1));
    uint divPool = poolYears == 1 ? 1 : (2 * (poolYears - 1));
    if(passingYears > poolYears){
      uint thisTimeDiff = passingYears > 5 ? 0 : block.timestamp - checkYears[passingYears - 1];
      uint oldTimeDiff = checkYears[passingYears-1] - _pool.lastRewardTs;

      _emissions = maxEmissions * thisTimeDiff * PERCENT / (chains * divPassing);
      _emissions += maxEmissions * oldTimeDiff * PERCENT / (chains * divPool);
    }
    else{
      _emissions = maxEmissions * (block.timestamp - _pool.lastRewardTs) * PERCENT / ( chains * divPool);
    }
  }

  /// @notice Update all pools accPerShare
  /// @dev this might be expensive to call...
  function massUpdatePools() public {
    for(uint id = 1; id <= poolCounter; id ++){
      if(poolInfo[id].mult > 0)
        updatePool(id);
    }
  }

  /// @notice This is for Third party pools only. this handles the reward 
  function mintRewards(uint _pid) external nonReentrant{
    PoolInfo storage pool = poolInfo[_pid];
    require(pool.poolType && tpPools[_pid] == msg.sender, "Not tp pool");
    if(block.timestamp <= pool.lastRewardTs)
      return;
    uint amount = getTimeEmissions(pool) * pool.mult / (currentMax * PERCENT);
    pool.lastRewardTs = block.timestamp;
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
    require(!pool.poolType, "Withdraw: Tp Pool");
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
    uint[] calldata _pidEdit,
    uint[] calldata _pidMulEdit
  ) external onlyOwner{
    updateMultipliers(_pidEdit, _pidMulEdit);
    emit UpdatePools(_pidEdit, _pidMulEdit);
  }

  function editPoolFee(
    uint _pid,
    uint _fee
  ) external onlyOwner{
    PoolInfo storage pool = poolInfo[_pid];
    require(address(pool.token) != address(0), "edit: invalid");
    require( _fee < 2501, "edit: high fee");
    pool.fee = _fee;
    emit UpdatePool(_pid, pool.mult, _fee);
  }

  function addChain() external onlyOwner{
    massUpdatePools();
    chains ++;
  }

}