//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IBitcrushNiceStaking {
    /// Store `_staking`.
    /// @param _staking the new value to store
    /// @dev stores the _staking address in the state variable `staking`
    function setStakingPool(address _staking) external;

    /// Store `_galacticChef`.
    /// @param _galacticChef the new value to store
    /// @dev stores the _galacticChef address in the state variable `galacticChef`
    function setGalacticChef(address _galacticChef) external;

    /// Store `_poolId`.
    /// @param _poolId the new value to store
    /// @dev stores the _poolId address in the state variable `poolId`
    function setPoolId(uint256 _poolId) external;

    /// @notice updates accProfitPerShare based on current Profit available and totalShares
    /// @dev this allows for consistent profit reporting and no change on profits to distribute
    function updateProfits() external;

    /// Get pending Profits to Claim
    /// @param _address the user's wallet address to calculate profits
    /// @return pending Profits to be claimed by this user
    function pendingProfits(address _address) external returns (uint256);

    /// compounds the rewards of all users in the pool
    /// @dev compounds the rewards of all users in the pool while deducting fees
    function compoundAll() external;

    /// withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function withdrawNiceRewards() external;

    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `performanceFeeCompounder`
    function setPerformanceFeeCompounder(uint256 _fee) external;

    /// emergency withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function emergencyWithdraw() external;
}
