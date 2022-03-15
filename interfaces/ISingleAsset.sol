// SPDX-License-Identifier: MIT
pragma solidty 0.8.12;

interface ISingleAssetStaking {
    /// Adds the provided amount to the totalPool
    /// @param _amount the amount to add
    /// @dev adds the provided amount to `totalPool` state variable
    function addRewardToPool(uint256 _amount) external;

    /// DESCRIPTION PENDING
    function setCrushPerBlock(uint256 _amount) external;

    /// Stake the provided amount
    /// @param _amount the amount to stake
    /// @dev stakes the provided amount
    function enterStaking(uint256 _amount) external;

    /// Leaves staking for a user by the specified amount and transfering staked amount and reward to users address
    /// @param _amount the amount to unstake
    /// @dev leaves staking and deducts total pool by the users reward. early withdrawal fee applied if withdraw is made before earlyWithdrawFeeTime
    function leaveStaking(uint256 _amount) external;

    /// Leaves staking for a user while setting stakedAmount to 0 and transfering staked amount and reward to users address
    /// @dev leaves staking and deducts total pool by the users reward. early withdrawal fee applied if withdraw is made before earlyWithdrawFeeTime
    function leaveStakingCompletely() external;

    /// Calculates total potential pending rewards
    /// @dev Calculates potential reward based on crush per block
    function totalPendingRewards() external view returns (uint256);

    /// Get pending rewards of a user
    /// @param _address the address to calculate the reward for
    /// @dev calculates potential reward for the address provided based on crush per block
    function pendingReward(address _address) external view returns (uint256);

    /// transfers the rewards of a user to their address
    /// @dev calculates users rewards and transfers it out while deducting reward from totalPool
    function claim() external;

    /// compounds the rewards of the caller
    /// @dev compounds the rewards of the caller add adds it into their staked amount
    function singleCompound() external;

    /// compounds the rewards of all users in the pool
    /// @dev compounds the rewards of all users in the pool add adds it into their staked amount while deducting fees
    function compoundAll() external;

    /// withdraws the staked amount of user in case of emergency.
    /// @dev drains the staked amount and sets the state variable `stakedAmount` of staking mapping to 0
    function emergencyWithdraw() external;

    /// withdraws the total pool in case of emergency.
    /// @dev drains the total pool and sets the state variable `totalPool` to 0
    function emergencyTotalPoolWithdraw() external;

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
}
