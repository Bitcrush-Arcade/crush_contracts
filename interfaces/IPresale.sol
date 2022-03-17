// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPresale {
    /// @notice pause the presale
    function pauseSale() external;

    /// @notice qualify only checks quantity
    /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
    function qualify() external view returns (bool _isQualified);

    function setNiceToken(address _tokenAddress) external;

    /// @notice get the total Raised amount
    function totalRaised() external view returns (uint256 _total);

    /// @notice User info
    function userData()
        external
        view
        returns (
            uint256 _totalBought,
            uint256 _totalOwed,
            uint256 _totalClaimed
        );

    /// @notice Reserve NICE allocation with BUSD
    /// @param _amount Amount of BUSD to lock NICE amount
    /// @dev minimum of $100 BUSD, max of $5K BUSD
    /// @dev if maxRaise is exceeded we will allocate just a portion of that amount.
    function buyNice(uint256 _amount) external;

    ///
    function claimRaised() external;

    /// @notice function that gets available tokens to the user.
    /// @dev transfers NICE to the user directly by minting straight to their wallets
    function claimTokens() external;

    // EVENTS
    event WhitelistStarted(bool status);
    event SaleStarts(uint256 startBlock);
    event NiceBought(address indexed buyer, uint256 busd, uint256 nice);
    event NiceClaimed(address indexed buyer, uint256 amount);
    event LogEvent(uint256 data1, string data2);
}