// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;

interface IBitcrushBankroll {
    /// authorize address to register wins and losses
    /// @param _address the address to be authorized
    /// @dev updates the authorizedAddresses mapping to true for given address
    function authorizeAddress(address _address) external;

    /// remove authorization of an address from register wins and losses
    /// @param _address the address to be removed
    /// @dev updates the authorizedAddresses mapping by deleting entry for given address
    function removeAuthorization(address _address) external;

    /// Add funds to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll
    function addToBankroll(uint256 _amount) external;

    /// Add users loss to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll if bankroll is in positive, otherwise its transfered to the staking pool to recover frozen funds
    function addUserLoss(uint256 _amount) external;

    /// DESCRIPTION PENDING
    function recoverBankroll(uint256 _amount) external;

    /// Deduct users win from the bankroll
    /// @param _amount the amount to deduct
    /// @dev deducts funds from the bankroll if bankroll is in positive, otherwise theyre pulled from staking pool and bankroll marked as negative
    function payOutUserWinning(uint256 _amount, address _winner) external;

    /// transfer profits to staking pool to be ditributed to stakers.
    /// @dev transfer profits since last compound to the staking pool while taking out necessary fees.
    function transferProfit() external returns (uint256);

    /// Store `_threshold`.
    /// @param _threshold the new value to store
    /// @dev stores the _threshold address in the state variable `profitThreshold`
    function setProfitThreshold(uint256 _threshold) external;

    /// updates all share percentage values
    /// @param _houseBankrollShare the new value to store
    /// @param _profitShare the new value to store
    /// @param _lotteryShare the new value to store
    /// @param _reserveShare the new value to store
    /// @dev stores the _houseBankrollShare address in the state variable `houseBankrollShare`
    function setShares(
        uint256 _houseBankrollShare,
        uint256 _profitShare,
        uint256 _lotteryShare,
        uint256 _reserveShare
    ) external;

    ///store new address in reserve address
    /// @param _reserve the new address to store
    /// @dev changes the address which recieves reserve fees
    function setReserveAddress(address _reserve) external;

    ///store new address in lottery address
    /// @param _lottery the new address to store
    /// @dev changes the address which recieves lottery fees
    function setLotteryAddress(address _lottery) external;

    ///store new address in admin address
    /// @param _admin the new address to store
    /// @dev changes the address which is used by the adminOnly modifier
    function setAdmin(address _admin) external;

    // EVENTS

    /// Event for the SetShares Function
    event SharesUpdated(
        uint256 _houseBankrollShare,
        uint256 _profitShare,
        uint256 _lotteryShare,
        uint256 _reserveShare
    );
}
