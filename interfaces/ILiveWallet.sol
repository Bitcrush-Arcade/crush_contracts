// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;

import "../contracts/BankStaking.sol";

interface IBitcrushLiveWallet {
    /// add funds to the senders live wallet
    /// @dev adds funds to the sender user's live wallets
    function addbet(uint256 _amount) external;

    /// add funds to the provided users live wallet
    /// @dev adds funds to the specified users live wallets
    function addbetWithAddress(uint256 _amount, address _user) external;

    /// return the current balance of user in the live wallet
    /// @dev return current the balance of provided user addrss in the live wallet
    function balanceOf(address _user) external view returns (uint256);

    /// register wins for users in game with amounts
    /// @dev register wins for users during gameplay. wins are reported in aggregated form from the game server.
    function registerWin(uint256[] memory _wins, address[] memory _users)
        external;

    /// register loss for users in game with amounts
    /// @dev register loss for users during gameplay. loss is reported in aggregated form from the game server.
    function registerLoss(uint256[] memory _bets, address[] memory _users)
        external;

    /// withdraw funds from live wallet of the senders address
    /// @dev withdraw amount from users wallet if betlock isnt enabled
    function withdrawBet(uint256 _amount) external;

    /// owner only function to override timelock and withdraw funds on behalf of user
    /// @dev withdraw preapproved amount from users wallet sidestepping the timelock on withdrawals
    function withdrawBetForUser(uint256 _amount, address _user) external;

    /// add funds to the users live wallet on wins by either the bankroll or the staking pool
    /// @dev add funds to the users live wallet as winnings
    function addToUserWinnings(uint256 _amount, address _user) external;

    /// update the lockTimeStamp of provided users to current timestamp to prevent withdraws
    /// @dev update bet lock to prevent withdraws during gameplay
    function updateBetLock(address[] memory _users) external;

    /// update the lockTimeStamp of provided users to 0 to allow withdraws
    /// @dev update bet lock to allow withdraws after gameplay
    function releaseBetLock(address[] memory _users) external;

    /// blacklist specified address from adding more funds to the pool
    /// @dev prevent specified address from adding funds to the live wallet
    function blacklistUser(address _address) external;

    /// whitelist sender address from adding more funds to the pool
    /// @dev allow previously blacklisted sender address to add funds to the live wallet
    function whitelistUser(address _address) external;

    /// blacklist sender address from adding more funds to the pool
    /// @dev prevent sender address from adding funds to the live wallet
    function blacklistSelf() external;

    /// Store `_lockPeriod`.
    /// @param _lockPeriod the new value to store
    /// @dev stores the _lockPeriod in the state variable `lockPeriod`
    function setLockPeriod(uint256 _lockPeriod) external;

    /// Store `_reserveAddress`.
    /// @param _reserveAddress the new value to store
    /// @dev stores the _reserveAddress in the state variable `reserveAddress`
    function setReserveAddress(address _reserveAddress) external;

    /// Store `_earlyWithdrawFee`.
    /// @param _earlyWithdrawFee the new value to store
    /// @dev stores the _earlyWithdrawFee in the state variable `earlyWithdrawFee`
    function setEarlyWithdrawFee(uint256 _earlyWithdrawFee) external;

    /// Store `_stakingPool`.
    /// @param _stakingPool the new value to store
    /// @dev stores the _stakingPool address in the state variable `stakingPool`
    function setStakingPool(BitcrushStaking _stakingPool) external;
}
