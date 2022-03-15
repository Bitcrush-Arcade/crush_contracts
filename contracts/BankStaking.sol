//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;

//BSC Address: 0x9D1Bc6843130fCAc8A609Bd9cb02Fb8A1E95630e
//openzeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//bitcrush
import "./CrushToken.sol";
import "./Bankroll.sol";
import "../interfaces/IBankStaking.sol";
import "./LiveWallet.sol";

contract BitcrushStaking is Ownable, IBitcrushStaking {
    using SafeMath for uint256;
    using SafeERC20 for CRUSHToken;
    uint256 public constant MAX_CRUSH_PER_BLOCK = 10000000000000000000;
    uint256 public constant MAX_FEE = 1000; // 1000/10000 * 100 = 10%
    uint256 public performanceFeeCompounder = 10; // 10/10000 * 100 = 0.1%
    uint256 public performanceFeeBurn = 100; // 100/10000 * 100 = 1%
    uint256 public constant divisor = 10000;

    uint256 public earlyWithdrawFee = 50; // 50/10000 * 100 = 0.5%
    uint256 public frozenEarlyWithdrawFee = 1500; // 1500/10000 * 100 = 15%
    uint256 public performanceFeeReserve = 190; // 190/10000 * 100 = 1.9%

    uint256 public frozenEarlyWithdrawFeeTime = 10800;

    uint256 public blockPerSecond = 3;
    uint256 public earlyWithdrawFeeTime = (72 * 60 * 60) / blockPerSecond;
    uint256 public apyBoost = 2500; //2500/10000 * 100 = 25%
    uint256 public totalShares;

    // Contracts to Interact with
    CRUSHToken public immutable crush;
    BitcrushBankroll public bankroll;
    BitcrushLiveWallet public liveWallet;
    // Team address to maintain funds
    address public reserveAddress;

    struct UserStaking {
        uint256 shares;
        uint256 stakedAmount;
        uint256 claimedAmount;
        uint256 lastBlockCompounded;
        uint256 lastBlockStaked;
        uint256 index;
        uint256 lastFrozenWithdraw;
        uint256 apyBaseline;
        uint256 profitBaseline;
    }
    mapping(address => UserStaking) public stakings;
    address[] public addressIndexes;

    uint256 public lastAutoCompoundBlock;

    uint256 public batchStartingIndex;
    uint256 public crushPerBlock = 5500000000000000000;
    // Pool Accumulated Reward Per Share (APY)
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;
    // Profit Accumulated Reward Per Share
    uint256 public accProfitPerShare;
    // Tracking Totals
    uint256 public totalPool; // Reward for Staking
    uint256 public totalStaked;
    uint256 public totalClaimed; // Total Claimed as rewards
    uint256 public totalFrozen;
    uint256 public totalProfitsClaimed;
    uint256 public totalProfitDistributed; // Total Claimed as Profits

    uint256 public autoCompoundLimit = 10; // Max Batch Size

    uint256 public deploymentTimeStamp;

    event RewardPoolUpdated(uint256 indexed _totalPool);
    event StakeUpdated(address indexed recipeint, uint256 indexed _amount);

    constructor(
        CRUSHToken _crush,
        uint256 _crushPerBlock,
        address _reserveAddress
    ) {
        crush = _crush;
        if (_crushPerBlock <= MAX_CRUSH_PER_BLOCK) {
            crushPerBlock = _crushPerBlock;
        }
        reserveAddress = _reserveAddress;
        deploymentTimeStamp = block.timestamp;
        lastRewardBlock = block.number;
    }

    /// Store `_bankroll`.
    /// @param _bankroll the new value to store
    /// @dev stores the _bankroll address in the state variable `bankroll`
    function setBankroll(BitcrushBankroll _bankroll) public override onlyOwner {
        require(
            address(bankroll) == address(0),
            "Bankroll address already set"
        );
        bankroll = _bankroll;
    }

    /// Store `_liveWallet`.
    /// @param _liveWallet the new value to store
    /// @dev stores the _liveWallet address in the state variable `liveWallet`
    function setLiveWallet(BitcrushLiveWallet _liveWallet)
        public
        override
        onlyOwner
    {
        require(
            address(liveWallet) == address(0),
            "Live Wallet address already set"
        );
        liveWallet = _liveWallet;
    }

    /// Adds the provided amount to the totalPool
    /// @param _amount the amount to add
    /// @dev adds the provided amount to `totalPool` state variable
    function addRewardToPool(uint256 _amount) public override {
        require(
            crush.balanceOf(msg.sender) >= _amount,
            "Insufficient Crush tokens for transfer"
        );
        totalPool = totalPool.add(_amount);
        crush.safeTransferFrom(msg.sender, address(this), _amount);
        emit RewardPoolUpdated(totalPool);
    }

    /// @notice updates accRewardPerShare based on the last block calculated and totalShares
    /// @dev accRewardPerShare is accumulative, meaning it always holds the total historic
    /// rewardPerShare making apyBaseline necessary to keep rewards fair
    function updateDistribution() public override {
        if (block.number <= lastRewardBlock) return;
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 rewardPerBlock = crushPerBlock;
        if (totalFrozen > 0)
            rewardPerBlock = rewardPerBlock.add(
                crushPerBlock.mul(apyBoost).div(divisor)
            );
        if (totalPool == 0) rewardPerBlock = 0;
        uint256 blocksSinceCalc = block.number.sub(lastRewardBlock);
        uint256 rewardCalc = blocksSinceCalc.mul(rewardPerBlock).mul(1e12).div(
            totalShares
        );
        accRewardPerShare = accRewardPerShare.add(rewardCalc);
        lastRewardBlock = block.number;
    }

    /// @notice updates accProfitPerShare based on current Profit available and totalShares
    /// @dev this allows for consistent profit reporting and no change on profits to distribute
    function updateProfits() public override {
        if (totalShares == 0) return;
        uint256 requestedProfits = bankroll.transferProfit();
        if (requestedProfits == 0) return;
        totalProfitDistributed = totalProfitDistributed.add(requestedProfits);
        uint256 profitCalc = requestedProfits.mul(1e12).div(totalShares);
        accProfitPerShare = accProfitPerShare.add(profitCalc);
    }

    function setCrushPerBlock(uint256 _amount) public override onlyOwner {
        require(_amount >= 0, "Crush per Block can not be negative");
        require(
            _amount <= MAX_CRUSH_PER_BLOCK,
            "Crush Per Block can not be more than 10"
        );
        crushPerBlock = _amount;
    }

    /// Stake the provided amount
    /// @param _amount the amount to stake
    /// @dev stakes the provided amount
    function enterStaking(uint256 _amount) public override {
        require(
            crush.balanceOf(msg.sender) >= _amount,
            "Insufficient Crush tokens for transfer"
        );
        require(_amount > 0, "Invalid staking amount");

        updateDistribution();
        updateProfits();
        crush.safeTransferFrom(msg.sender, address(this), _amount);
        if (totalStaked == 0) {
            lastAutoCompoundBlock = block.number;
        }
        UserStaking storage user = stakings[msg.sender];

        if (user.stakedAmount == 0) {
            user.lastBlockCompounded = block.number;
            addressIndexes.push(msg.sender);
            user.index = addressIndexes.length - 1;
        } else {
            uint256 pending = user.shares.mul(accRewardPerShare).div(1e12).sub(
                user.apyBaseline
            );
            if (pending > totalPool) pending = totalPool;
            totalPool = totalPool.sub(pending);
            uint256 profitPending = user
                .shares
                .mul(accProfitPerShare)
                .div(1e12)
                .sub(user.profitBaseline);
            pending = pending.add(profitPending);
            if (pending > 0) {
                crush.safeTransfer(msg.sender, pending);
                user.claimedAmount = user.claimedAmount.add(pending);
                totalClaimed = totalClaimed.add(pending);
                totalProfitsClaimed = totalProfitsClaimed.add(profitPending);
            }
        }

        uint256 currentShares = 0;
        if (totalShares != 0)
            currentShares = _amount.mul(totalShares).div(totalStaked);
        else currentShares = _amount;

        totalStaked = totalStaked.add(_amount);
        totalShares = totalShares.add(currentShares);
        if (user.shares == 0) {
            user.lastBlockCompounded = block.number;
        }
        user.shares = user.shares.add(currentShares);
        user.profitBaseline = accProfitPerShare.mul(user.shares).div(1e12);
        user.apyBaseline = accRewardPerShare.mul(user.shares).div(1e12);
        user.stakedAmount = user.stakedAmount.add(_amount);
        user.lastBlockStaked = block.number;
    }

    /// Leaves staking for a user by the specified amount and transfering staked amount and reward to users address
    /// @param _amount the amount to unstake
    /// @dev leaves staking and deducts total pool by the users reward. early withdrawal fee applied if withdraw is made before earlyWithdrawFeeTime
    function leaveStaking(uint256 _amount, bool _liveWallet) external override {
        updateDistribution();
        updateProfits();
        UserStaking storage user = stakings[msg.sender];
        uint256 reward = user.shares.mul(accRewardPerShare).div(1e12).sub(
            user.apyBaseline
        );
        uint256 profitShare = user.shares.mul(accProfitPerShare).div(1e12).sub(
            user.profitBaseline
        );
        if (reward > totalPool) reward = totalPool;
        totalPool = totalPool.sub(reward);
        reward = reward.add(profitShare);
        totalProfitsClaimed = totalProfitsClaimed.add(profitShare);
        user.lastBlockCompounded = block.number;

        uint256 availableStaked = user.stakedAmount;
        if (totalFrozen > 0) {
            availableStaked = availableStaked.sub(
                totalFrozen.mul(user.stakedAmount).div(totalStaked)
            );
            require(
                availableStaked >= _amount,
                "Frozen Funds: Can't withdraw more than Available funds"
            );
        } else if (user.lastFrozenWithdraw > 0) {
            user.lastFrozenWithdraw = 0;
        }
        require(
            availableStaked >= _amount,
            "Withdraw amount can not be greater than available staked amount"
        );
        totalStaked = totalStaked.sub(_amount);

        uint256 shareReduction = _amount.mul(user.shares).div(
            user.stakedAmount
        );
        user.stakedAmount = user.stakedAmount.sub(_amount);
        user.shares = user.shares.sub(shareReduction);
        totalShares = totalShares.sub(shareReduction);
        user.apyBaseline = user.shares.mul(accRewardPerShare).div(1e12);
        user.profitBaseline = user.shares.mul(accProfitPerShare).div(1e12);
        _amount = _amount.add(reward);
        if (totalFrozen > 0) {
            if (user.lastFrozenWithdraw > 0)
                require(
                    block.timestamp >
                        user.lastFrozenWithdraw.add(frozenEarlyWithdrawFeeTime),
                    "Only One Withdraw allowed per 3 hours during freeze"
                );

            uint256 withdrawalFee = _amount.mul(frozenEarlyWithdrawFee).div(
                divisor
            );
            user.lastFrozenWithdraw = block.timestamp;
            _amount = _amount.sub(withdrawalFee);

            if (withdrawalFee > totalFrozen) {
                uint256 remainder = withdrawalFee.sub(totalFrozen);
                crush.approve(address(bankroll), remainder);
                totalFrozen = 0;
            } else totalFrozen = totalFrozen.sub(withdrawalFee);

            bankroll.recoverBankroll(withdrawalFee);
        } else if (
            block.number < user.lastBlockStaked.add(earlyWithdrawFeeTime)
        ) {
            //apply fee
            uint256 withdrawalFee = _amount.mul(earlyWithdrawFee).div(divisor);
            _amount = _amount.sub(withdrawalFee);
            crush.safeTransfer(reserveAddress, withdrawalFee);
        }

        if (_liveWallet == false) crush.safeTransfer(msg.sender, _amount);
        else {
            crush.approve(address(liveWallet), _amount);
            liveWallet.addbetWithAddress(_amount, msg.sender);
        }
        user.claimedAmount = user.claimedAmount.add(reward);
        totalClaimed = totalClaimed.add(reward);
        //remove from batchig array
        if (user.stakedAmount == 0) {
            if (user.index != addressIndexes.length - 1) {
                address lastAddress = addressIndexes[addressIndexes.length - 1];
                addressIndexes[user.index] = lastAddress;
                stakings[lastAddress].index = user.index;
            }
            addressIndexes.pop();
        }
        emit RewardPoolUpdated(totalPool);
    }

    /// Get pending rewards of a user for UI
    /// @param _address the address to calculate the reward for
    /// @dev calculates potential reward for the address provided based on crush per block
    function pendingReward(address _address) external view returns (uint256) {
        UserStaking storage user = stakings[_address];
        uint256 rewardPerBlock = crushPerBlock;
        if (totalFrozen > 0)
            rewardPerBlock = rewardPerBlock.add(
                crushPerBlock.mul(apyBoost).div(divisor)
            );
        if (totalPool == 0) rewardPerBlock = 0;
        uint256 localAccRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && totalShares != 0) {
            uint256 blocksSinceCalc = block.number.sub(lastRewardBlock);
            uint256 rewardCalc = blocksSinceCalc
                .mul(rewardPerBlock)
                .mul(1e12)
                .div(totalShares);
            localAccRewardPerShare = accRewardPerShare.add(rewardCalc);
        }
        return
            user.shares.mul(localAccRewardPerShare).div(1e12).sub(
                user.apyBaseline
            );
    }

    /// Get pending Profits to Claim
    /// @param _address the user's wallet address to calculate profits
    /// @return pending Profits to be claimed by this user
    function pendingProfits(address _address)
        public
        view
        override
        returns (uint256)
    {
        UserStaking storage user = stakings[_address];
        return
            user.shares.mul(accProfitPerShare).div(1e12).sub(
                user.profitBaseline
            );
    }

    /// compounds the rewards of all users in the pool
    /// @dev compounds the rewards of all users in the pool add adds it into their staked amount while deducting fees
    function compoundAll() public override {
        require(
            lastAutoCompoundBlock <= block.number,
            "Compound All not yet applicable."
        );
        require(totalStaked > 0, "No Staked rewards to claim");
        uint256 crushToBurn = 0;
        uint256 performanceFee = 0;

        uint256 compounderReward = 0;
        uint256 totalPoolDeducted = 0;

        uint256 batchStart = batchStartingIndex;
        if (batchStartingIndex >= addressIndexes.length) batchStart = 0;

        uint256 batchLimit = addressIndexes.length;
        if (
            addressIndexes.length <= autoCompoundLimit ||
            batchStart.add(autoCompoundLimit) >= addressIndexes.length
        ) batchLimit = addressIndexes.length;
        else batchLimit = batchStart.add(autoCompoundLimit);

        updateProfits();
        updateDistribution();
        for (uint256 i = batchStart; i < batchLimit; i++) {
            UserStaking storage currentUser = stakings[addressIndexes[i]];
            uint256 stakerReward = currentUser
                .shares
                .mul(accRewardPerShare)
                .div(1e12)
                .sub(currentUser.apyBaseline);
            if (totalPool < totalPoolDeducted.add(stakerReward)) {
                stakerReward = totalPool.sub(totalPoolDeducted);
            }
            currentUser.apyBaseline = currentUser.apyBaseline.add(stakerReward);
            if (stakerReward > 0)
                totalPoolDeducted = totalPoolDeducted.add(stakerReward);
            uint256 profitReward = currentUser
                .shares
                .mul(accProfitPerShare)
                .div(1e12)
                .sub(currentUser.profitBaseline);
            currentUser.profitBaseline = currentUser.profitBaseline.add(
                profitReward
            );
            stakerReward = stakerReward.add(profitReward);
            if (stakerReward > 0) {
                totalProfitsClaimed = totalProfitsClaimed.add(profitReward);
                totalClaimed = totalClaimed.add(stakerReward);
                uint256 stakerBurn = stakerReward.mul(performanceFeeBurn).div(
                    divisor
                );
                crushToBurn = crushToBurn.add(stakerBurn);

                uint256 cpAllReward = stakerReward
                    .mul(performanceFeeCompounder)
                    .div(divisor);
                compounderReward = compounderReward.add(cpAllReward);

                uint256 feeReserve = stakerReward
                    .mul(performanceFeeReserve)
                    .div(divisor);
                performanceFee = performanceFee.add(feeReserve);
                stakerReward = stakerReward.sub(stakerBurn);
                stakerReward = stakerReward.sub(cpAllReward);
                stakerReward = stakerReward.sub(feeReserve);
                currentUser.claimedAmount = currentUser.claimedAmount.add(
                    stakerReward
                );
                currentUser.stakedAmount = currentUser.stakedAmount.add(
                    stakerReward
                );

                totalStaked = totalStaked.add(stakerReward);
            }
            currentUser.lastBlockCompounded = block.number;
        }
        batchStartingIndex = batchLimit;
        if (batchStartingIndex >= addressIndexes.length) {
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
    function freezeStaking(
        uint256 _amount,
        address _recipient,
        address _lwAddress
    ) public override {
        require(msg.sender == address(bankroll), "Callet must be bankroll");
        //divide amount over users
        //update user mapping to reflect frozen amount
        require(
            _amount <= totalStaked.sub(totalFrozen),
            "Freeze amount should be less than or equal to available funds"
        );
        totalFrozen = totalFrozen.add(_amount);
        BitcrushLiveWallet currentLw = BitcrushLiveWallet(_lwAddress);
        currentLw.addToUserWinnings(_amount, _recipient);
        crush.safeTransfer(address(_lwAddress), _amount);
        updateDistribution();
        updateProfits();
    }

    /// unfreeze previously frozen funds from the staking pool
    /// @dev deducts the provided amount from the total frozen variablle
    function unfreezeStaking(uint256 _amount) public override {
        require(msg.sender == address(bankroll), "Caller must be bankroll");
        require(
            _amount <= totalFrozen,
            "unfreeze amount cant be greater than currently frozen amount"
        );
        totalFrozen = totalFrozen.sub(_amount);
        updateDistribution();
        updateProfits();
    }

    /// returns the total count of users in the staking pool.
    /// @dev returns the total stakers in the staking pool by reading length of addressIndexes array
    function indexesLength()
        external
        view
        override
        returns (uint256 _addressesLength)
    {
        _addressesLength = addressIndexes.length;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeCompounder`
    function setPerformanceFeeCompounder(uint256 _fee)
        public
        override
        onlyOwner
    {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        performanceFeeCompounder = _fee;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeBurn`
    function setPerformanceFeeBurn(uint256 _fee) public override onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        performanceFeeBurn = _fee;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `earlyWithdrawFee`
    function setEarlyWithdrawFee(uint256 _fee) public override onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        earlyWithdrawFee = _fee;
    }

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeReserve`
    function setPerformanceFeeReserve(uint256 _fee) public override onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee <= MAX_FEE, "Fee must be less than 10%");
        performanceFeeReserve = _fee;
    }

    /// Store `_time`.
    /// @param _time the new value to store
    /// @dev stores the time in the state variable `earlyWithdrawFeeTime`
    function setEarlyWithdrawFeeTime(uint256 _time) public override onlyOwner {
        require(_time > 0, "Time must be greater than 0");
        earlyWithdrawFeeTime = _time;
    }

    /// Store `_limit`.
    /// @param _limit the new value to store
    /// @dev stores the limit in the state variable `autoCompoundLimit`
    function setAutoCompoundLimit(uint256 _limit) public override onlyOwner {
        require(_limit > 0, "Limit can not be 0");
        require(_limit < 30, "Max autocompound limit cannot be greater 30");
        autoCompoundLimit = _limit;
    }

    /// emergency withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function emergencyWithdraw() public override {
        updateDistribution();

        UserStaking storage user = stakings[msg.sender];
        user.lastBlockCompounded = block.number;

        uint256 availableStaked = user.stakedAmount;
        if (totalFrozen > 0) {
            availableStaked = availableStaked.sub(
                totalFrozen.mul(user.stakedAmount).div(totalStaked)
            );
        } else if (user.lastFrozenWithdraw > 0) {
            user.lastFrozenWithdraw = 0;
        }

        totalStaked = totalStaked.sub(availableStaked);

        uint256 shareReduction = availableStaked.mul(user.shares).div(
            user.stakedAmount
        );
        user.stakedAmount = user.stakedAmount.sub(availableStaked);
        user.shares = user.shares.sub(shareReduction);
        totalShares = totalShares.sub(shareReduction);
        user.apyBaseline = user.shares.mul(accRewardPerShare).div(1e12);
        user.profitBaseline = user.shares.mul(accProfitPerShare).div(1e12);

        if (totalFrozen > 0) {
            if (user.lastFrozenWithdraw > 0)
                require(
                    block.timestamp >
                        user.lastFrozenWithdraw.add(frozenEarlyWithdrawFeeTime),
                    "Only One Withdraw allowed per 3 hours during freeze"
                );

            uint256 withdrawalFee = availableStaked
                .mul(frozenEarlyWithdrawFee)
                .div(divisor);
            user.lastFrozenWithdraw = block.timestamp;
            availableStaked = availableStaked.sub(withdrawalFee);

            if (withdrawalFee > totalFrozen) {
                uint256 remainder = withdrawalFee.sub(totalFrozen);
                crush.approve(address(bankroll), remainder);
                totalFrozen = 0;
            } else totalFrozen = totalFrozen.sub(withdrawalFee);

            crush.safeTransfer(reserveAddress, withdrawalFee);
        } else if (
            block.number < user.lastBlockStaked.add(earlyWithdrawFeeTime)
        ) {
            //apply fee
            uint256 withdrawalFee = availableStaked.mul(earlyWithdrawFee).div(
                divisor
            );
            availableStaked = availableStaked.sub(withdrawalFee);
            crush.safeTransfer(reserveAddress, withdrawalFee);
        }

        crush.safeTransfer(msg.sender, availableStaked);

        //remove from batchig array
        if (user.stakedAmount == 0) {
            if (user.index != addressIndexes.length - 1) {
                address lastAddress = addressIndexes[addressIndexes.length - 1];
                addressIndexes[user.index] = lastAddress;
                stakings[lastAddress].index = user.index;
            }
            addressIndexes.pop();
        }
        emit RewardPoolUpdated(totalPool);
    }
}
