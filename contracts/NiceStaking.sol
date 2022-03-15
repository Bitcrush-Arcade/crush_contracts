//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/INiceStaking.sol";
import "./GalacticChef.sol";
import "./NICEToken.sol";

contract BitcrushNiceStaking is Ownable, IBitcrushNiceStaking {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 public performanceFeeCompounder = 10; // 10/10000 * 100 = 0.1%
    uint256 public constant MAX_FEE = 1000; // 1000/10000 * 100 = 10%
    uint256 public constant divisor = 10000;
    uint256 public poolId;
    // Contracts to Interact with
    IStaking public stakingPool;
    GalacticChef public galacticChef;
    IERC20 public immutable nice;

    struct UserStaking {
        uint256 shares;
        uint256 profitBaseline;
    }
    mapping(address => UserStaking) public stakings;
    mapping(address => uint256) public niceRewards;

    uint256 public lastAutoCompoundBlock;

    // Profit Accumulated Reward Per Share
    uint256 public accProfitPerShare;

    // Tracking Totals
    uint256 public totalProfitDistributed; // Total Claimed as Profits

    uint256 public deploymentTimeStamp;

    event PerformanceFeeUpdated(uint256 newFee);
    event PoolIdUpdated(uint256 poolId);

    constructor(IERC20 _nice) {
        nice = _nice;
        deploymentTimeStamp = block.timestamp;
    }

    /// Store `_staking`.
    /// @param _staking the new value to store
    /// @dev stores the _staking address in the state variable `staking`
    function setStakingPool(IStaking _staking) public override onlyOwner {
        require(
            address(stakingPool) == address(0x0),
            "staking pool address already set"
        );
        stakingPool = _staking;
    }

    /// Store `_galacticChef`.
    /// @param _galacticChef the new value to store
    /// @dev stores the _galacticChef address in the state variable `galacticChef`
    function setGalacticChef(GalacticChef _galacticChef)
        public
        override
        onlyOwner
    {
        require(
            address(galacticChef) == address(0x0),
            "staking pool address already set"
        );
        galacticChef = _galacticChef;
    }

    /// Store `_poolId`.
    /// @param _poolId the new value to store
    /// @dev stores the _poolId address in the state variable `poolId`
    function setPoolId(uint256 _poolId) public override onlyOwner {
        poolId = _poolId;
        emit PoolIdUpdated(_poolId);
    }

    /// @notice updates accProfitPerShare based on current Profit available and totalShares
    /// @dev this allows for consistent profit reporting and no change on profits to distribute
    function updateProfits() public override {
        if (stakingPool.totalShares() == 0) return;
        //Todo replace with galatic chef rewards
        uint256 requestedProfits = galacticChef.mintRewards(poolId);
        if (requestedProfits == 0) return;
        totalProfitDistributed = totalProfitDistributed.add(requestedProfits);
        uint256 profitCalc = requestedProfits.mul(1e12).div(
            stakingPool.totalShares()
        );
        accProfitPerShare = accProfitPerShare.add(profitCalc);
    }

    /// Get pending Profits to Claim
    /// @param _address the user's wallet address to calculate profits
    /// @return pending Profits to be claimed by this user
    function pendingProfits(address _address)
        public
        override
        returns (uint256)
    {
        UserStaking memory user = stakings[_address];
        (user.shares, , , , , , , , ) = stakingPool.stakings(_address);
        return
            user.shares.mul(accProfitPerShare).div(1e12).sub(
                user.profitBaseline
            );
    }

    /// compounds the rewards of all users in the pool
    /// @dev compounds the rewards of all users in the pool while deducting fees
    function compoundAll() public override {
        require(
            lastAutoCompoundBlock <= block.number,
            "Compound All not yet applicable."
        );

        uint256 compounderReward = 0;
        uint256 batchStartingIndex = stakingPool.batchStartingIndex();
        uint256 indexesLength = stakingPool.indexesLength();
        uint256 autoCompundLimit = stakingPool.autoCompoundLimit();

        uint256 batchStart = batchStartingIndex;
        if (batchStartingIndex >= indexesLength) batchStart = 0;

        uint256 batchLimit = indexesLength;
        if (
            indexesLength <= autoCompundLimit ||
            batchStart.add(autoCompundLimit) >= indexesLength
        ) batchLimit = indexesLength;
        else batchLimit = batchStart.add(autoCompundLimit);

        updateProfits();
        for (uint256 i = batchStart; i < batchLimit; i++) {
            address currentAddress = stakingPool.addressIndexes(i);
            UserStaking storage currentUser = stakings[currentAddress];
            (currentUser.shares, , , , , , , , ) = stakingPool.stakings(
                currentAddress
            );

            uint256 stakerReward = currentUser
                .shares
                .mul(accProfitPerShare)
                .div(1e12)
                .sub(currentUser.profitBaseline);
            currentUser.profitBaseline = currentUser.profitBaseline.add(
                stakerReward
            );

            if (stakerReward > 0) {
                uint256 cpAllReward = stakerReward
                    .mul(performanceFeeCompounder)
                    .div(divisor);
                compounderReward = compounderReward.add(cpAllReward);
                stakerReward = stakerReward.sub(cpAllReward);
                niceRewards[currentAddress] = niceRewards[currentAddress].add(
                    stakerReward
                );
            }
        }

        lastAutoCompoundBlock = block.number;
        nice.safeTransfer(msg.sender, compounderReward);
        stakingPool.compoundAll();
    }

    /// withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function withdrawNiceRewards() public override {
        require(niceRewards[msg.sender] > 0, "No rewards available");
        uint256 amount = niceRewards[msg.sender];
        niceRewards[msg.sender] = 0;
        nice.safeTransfer(msg.sender, amount);
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
        emit PerformanceFeeUpdated(_fee);
    }

    /// emergency withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function emergencyWithdraw() public override {
        uint256 amount = niceRewards[msg.sender];
        niceRewards[msg.sender] = 0;
        nice.safeTransfer(msg.sender, amount);
    }
}
