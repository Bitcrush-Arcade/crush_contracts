//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "./HouseBankroll.sol";
import "./LiveWallet.sol";
contract BitcrushStaking is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for CRUSHToken;
    uint256 public constant MAX_CRUSH_PER_BLOCK = 10000000000000000000;
    uint256 public constant MAX_FEE = 1000; // 1000/10000 * 100 = 10%
    uint256 public performanceFeeCompounder = 10; // 10/10000 * 100 = 0.1%
    uint256 public performanceFeeBurn       = 100; // 100/10000 * 100 = 1%
    uint256 public constant divisor = 10000;
    
    uint256  public earlyWithdrawFee         = 50; // 50/10000 * 100 = 0.5% 
    uint256  public frozenEarlyWithdrawFee   = 1500; // 50/10000 * 100 = 0.5% 
    uint256  public performanceFeeReserve    = 190; // 190/10000 * 100 = 1.9%
    
    uint256  public frozenEarlyWithdrawFeeTime   = 10800; // 50/10000 * 100 = 0.5% 

    
    uint256 public blockPerSecond = 3;
    uint256 public earlyWithdrawFeeTime = 72 * 60 * 60 / blockPerSecond;
    uint256 public apyBoost = 2500; //2500/10000 * 100 = 25%
    uint256 public totalShares;

    
    //address of the crush token
    CRUSHToken public immutable crush;
    BitcrushBankroll public bankroll;
    BitcrushLiveWallet public liveWallet;
    struct UserStaking {
        uint256 shares;
        uint256 stakedAmount;
        uint256 claimedAmount;
        uint256 profit;
        uint256 lastBlockCompounded;
        uint256 lastBlockStaked;
        uint256 index;
        uint256 lastFrozenWithdraw;
    }
    mapping (address => UserStaking) public stakings;
    address[] public addressIndexes;

    struct profit {
        uint256 total;
        uint256 remaining;
    }
    profit[] public profits;

    uint256 public totalPool;
    uint256 public lastAutoCompoundBlock;
    uint256 public batchStartingIndex = 0;
    
    uint256 public crushPerBlock = 5500000000000000000;
    address public reserveAddress;

    uint256 public totalStaked;
    
    uint256 public totalClaimed;
    uint256 public totalFrozen = 0;
    uint256 public totalProfitDistributed = 0;
    
    uint256 public autoCompoundLimit = 10;

    uint256 public deploymentTimeStamp;
    event RewardPoolUpdated (uint256 indexed _totalPool);
    
    event StakeUpdated (address indexed recipeint, uint256 indexed _amount);
    
    constructor (CRUSHToken _crush, uint256 _crushPerBlock, address _reserveAddress) public{
        crush = _crush;
        if(_crushPerBlock <= MAX_CRUSH_PER_BLOCK){
            crushPerBlock = _crushPerBlock;
        }
    
        reserveAddress = _reserveAddress;
        lastAutoCompoundBlock = 0;
        deploymentTimeStamp = block.timestamp;
        
    }
    /// Store `_bankroll`.
    /// @param _bankroll the new value to store
    /// @dev stores the _bankroll address in the state variable `bankroll`
    function setBankroll (BitcrushBankroll _bankroll) public onlyOwner{
        bankroll = _bankroll;
    }

    /// Store `_liveWallet`.
    /// @param _liveWallet the new value to store
    /// @dev stores the _liveWallet address in the state variable `liveWallet`
    function setLiveWallet (BitcrushLiveWallet _liveWallet) public onlyOwner{
        liveWallet = _liveWallet;
    }

    /// Adds the provided amount to the totalPool
    /// @param _amount the amount to add
    /// @dev adds the provided amount to `totalPool` state variable
    function addRewardToPool (uint256 _amount) public  {
        require(crush.balanceOf(msg.sender) >= _amount, "Insufficient Crush tokens for transfer");
        totalPool = totalPool.add(_amount);
        crush.safeTransferFrom(msg.sender, address(this), _amount);
        emit RewardPoolUpdated(totalPool);
    }

    
    function setCrushPerBlock (uint256 _amount) public onlyOwner {
        require(_amount >= 0, "Crush per Block can not be negative" );
        require(_amount <= MAX_CRUSH_PER_BLOCK, "Crush Per Block can not be more than 10");
        crushPerBlock = _amount;
    }


    /// Stake the provided amount
    /// @param _amount the amount to stake
    /// @dev stakes the provided amount
    function enterStaking (uint256 _amount) public  {
        require(crush.balanceOf(msg.sender) >= _amount, "Insufficient Crush tokens for transfer");
        require(_amount > 0,"Invalid staking amount");
        require(totalPool > 0, "Reward Pool Exhausted");
        
        crush.safeTransferFrom(msg.sender, address(this), _amount);
        if(totalStaked == 0){
            lastAutoCompoundBlock = block.number;
        }
        UserStaking storage user = stakings[msg.sender];

        if(user.stakedAmount == 0){
            user.lastBlockCompounded = block.number;
            addressIndexes.push(msg.sender);
            user.index = addressIndexes.length-1;
        }
        else{
            crush.safeTransfer(msg.sender, getReward(msg.sender));
        }
        
        totalStaked = totalStaked.add(_amount);

        uint256 currentShares = 0;
        if (totalShares != 0) {
            currentShares = _amount.mul(totalShares).div(totalStaked);
        } else {
            currentShares = _amount;
        }
        user.shares = user.shares.add(currentShares);
        totalShares = totalShares.add(currentShares);

        user.stakedAmount = user.stakedAmount.add(_amount);
        
        user.lastBlockStaked = block.number;
        
        user.lastBlockCompounded = block.number;
    }



    /// Leaves staking for a user by the specified amount and transfering staked amount and reward to users address
    /// @param _amount the amount to unstake
    /// @dev leaves staking and deducts total pool by the users reward. early withdrawal fee applied if withdraw is made before earlyWithdrawFeeTime
    function leaveStaking (uint256 _amount, bool _liveWallet) external  {
        uint256 reward = getReward(msg.sender);
        UserStaking storage user = stakings[msg.sender];
        user.lastBlockCompounded = block.number;
        totalPool = totalPool.sub(reward);
        uint256 availableStaked = user.stakedAmount;
        if(totalFrozen > 0){
            availableStaked = availableStaked.sub(totalFrozen.mul(user.stakedAmount).div(totalStaked));
        }else if(user.lastFrozenWithdraw > 0){
            user.lastFrozenWithdraw = 0;
        }
        require(availableStaked >= _amount, "Withdraw amount can not be greater than available staked amount");
        totalStaked = totalStaked.sub(_amount);
        
        uint256 shareReduction = _amount.mul( user.shares ).div( user.stakedAmount );
        user.stakedAmount = user.stakedAmount.sub(_amount);
        user.shares = user.shares.sub( shareReduction );
        totalShares = totalShares.sub( shareReduction );

        if(totalFrozen > 0 ){
            if(user.lastFrozenWithdraw > 0 ) {
                require(block.timestamp > user.lastFrozenWithdraw.add(frozenEarlyWithdrawFeeTime),"Only One Withdraw allowed per 3 hours during freeze");
            }
            uint256 withdrawalFee = _amount.mul(frozenEarlyWithdrawFee).div(divisor);
            user.lastFrozenWithdraw = block.timestamp;
            _amount = _amount.sub(withdrawalFee);
            
            if(withdrawalFee > totalFrozen){
                uint256 remainder = withdrawalFee.sub(totalFrozen);
                crush.approve(address(bankroll), remainder);
                totalFrozen = 0;
            }else {
                totalFrozen = totalFrozen.sub(withdrawalFee);
            }
            
            bankroll.recoverBankroll(withdrawalFee);
            
        }
        else if(block.number < user.lastBlockStaked.add(earlyWithdrawFeeTime)){
            //apply fee
            uint256 withdrawalFee = _amount.mul(earlyWithdrawFee).div(divisor);
            _amount = _amount.sub(withdrawalFee);
            crush.safeTransfer(reserveAddress, withdrawalFee);
        }
        _amount = _amount.add(reward);
        if(_liveWallet == false){
            crush.safeTransfer(msg.sender, _amount);
        }else {
            crush.approve(address(liveWallet), _amount);
            liveWallet.addbetWithAddress(_amount, msg.sender);
        }
        
        //remove from array
        if(user.stakedAmount == 0){
            if(user.index != addressIndexes.length-1){
                address lastAddress = addressIndexes[addressIndexes.length-1];
                addressIndexes[user.index] = lastAddress;
                stakings[lastAddress].index = user.index;
            }
            addressIndexes.pop();
        }
        emit RewardPoolUpdated(totalPool);
    }


    function getReward(address _address) internal view returns (uint256) {
        UserStaking storage user = stakings[_address];
        if(block.number <= user.lastBlockCompounded || totalPool == 0 || totalStaked ==0){
            return 0;
        }
        //if the staker reward is greater than total pool => set it to total pool
        uint256 blocks = block.number.sub(user.lastBlockCompounded);
        uint256 totalReward;
        if(totalFrozen > 0){
            totalReward = blocks.mul(crushPerBlock.add(crushPerBlock.mul(apyBoost).div(divisor)));
        }else {
            totalReward = blocks.mul(crushPerBlock);
        }
        uint256 stakerReward = totalReward.mul(user.shares).div(totalShares);
        if(stakerReward > totalPool){
            stakerReward = totalPool;
        }
        return stakerReward;
    }

    /// Calculates total potential pending rewards
    /// @dev Calculates potential reward based on crush per block
    function totalPendingRewards () public view returns (uint256){
            if(block.number <= lastAutoCompoundBlock){
                return 0;
            }else if(lastAutoCompoundBlock == 0){
                return 0;
            }else if (totalPool == 0){
                return 0;
            }

            uint256 blocks = block.number.sub(lastAutoCompoundBlock);
            uint256 totalReward = blocks.mul(crushPerBlock);

            return totalReward;
    }

    /// Get pending rewards of a user
    /// @param _address the address to calculate the reward for
    /// @dev calculates potential reward for the address provided based on crush per block
    function pendingReward (address _address) external view returns (uint256){
        return getReward(_address);
    }

   

    /// compounds the rewards of all users in the pool
    /// @dev compounds the rewards of all users in the pool add adds it into their staked amount while deducting fees
    function compoundAll () public  {
        require(lastAutoCompoundBlock <= block.number, "Compound All not yet applicable.");
        require(totalStaked > 0, "No Staked rewards to claim" );
        uint256 crushToBurn = 0;
        uint256 performanceFee = 0;
        
        uint256 compounderReward = 0;
        uint totalPoolDeducted = 0;
        
        uint256 batchLimit = addressIndexes.length;
        if(addressIndexes.length <= autoCompoundLimit || batchStartingIndex.add(autoCompoundLimit) >= addressIndexes.length){
            batchLimit = addressIndexes.length;
        }else {
            batchLimit = batchStartingIndex.add(autoCompoundLimit);
        }
        uint256 newProfit = bankroll.transferProfit();
        if(newProfit > 0){
            //profit deduction
            profit memory prof = profit(newProfit,newProfit);
            profits.push(prof);
            totalProfitDistributed = totalProfitDistributed.add(newProfit);
        }
        if(batchStartingIndex == 0){
            if(profits.length > 1){
                profits[profits.length - 1].total = profits[profits.length - 1].total.add(profits[0].remaining); 
                profits[profits.length - 1].remaining = profits[profits.length - 1].total;
                profits[0] = profits[profits.length - 1];
                profits.pop();
            }
        }

        for(uint256 i=batchStartingIndex; i < batchLimit; i++){
            uint256 stakerReward = getReward(addressIndexes[i]);
            UserStaking storage currentUser = stakings[addressIndexes[i]];
            if(stakerReward > 0){
                totalClaimed = totalClaimed.add(stakerReward);
                totalPoolDeducted = totalPoolDeducted.add(stakerReward);
            }
            if(profits.length > 0){
                if(profits[0].remaining > 0){
                    uint256 profitShareUser =0;
                    profitShareUser = profits[0].total.mul( currentUser.shares).div(totalShares);
                    if(profitShareUser > profits[0].remaining){
                        profitShareUser = profits[0].remaining;
                    }
                    profits[0].remaining = profits[0].remaining.sub(profitShareUser);
                    if(profits[0].remaining <= 5){
                       totalPool = totalPool.add(profits[0].remaining); 
                       profits[0].remaining = 0;
                    }
                    stakerReward = stakerReward.add(profitShareUser); 
                }
            }
            if(stakerReward > 0){
                uint256 stakerBurn = stakerReward.mul(performanceFeeBurn).div(divisor);
                crushToBurn = crushToBurn.add(stakerBurn);
            
                uint256 cpAllReward = stakerReward.mul(performanceFeeCompounder).div(divisor);
                compounderReward = compounderReward.add(cpAllReward);
            
                uint256 feeReserve = stakerReward.mul(performanceFeeReserve).div(divisor);
                performanceFee = performanceFee.add(feeReserve);
                stakerReward = stakerReward.sub(stakerBurn);
                stakerReward = stakerReward.sub(cpAllReward);
                stakerReward = stakerReward.sub(feeReserve);
                currentUser.claimedAmount = currentUser.claimedAmount.add(stakerReward);
                currentUser.stakedAmount = currentUser.stakedAmount.add(stakerReward);
                
                uint256 rewardShares = stakerReward.mul(totalShares).div(totalStaked);
                totalShares = totalShares.add( rewardShares );
                currentUser.shares = currentUser.shares.add(rewardShares);
            }    
            currentUser.lastBlockCompounded = block.number;
            batchStartingIndex = batchStartingIndex.add(1);
                        
        }
        if(batchStartingIndex >= addressIndexes.length){
            batchStartingIndex = 0;
        }
        totalPool = totalPool.sub(totalPoolDeducted);
        lastAutoCompoundBlock = block.number;
        crush.burn(crushToBurn);
        crush.safeTransfer(msg.sender, compounderReward);
        crush.safeTransfer(reserveAddress, performanceFee);
        
    }

    /// freeze certain funds in the staking pool and transfer them to the live wallet address
    /// @dev adds the provided amount to the total frozen variablle
    function freezeStaking (uint256 _amount, address _recipient, address _lwAddress) public  {
        require(msg.sender == address(bankroll), "Callet must be bankroll");
        //divide amount over users
        //update user mapping to reflect frozen amount
         require(_amount <= totalStaked.sub(totalFrozen), "Freeze amount should be less than or equal to available funds");
         totalFrozen = totalFrozen.add(_amount);
         BitcrushLiveWallet currentLw = BitcrushLiveWallet(_lwAddress);
         currentLw.addToUserWinnings(_amount, _recipient);
         crush.safeTransfer(address(_lwAddress), _amount);
    }
    
    /// unfreeze previously frozen funds from the staking pool
    /// @dev deducts the provided amount from the total frozen variablle
    function unfreezeStaking (uint256 _amount) public {
        require(msg.sender == address(bankroll), "Callet must be bankroll");
       //divide amount over users
        //update user mapping to reflect deducted frozen amount
         require(_amount <= totalFrozen, "unfreeze amount cant be greater than currently frozen amount");
         totalFrozen = totalFrozen.sub(_amount);
    }



    /// returns the total count of users in the staking pool.
    /// @dev returns the total stakers in the staking pool by reading length of addressIndexes array
    function indexesLength() external view returns(uint256 _addressesLength){
        _addressesLength = addressIndexes.length;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeCompounder`
    function setPerformanceFeeCompounder (uint256 _fee) public onlyOwner{
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        performanceFeeCompounder = _fee;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeBurn`
    function setPerformanceFeeBurn (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        performanceFeeBurn = _fee;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `earlyWithdrawFee`
    function setEarlyWithdrawFee (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        earlyWithdrawFee = _fee;
    }


    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeReserve`
    function setPerformanceFeeReserve (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee <= MAX_FEE, "Fee must be less than 10%");
        performanceFeeReserve = _fee;
    }

    /// Store `_time`.
    /// @param _time the new value to store
    /// @dev stores the time in the state variable `earlyWithdrawFeeTime`
    function setEarlyWithdrawFeeTime (uint256 _time) public onlyOwner {
        require(_time > 0, "Time must be greater than 0");
        earlyWithdrawFeeTime = _time;
    }
    /// Store `_limit`.
    /// @param _limit the new value to store
    /// @dev stores the limit in the state variable `autoCompoundLimit`
    function setAutoCompoundLimit (uint256 _limit) public onlyOwner {
        require(_limit > 0, "Limit can not be 0");
        require(_limit < 30, "Max autocompound limit cannot be greater 30");
        autoCompoundLimit = _limit;
    }
   

   
}
