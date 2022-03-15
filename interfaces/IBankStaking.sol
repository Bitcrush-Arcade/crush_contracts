// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;

import "../contracts/Bankroll.sol";
import "../contracts/LiveWallet.sol";

interface IBitcrushStaking {
    /// Store `_bankroll`.
    /// @param _bankroll the new value to store
    /// @dev stores the _bankroll address in the state variable `bankroll`
    function setBankroll(BitcrushBankroll _bankroll) external;

    /// Store `_liveWallet`.
    /// @param _liveWallet the new value to store
    /// @dev stores the _liveWallet address in the state variable `liveWallet`
    function setLiveWallet(BitcrushLiveWallet _liveWallet) external;

    /// Adds the provided amount to the totalPool
    /// @param _amount the amount to add
    /// @dev adds the provided amount to `totalPool` state variable
    function addRewardToPool(uint256 _amount) external;

    /// @notice updates accRewardPerShare based on the last block calculated and totalShares
    /// @dev accRewardPerShare is accumulative, meaning it always holds the total historic
    /// rewardPerShare making apyBaseline necessary to keep rewards fair
    function updateDistribution() external;

    /// @notice updates accProfitPerShare based on current Profit available and totalShares
    /// @dev this allows for consistent profit reporting and no change on profits to distribute
    function updateProfits() external;

    function setCrushPerBlock(uint256 _amount) external;

    /// Stake the provided amount
    /// @param _amount the amount to stake
    /// @dev stakes the provided amount
    function enterStaking(uint256 _amount) external;

    /// Leaves staking for a user by the specified amount and transfering staked amount and reward to users address
    /// @param _amount the amount to unstake
    /// @dev leaves staking and deducts total pool by the users reward. early withdrawal fee applied if withdraw is made before earlyWithdrawFeeTime
    function leaveStaking(uint256 _amount, bool _liveWallet) external;

    /// Get pending rewards of a user for UI
    /// @param _address the address to calculate the reward for
    /// @dev calculates potential reward for the address provided based on crush per block
    function pendingReward(address _address) external view returns (uint256);

    /// Get pending Profits to Claim
    /// @param _address the user's wallet address to calculate profits
    /// @return pending Profits to be claimed by this user
    function pendingProfits(address _address) external view returns (uint256);

    /// compounds the rewards of all users in the pool
    /// @dev compounds the rewards of all users in the pool add adds it into their staked amount while deducting fees
    function compoundAll() external;

    /// freeze certain funds in the staking pool and transfer them to the live wallet address
    /// @dev adds the provided amount to the total frozen variablle
    function freezeStaking(
        uint256 _amount,
        address _recipient,
        address _lwAddress
    ) external;

    /// unfreeze previously frozen funds from the staking pool
    /// @dev deducts the provided amount from the total frozen variablle
    function unfreezeStaking(uint256 _amount) external;

    /// returns the total count of users in the staking pool.
    /// @dev returns the total stakers in the staking pool by reading length of addressIndexes array
    function indexesLength() external view returns (uint256 _addressesLength);

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeCompounder`
    function setPerformanceFeeCompounder(uint256 _fee) external;

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeBurn`
    function setPerformanceFeeBurn(uint256 _fee) external;

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `earlyWithdrawFee`
    function setEarlyWithdrawFee(uint256 _fee) external;

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeReserve`
    function setPerformanceFeeReserve(uint256 _fee) external;

    /// Store `_time`.
    /// @param _time the new value to store
    /// @dev stores the time in the state variable `earlyWithdrawFeeTime`
    function setEarlyWithdrawFeeTime(uint256 _time) external;

    /// Store `_limit`.
    /// @param _limit the new value to store
    /// @dev stores the limit in the state variable `autoCompoundLimit`
    function setAutoCompoundLimit(uint256 _limit) external;

    /// emergency withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function emergencyWithdraw() external;

    //EVENTS

    /// Emitted when adding to reward pool, leaveStaking, or emergencyWithdraw
    event RewardPoolUpdated(uint256 indexed _totalPool);

    /// Currently unused
    event StakeUpdated(address indexed recipeint, uint256 indexed _amount);
}
