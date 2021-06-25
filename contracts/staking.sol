//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
contract BitcrushStaking is Ownable {
    using SafeMath for uint256;
    
    // Constants
    uint256  public PerformanceFeeCompounder = 100;
    uint256  public PerformanceFeeBurn       = 100;
    uint256  public Divisor = 10000;
    
    uint256  public EarlyWithdrawFee         = 50;
    uint256  public PerformanceFeeReserve    = 190;
    

    uint256 public EarlyWithdrawFeeTime = 72 * 60 * 60 / 3;
    
    CRUSHToken crush;

    struct staked {
        uint256 stakedAmount;
        uint256 claimedAmount;
        uint256 compoundedAmount;
        uint256 lastBlockCompounded;
        uint256 lastBlockStaked;
        uint256 index;
    }
    mapping (address => staked) public stakings;
    address[] public addressIndexes;

    uint256 public totalPool;
    uint256 public lastAutoCompoundBlock;
    uint256 public crushPerBlock;
    address public reserveAddress;

    uint256 public totalStaked;
    uint256 public totalCompound;
    uint256 public totalClaimed;

    event RewardPoolUpdated (uint256 _totalPool);
    event CompoundAll ();

    constructor (CRUSHToken _crush, uint256 _crushPerBlock, address _reserveAddress) public{
        crush = _crush;
        crushPerBlock = _crushPerBlock;
        reserveAddress = _reserveAddress;
        lastAutoCompoundBlock = block.number;
    }

    //Increases the CRUSH prize pool by receiving tokens
    //Receive/Transfer the amount of CRUSH specified in _amount into itself from msg.sender
    //Increase TotalPool
    function addRewardToPool (uint256 _amount) public  {
        require(crush.balanceOf(msg.sender) >= _amount, "Insufficient Crush tokens for transfer");
        totalPool = totalPool + _amount;
        crush.transferFrom(msg.sender, address(this), _amount);
        emit RewardPoolUpdated(totalPool);
    }

    //Edits CrushPerBlock to be equal to _amount
    function setCrushPerBlock (uint256 _amount) public onlyOwner {
        require(_amount >= 0, "Crush per Block can not be negative" );
        crushPerBlock = _amount;
    }


    //Stake CRUSH in Contract
    //Transfer CRUSH from msg.sender to Contract 
    //Add user to Staked Mapping, if user exists, update Staked amount
    function enterStaking (uint256 _amount) public  {
        require(crush.balanceOf(msg.sender) >= _amount, "Insufficient Crush tokens for transfer");
        require(totalPool > 0, "Reward Pool Exhausted");
        
        crush.transferFrom(msg.sender, address(this), _amount);
        if(stakings[msg.sender].stakedAmount == 0){
            stakings[msg.sender].lastBlockCompounded = block.number;
            addressIndexes.push(msg.sender);
            stakings[msg.sender].index = addressIndexes.length-1;
        }
        stakings[msg.sender].stakedAmount += _amount;
        stakings[msg.sender].lastBlockStaked = block.number;
        totalStaked += _amount;
       
    }

    //Withdraw CRUSH from staking and claim rewards
    //Decrease Staked Amount from Staked
    //Transfer CRUSH from Contract to msg.sender, amount to be determined by 
    function leaveStaking (uint256 _amount) public  {
        //check time
        //impose penalty if time limit not met
        //check amount is less than staked amount
        //transfer reward and amount specified
        uint256 reward = getReward(msg.sender);
        totalCompound = totalCompound.add(reward);
        totalStaked = totalStaked.add(reward);
        stakings[msg.sender].compoundedAmount = stakings[msg.sender].compoundedAmount.add(reward);
        stakings[msg.sender].lastBlockCompounded = block.number;
        require(stakings[msg.sender].stakedAmount.add(stakings[msg.sender].compoundedAmount) >= _amount, "Withdraw amount can not be greater than staked amount");

        uint256 difference = 0;
        totalStaked = totalStaked.sub(_amount);
            if(stakings[msg.sender].compoundedAmount >= _amount){
                stakings[msg.sender].compoundedAmount = stakings[msg.sender].compoundedAmount.sub(_amount);
                totalCompound = totalCompound.sub(_amount);
                stakings[msg.sender].claimedAmount = stakings[msg.sender].claimedAmount.add(_amount);
                totalPool = totalPool.sub(_amount);
            }else {
                totalPool = totalPool.sub( stakings[msg.sender].compoundedAmount );
                difference = _amount.sub(stakings[msg.sender].compoundedAmount);
                totalCompound = totalCompound.sub(stakings[msg.sender].compoundedAmount);
                stakings[msg.sender].claimedAmount = stakings[msg.sender].claimedAmount.add(stakings[msg.sender].compoundedAmount);
                stakings[msg.sender].compoundedAmount = 0;
                stakings[msg.sender].stakedAmount = stakings[msg.sender].stakedAmount.sub(difference);
            }

        
        //totalCompound = totalCompound.sub(stakings[msg.sender].compoundedAmount.sub(reward));
        //stakings[msg.sender].claimedAmount = stakings[msg.sender].claimedAmount.add(stakings[msg.sender].compoundedAmount) ;
        if(block.number < stakings[msg.sender].lastBlockStaked + EarlyWithdrawFeeTime ){
            //apply fee
            uint256 withdrawalFee = _amount.mul(EarlyWithdrawFee).div(Divisor);
            _amount = _amount.sub(withdrawalFee);
            crush.transfer(reserveAddress, withdrawalFee);
        }
        crush.transfer(msg.sender, _amount);
        //remove from array
        if(stakings[msg.sender].stakedAmount == 0){
            staked storage staking = stakings[msg.sender];
            if(staking.index != addressIndexes.length-1){
                address lastAddress = addressIndexes[addressIndexes.length-1];
                addressIndexes[staking.index] = lastAddress;
                stakings[lastAddress].index = staking.index;
                crush.approve( address(this), 0);
            }
            addressIndexes.pop();
        }
        emit RewardPoolUpdated(totalPool);
    }


    function getReward(address _address) internal view returns (uint256) {
        if(block.number <=  stakings[_address].lastBlockCompounded){
            return 0;
        }else {
            if(totalPool <= 0 || totalStaked <=0 ){
                return 0;
            }else {
                uint256 blocks = block.number.sub(stakings[_address].lastBlockCompounded);
                uint256 totalReward = blocks.mul(crushPerBlock);
                uint256 stakerReward = totalReward.mul(stakings[_address].stakedAmount).div(totalStaked);
                return stakerReward;
            }
            
        }
    }

    function totalPendingRewards () public view returns (uint256){
            uint256 blocks = block.number.sub(lastAutoCompoundBlock);
            uint256 totalReward = blocks.mul(crushPerBlock);

            return totalReward;
    }

    function pendingReward (address _address) public view returns (uint256){
        return getReward(_address);
    }

    //Send Rewards only to msg.sender
    function claim () public  {
        singleCompound();
        if(stakings[msg.sender].compoundedAmount > 0){
        //require(stakings[msg.sender].compoundedAmount > 0, "Compounded Amount must be greater than 0");
        if(stakings[msg.sender].compoundedAmount > totalPool){
                stakings[msg.sender].compoundedAmount = totalPool;
        }
        stakings[msg.sender].claimedAmount += stakings[msg.sender].compoundedAmount;
        crush.transfer(msg.sender, stakings[msg.sender].compoundedAmount);
        totalStaked = totalStaked.sub(stakings[msg.sender].compoundedAmount);
        totalCompound = totalCompound.sub(stakings[msg.sender].compoundedAmount);
        totalClaimed += stakings[msg.sender].compoundedAmount;
        stakings[msg.sender].compoundedAmount = 0;
        }
        
    }

    //Update staked values on a single User.
    function singleCompound () public  {
        uint256 reward = getReward(msg.sender);
        stakings[msg.sender].compoundedAmount = stakings[msg.sender].compoundedAmount.add(reward);
        totalStaked = totalStaked.add(reward);
        stakings[msg.sender].lastBlockCompounded = block.number;
        totalCompound = totalCompound.add(reward);
        totalPool = totalPool.sub(reward);
        emit RewardPoolUpdated(totalPool);
    }

    //Compound all of the rewards for all stakers
    function compoundAll () public  {
        require(lastAutoCompoundBlock < block.number, "Compound All not yet application.");
        uint256 crushToBurn = 0;
        uint256 reward = 0;
        uint256 performanceFee = 0;
        uint256 totalReward = 0;
        for(uint256 i=0; i < addressIndexes.length; i++){
            uint256 stakerReward = getReward(addressIndexes[i]);
            
            uint256 stakerBurn = stakerReward.mul(PerformanceFeeBurn).div(Divisor);
            crushToBurn = crushToBurn.add(stakerBurn);
            
            uint256 cpAllReward = stakerReward.mul(PerformanceFeeCompounder).div(Divisor);
            reward = reward.add(cpAllReward);
            
            uint256 feeReserve = stakerReward.mul(PerformanceFeeReserve).div(Divisor);
            performanceFee = performanceFee.add(feeReserve);
            

            stakerReward = stakerReward.sub(stakerBurn);
            stakerReward = stakerReward.sub(cpAllReward);
            stakerReward = stakerReward.sub(feeReserve);

            totalStaked = totalStaked.add(stakerReward);
            totalReward = totalReward.add(stakerReward);
            totalCompound = totalCompound.add(stakerReward); 
            stakings[addressIndexes[i]].compoundedAmount += stakerReward;
            stakings[addressIndexes[i]].lastBlockCompounded = block.number;
        }
        lastAutoCompoundBlock = block.number;
        crush.burn(crushToBurn);
        crush.transfer(msg.sender, reward);
        crush.transfer(reserveAddress, performanceFee);
        totalPool = totalPool.sub(totalReward);
        emit CompoundAll();
        emit RewardPoolUpdated(totalPool);
    }

    //emergency withdraw without caring about reward
    function emergencyWithdraw() public{
        crush.transfer( msg.sender, stakings[msg.sender].stakedAmount);
        stakings[msg.sender].stakedAmount = 0;
        stakings[msg.sender].compoundedAmount = 0;
        stakings[msg.sender].lastBlockCompounded = block.number;
        staked storage staking = stakings[msg.sender];
        if(staking.index != addressIndexes.length-1){
            address lastAddress = addressIndexes[addressIndexes.length-1];
            addressIndexes[staking.index] = lastAddress;
            stakings[lastAddress].index = staking.index;
        }
        addressIndexes.pop();
        crush.approve( address(this), 0);
    }

    function emergencyTotalPoolWithdraw () public onlyOwner {
        require(totalPool > 0, "Total Pool need to be greater than 0");
        crush.transfer(msg.sender, totalPool);
        totalPool = 0;
    }

    function setPerformanceFeeCompounder (uint256 _fee) public onlyOwner{
        require(_fee > 0, "Fee must be greater than 0");
        PerformanceFeeCompounder = _fee;
    }

    function setPerformanceFeeBurn (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        PerformanceFeeBurn = _fee;
    }

    function setEarlyWithdrawFee (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        EarlyWithdrawFee = _fee;
    }

    function setPerformanceFeeReserve (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        PerformanceFeeReserve = _fee;
    }
    
    function setEarlyWithdrawFeeTime (uint256 _time) public onlyOwner {
        require(_time > 0, "Time must be greater than 0");
        EarlyWithdrawFeeTime = _time;
    }

    function setFeeDivisor (uint256 _divisor) public onlyOwner {
        require(_divisor > 0, "Divisor must be greater than 0");
        Divisor = _divisor;
    }
    
}
