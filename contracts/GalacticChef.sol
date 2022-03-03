// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NiceToken.sol";
import "./IFeeDistributor.sol";

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
    bool isLP;
  }
  /// Timestamp Specific
  uint constant SECONDS_PER_DAY = 24 * 60 * 60;
  uint constant SECONDS_PER_HOUR = 60 * 60;
  uint constant SECONDS_PER_MINUTE = 60;
  int constant OFFSET19700101 = 2440588;
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
  uint public immutable initMax; // First year only
  uint public immutable nextMax; // Subsequent Years
  /*
  ** Reward Calculation:
  ** Fixed Pool Rewards = Emission*allocation / PERCENT
  ** Regular Pool Rewards = Emission*( 1e12 - fixedAlloc*1e12/PERCENT) * allocation/regularAlloc / 1e12 
  ** 1e12 is used to cover for fraction issues
  */
  uint public poolCounter;

  // Reward Token
  NiceToken public NICE;

  // FEE distribution
  IFeeDistributor public feeDistributor;

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

  constructor(address _niceToken, uint _maxEmission, uint _nextEmission,uint _chains){
    NICE = NiceToken(_niceToken);
    feeAddress = msg.sender;
    initMax = _maxEmission ; // 20
    nextMax = _nextEmission; // 10
    chains = _chains;
  }
  /// @notice Add Farm of a specific token
  /// @param _token the token that will be collected, Taken as address since ThirdParty pools will handle their own logic
  /// @param _mult the multiplier the pool will have
  /// @param _fee the fee to deposit on the pool
  /// @param _isLP is the token an LP token
  /// @param _type is it a regular pool or a third party pool ( TRUE = ThirdParty )
  /// @param _pidEdit is it a regular pool or a third party pool ( TRUE = ThirdParty )
  /// @param _pidMulEdit is it a regular pool or a third party pool ( TRUE = ThirdParty )
  function addPool(
    address _token,
    uint _mult,
    bool _type,
    uint _fee,
    bool _isLP,
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
    poolInfo[poolCounter] = PoolInfo(_type, _mult, _fee, IERC20(_token), 0, block.timestamp, _isLP);
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
  /// @param _pid Pool Id to update the accumulated rewards 
  function updatePool(uint _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    uint selfBal = pool.token.balanceOf(address(this));
    if(pool.mult == 0 || selfBal == 0 || block.timestamp <= pool.lastRewardTs){
      pool.lastRewardTs = block.timestamp;
      return;
    }
    uint maxMultiplier = currentMax * selfBal;
    uint periodReward = getTimeEmissions(pool) * pool.mult / maxMultiplier;
    pool.lastRewardTs = block.timestamp;
    pool.accRewardPerShare = pool.accRewardPerShare + periodReward;
  }

  /// @notice getCurrentEmissions allows external users to get the current reward emissions
  /// It Uses getTimeEmissions to get the current emissions for the pool between last reward emission and current emission
  /// @param _pid Pool Id  from which we need emissions calculated
  /// @return _emissions emissions for the given pool between 
  function getCurrentEmissions(uint _pid) public view returns (uint _emissions){
    PoolInfo storage pool = poolInfo[_pid];
    if(address(pool.token) == address(0) || pool.mult == 0)
      return 0;
    _emissions = getTimeEmissions(pool);
  }

  /// @notice getCurrentEmissions calculates the current rewards between last reward emission and current emission timestamps
  /// The function takes into account if that period is within the same year or it spans across two different years, since the emission rate changes yearly
  /// @param _pool Pool Id  from which we need emissions calculated
  /// @return _emissions reward token emissions calculated between the last reward emission and the current emission 
  function getTimeEmissions(PoolInfo storage _pool) internal view returns (uint _emissions){
    (uint currentYear,,) = timestampToDateTime(block.timestamp);
    (uint poolYear,,) = timestampToDateTime(_pool.lastRewardTs);
    uint divPool;
    uint yearDiff = currentYear - poolYear;
    uint maxEmissions = poolYear > 2022 ? nextMax : initMax;
    if(poolYear > 2026)
      return 0;
    
    divPool = poolYear <= 2023 ? 1 : (2 ** (poolYear - 2023));

    if(yearDiff > 0){
      //LAST YEAR EMISSIONS
      uint timeDiff = timestampFromDateTime(currentYear,1,1,0,0,0) - _pool.lastRewardTs;
      _emissions += maxEmissions * timeDiff * PERCENT / (chains * divPool);
      // NEW YEAR NEW EMISSIONS
      if( maxEmissions != nextMax )
        maxEmissions = nextMax;
      divPool = currentYear == 2023 ? 1 : (2 ** (currentYear - 2023));
      timeDiff = currentYear > 2026 ? 0 : block.timestamp - timestampFromDateTime(currentYear,1,1,0,0,0);
      _emissions += maxEmissions * timeDiff * PERCENT / (chains * divPool);
    }
    else{
      _emissions = maxEmissions * (block.timestamp - _pool.lastRewardTs) * PERCENT / ( chains * divPool);
    }
  }

  /// @notice Update all pools accPerShare
  /// @dev this might be expensive to call...
  function massUpdatePools() public {
    for(uint id = 1; id <= poolCounter; id ++){
      emit LogEvent(id, "pool update");
      if(poolInfo[id].mult == 0)
        continue; 
      if(!poolInfo[id].poolType)
        updatePool(id);
      else
        _mintRewards(id);
    }
  }

  /// @notice This is for Third party pools only. This handles the reward. 
  /// @param _pid ID of the third party pool that requests minted rewards 
  /// @return _rewardsGiven Amount of rewards minted to the third party pool 
  function mintRewards(uint _pid) external nonReentrant returns(uint _rewardsGiven){
    PoolInfo storage pool = poolInfo[_pid];
    require(pool.poolType && tpPools[_pid] == msg.sender, "Not tp pool");
    _rewardsGiven =_mintRewards(_pid);
  }

  /// @notice Internal function that Mints the amount of rewards calculated between last emission and current emission
  /// @param _pid ID of the third party pool that requests minted rewards 
  /// @return _minted Amount of rewards minted to the pool 
  function _mintRewards(uint _pid) internal returns(uint _minted){
    PoolInfo storage pool = poolInfo[_pid];
    if(block.timestamp <= pool.lastRewardTs)
      return 0;
    _minted = getTimeEmissions(pool) * pool.mult / (currentMax * PERCENT);
    pool.lastRewardTs = block.timestamp;
    NICE.mint(address(pool.token), _minted);
  }

  /// @notice Allows user to deposit pool token to chef. Transfers rewards to user.
  /// @param _amount Amount of pool tokens to stake 
  /// @param _pid Pool ID which indicates the type of token  
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
        if(address(feeDistributor) == address(0))
          pool.token.safeTransferFrom(address(msg.sender), feeAddress, usedAmount);
        else{
          pool.token.approve(address(feeDistributor), usedAmount);
          try feeDistributor.receiveFees(_pid, usedAmount){
            emit LogEvent(usedAmount, "Success Fee Distribution");
          }
          catch{
            emit LogEvent(usedAmount, "Failed Fee Distribution");
            pool.token.safeTransferFrom(address(msg.sender), feeAddress, usedAmount);
            pool.token.approve(address(feeDistributor),0);
          }
        }
        usedAmount = _amount - usedAmount;
      }
      user.amount = user.amount + usedAmount;
      pool.token.safeTransferFrom(address(msg.sender), address(this), usedAmount);
    }
    user.accClaim = user.amount * pool.accRewardPerShare / PERCENT;
    emit Deposit(msg.sender, _pid, _amount);
  }

  /// @notice Withdraws pool token from chef. Transfers rewards to user. 
  /// @param _amount Amount of pool tokens to withdraw. 
  /// @param _pid Pool ID which indicates the type of token 
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

  /// @notice Emergency withdraws all the pool tokens from chef. In this case there's no reward. 
  /// @param _pid Pool ID which indicates the type of token
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

  /// @notice Edits the pool multiplier and updates pools with new params
  /// @param _pidEdit Pool ID
  /// @param _pidMulEdit New multiplier
  function editPoolMult(
    uint[] calldata _pidEdit,
    uint[] calldata _pidMulEdit
  ) external onlyOwner{
    updateMultipliers(_pidEdit, _pidMulEdit);
    emit UpdatePools(_pidEdit, _pidMulEdit);
  }
  
  /// @notice Edits pool fee and updates pools with new params
  /// @param _pid Pool Id
  /// @param _fee New pool fee
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

  /// @notice Adds 1 to the amount of chains to which emissions are split
  /// This factor is used in the emissions calculation
  function addChain() external onlyOwner{
    massUpdatePools();
    chains = chains + 1;
  }

  /// @notice Converts timestamp to date time
  /// @param year Year
  /// @param month Month
  /// @param day Day 
  function timestampToDateTime(uint timestamp) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
  }

  /// @notice Converts date time into timestamp 
  /// @param year Year
  /// @param month Month
  /// @param day Day
  /// @param hour Hour
  /// @param minute Minute
  /// @param second Second
  function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
      timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
  }


  // -------------------------------------------------------------------`
  // Timestamp fns taken from BokkyPooBah's DateTime Library
  //
  // Gas efficient Solidity date and time library
  //
  // https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
  //
  // Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018.
  //
  // GNU Lesser General Public License 3.0
  // https://www.gnu.org/licenses/lgpl-3.0.en.html
  // ---------------------------------------------------------------------------- 

  /// @notice converts days to date
  /// @param _days amount of days 
  /// @return year
  /// @return month
  /// @return day 
  function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
      int __days = int(_days);

      int L = __days + 68569 + OFFSET19700101;
      int N = 4 * L / 146097;
      L = L - (146097 * N + 3) / 4;
      int _year = 4000 * (L + 1) / 1461001;
      L = L - 1461 * _year / 4 + 31;
      int _month = 80 * L / 2447;
      int _day = L - 2447 * _month / 80;
      L = _month / 11;
      _month = _month + 2 - 12 * L;
      _year = 100 * (N - 49) + _year + L;

      year = uint(_year);
      month = uint(_month);
      day = uint(_day);
  }

  /// @notice converts days to date
  /// @param year Year
  /// @param month Month
  /// @param day Day
  /// @return _days Days
  function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
      require(year >= 1970);
      int _year = int(year);
      int _month = int(month);
      int _day = int(day);

      int __days = _day
        - 32075
        + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
        + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
        - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
        - OFFSET19700101;

      _days = uint(__days);
  }

}