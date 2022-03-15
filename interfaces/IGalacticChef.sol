// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IGalacticChef {
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
        uint256 _mult,
        bool _type,
        uint256 _fee,
        bool _isLP,
        uint256[] calldata _pidEdit,
        uint256[] calldata _pidMulEdit
    ) external;

    /// @notice this is for frontend only, calculates the pending reward for a particular user in a specific pool.
    /// @param _user User to calculate rewards to
    /// @param _pid Pool Id to calculate rewards of
    function pendingRewards(address _user, uint256 _pid)
        external
        view
        returns (uint256 _pendingRewards);

    /// @notice Update the accRewardPerShare for a specific pool
    /// @param _pid Pool Id to update the accumulated rewards
    function updatePool(uint256 _pid) external;

    /// @notice getCurrentEmissions allows external users to get the current reward emissions
    /// It Uses getTimeEmissions to get the current emissions for the pool between last reward emission and current emission
    /// @param _pid Pool Id  from which we need emissions calculated
    /// @return _emissions emissions for the given pool between
    function getCurrentEmissions(uint256 _pid)
        external
        view
        returns (uint256 _emissions);

    /// @notice Update all pools accPerShare
    /// @dev this might be expensive to call...
    function massUpdatePools() external;

    /// @notice This is for Third party pools only. This handles the reward.
    /// @param _pid ID of the third party pool that requests minted rewards
    /// @return _rewardsGiven Amount of rewards minted to the third party pool
    function mintRewards(uint256 _pid) external returns (uint256 _rewardsGiven);

    /// @notice Allows user to deposit pool token to chef. Transfers rewards to user.
    /// @param _amount Amount of pool tokens to stake
    /// @param _pid Pool ID which indicates the type of token
    function deposit(uint256 _amount, uint256 _pid) external;

    /// @notice Withdraws pool token from chef. Transfers rewards to user.
    /// @param _amount Amount of pool tokens to withdraw.
    /// @param _pid Pool ID which indicates the type of token
    function withdraw(uint256 _amount, uint256 _pid) external;

    /// @notice Emergency withdraws all the pool tokens from chef. In this case there's no reward.
    /// @param _pid Pool ID which indicates the type of token
    function emergencyWithdraw(uint256 _pid) external;

    /// @notice Edits the pool multiplier and updates pools with new params
    /// @param _pidEdit Pool ID
    /// @param _pidMulEdit New multiplier
    function editPoolMult(
        uint256[] calldata _pidEdit,
        uint256[] calldata _pidMulEdit
    ) external;

    /// @notice Edits pool fee and updates pools with new params
    /// @param _pid Pool Id
    /// @param _fee New pool fee
    function editPoolFee(uint256 _pid, uint256 _fee) external;

    /// @notice Adds 1 to the amount of chains to which emissions are split
    /// This factor is used in the emissions calculation
    function addChain() external;

    // DESCRIPTION PENDING
    function editFeeAddress(address _feeReceiver, bool _isContract) external;

    event PoolAdded(
        address token,
        uint256 multiplier,
        uint256 fee,
        bool _type,
        uint256 _pid
    );

    //EVENTS

    /// NICE operations
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    /// Pool operations
    event UpdatePools(uint256[] pid, uint256[] mult);
    event UpdatePool(uint256 indexed pid, uint256 mult, uint256 fee);

    /// Emissions
    event UpdateEmissions(uint256 amount);

    /// Editing fee wallet address
    event FeeAddressEdit(address _newAddress, bool _isContract);

    ///
    event LogEvent(uint256 number, string data);
}
