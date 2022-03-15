// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPrevSale {
    /// @notice qualify only checks quantity
    /// @dev qualify is an overlook of the amount of CrushGod NFTs held and tokens staked
    function qualify() external view returns (bool _isQualified);

    /// @notice user will need to self whitelist prior to the sale
    /// @param tokenId the NFT Id to register with
    /// @dev once whitelisted, the token locked to that wallet.
    function whitelistSelf(uint256 tokenId) external;

    function setNiceToken(address _tokenAddress) external;

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

    /// @notice get claimable percentage after sale end
    /// @return _avail percentage available to claim
    /// @dev this function checks if time has passed to set the max amount claimable
    function availableAmount() external view returns (uint256 _avail);
}
