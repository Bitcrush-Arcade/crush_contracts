// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IFeeDistributor.sol";

contract InvaderPool is Ownable, ReentrancyGuard {
    struct UserInfo {
        uint256 amount;
        uint256 accReward;
    }

    mapping(address => UserInfo) public userInfo;

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardEnd;
    uint256 public rewardPerBlock;
    uint256 public startBlock;
    uint256 public poolLimit;
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;
    uint256 public fee;
    uint256 public constant DIVISOR = 10000; //100.00

    address public feeAddress;

    uint256 public constant PRECISION_FACTOR = 1e12;

    event Deposit(address indexed _user, uint256 amount);
    event Withdraw(address indexed _user, uint256 amount);
    event AdminTokenRecovery(address indexed _token, uint256 amount);
    event EmergencyWithdraw(address indexed _user, uint256 amount);
    event UpdateLimit(uint256 _limit);
    event UpdateRewardPerBlock(uint256 _newRewardPerBlock);
    event UpdateFeeDistributor(address _new, address _old);
    event UpdateFees(uint256 _new, uint256 _old);

    /// @notice Constructor, set startBlock at least 2 - 3 hours before actual launch time.
    /// @dev Please add funds before startBlock is reached.
    constructor(
        address _staked,
        address _rewarded,
        address _feeAddress,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _poolLimit,
        uint256 rewardAmount,
        uint256 _fee
    ) {
        stakeToken = IERC20(_staked);
        rewardToken = IERC20(_rewarded);
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        poolLimit = _poolLimit;
        rewardEnd = (rewardAmount / _rewardPerBlock) + _startBlock;
        feeAddress = _feeAddress;
        fee = _fee;
    }

    function _updateRewardPool() internal {
        if (block.number <= lastRewardBlock) return;
        uint256 stakedSupply = stakeToken.balanceOf(address(this));
        if (stakedSupply == 0 || lastRewardBlock > rewardEnd) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 reward;
        if (block.number > rewardEnd) reward = rewardEnd - lastRewardBlock;
        else reward = block.number - lastRewardBlock;

        reward = reward * rewardPerBlock;
        accRewardPerShare += (reward * PRECISION_FACTOR) / stakedSupply;
        lastRewardBlock = block.number;
    }

    /// @notice withdraw stake tokens from pool back to user.
    /// @dev updates the pool reward to give through time.
    /// @param _amount the amount to deposit... Amount must be lower than limit
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        if (poolLimit > 0) {
            require(user.amount + _amount <= poolLimit, "Above Limit");
        }

        _updateRewardPool();
        if (user.amount > 0) {
            uint256 pending = ((user.amount * accRewardPerShare) /
                PRECISION_FACTOR) - user.accReward;
            if (pending > 0) {
                bool success = rewardToken.transfer(msg.sender, pending);
                require(success, "Failed to Reward");
            }
        }

        if (_amount > 0) {
            if (fee > 0) {
                uint256 feeAmount = (_amount * fee) / DIVISOR;
                _amount = _amount - feeAmount;
                bool feeSuccess = stakeToken.transferFrom(
                    msg.sender,
                    feeAddress,
                    feeAmount
                );
                require(feeSuccess, "Unable to transfer to fee Address");
            }
            user.amount += _amount;
            bool success = stakeToken.transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            require(success, "Cant deposit");
        }

        user.accReward = (user.amount * accRewardPerShare) / PRECISION_FACTOR;

        emit Deposit(msg.sender, _amount);
    }

    /// @notice withdraw stake tokens from pool back to user.
    /// @dev updates the pool reward to give throught time.
    /// @param _amount the amount to withdraw... Amount must be the staked amount MAX
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(_amount <= user.amount, "Amount to withdraw too high");
        _updateRewardPool();

        uint256 pending = ((user.amount * accRewardPerShare) /
            PRECISION_FACTOR) - user.accReward;
        if (_amount > 0) {
            user.amount -= _amount;
            bool success = stakeToken.transfer(msg.sender, _amount);
            require(success, "Stake Transfer Fail");
        }
        if (pending > 0) {
            bool success = rewardToken.transfer(msg.sender, pending);
        }
        user.accReward = (user.amount * accRewardPerShare) / PRECISION_FACTOR;
        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Allows users to withdraw their funds without any rewards
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 transferAmount = user.amount;
        user.amount = 0;
        user.accReward = 0;
        if (transferAmount > 0) {
            bool success = stakeToken.transfer(msg.sender, transferAmount);
            require(success, "Emergency Cant withdraw");
        }
        emit EmergencyWithdraw(msg.sender, transferAmount);
    }

    /// @notice give pending reward back from having the user account
    /// @param _user The user address to check
    /// @return _reward The reward amount for the timeframe
    function pendingReward(address _user)
        external
        view
        returns (uint256 _reward)
    {
        UserInfo storage user = userInfo[_user];
        uint256 totalSupply = stakeToken.balanceOf(address(this));
        if (block.number > lastRewardBlock && totalSupply > 0) {
            uint256 reward;
            if (block.number > rewardEnd) reward = rewardEnd - lastRewardBlock;
            else reward = block.number - lastRewardBlock;

            reward = reward * rewardPerBlock;
            uint256 adjustedPerShare = accRewardPerShare +
                ((reward * PRECISION_FACTOR) / totalSupply);
            _reward =
                ((adjustedPerShare * user.amount) / PRECISION_FACTOR) -
                user.accReward;
        } else
            _reward =
                ((user.amount * accRewardPerShare) / PRECISION_FACTOR) -
                user.accReward;
    }

    /// @notice It allows the admin to recover wrong tokens sent to the contract
    /// @param _tokenAddress: the address of the token to withdraw
    /// @param _tokenAmount: the number of tokens to withdraw
    /// @dev This function is only callable by admin.
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(_tokenAddress != address(stakeToken), "Cannot be staked token");
        require(
            _tokenAddress != address(rewardToken),
            "Cannot be reward token"
        );

        IERC20(_tokenAddress).transfer(msg.sender, _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /// @notice Update pool limit per user
    /// @dev Only callable by owner.
    /// @param _newLimit: enforce limit only by number... new Limit must be higher or ZERO
    /// @dev if _newLimit is 0 then limit is removed
    function updatePoolLimitPerUser(uint256 _newLimit) external onlyOwner {
        require(
            _newLimit > poolLimit || _newLimit == 0,
            "Increase or remove limit only"
        );
        poolLimit = _newLimit;
        emit UpdateLimit(poolLimit);
    }

    /// @notice Update reward per block
    /// @dev Only callable by owner.
    /// @param _rewardPerBlock: the reward per block
    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        rewardPerBlock = _rewardPerBlock;
        emit UpdateRewardPerBlock(_rewardPerBlock);
    }

    function updateFeeDistributor(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0) && _feeAddress != feeAddress); // dev: Fee distributor can't be zero wallet
        emit UpdateFeeDistributor(_feeAddress, feeAddress);
        feeAddress = _feeAddress;
    }

    function updateFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 2500, "Invalid Fee"); // Fee too high
        emit UpdateFees(_newFee, fee);
        fee = _newFee;
    }
}
