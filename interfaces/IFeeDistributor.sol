// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IFeeDistributor {
    function feeInfo(uint256 _pid)
        external
        returns (
            uint256[3] memory niceFees,
            uint256[5] memory crushFees,
            bool initialized, // Fail transactions where fees have not been added
            bool hasFees, // If token charges fees on transfers need to use swapTokensForEthSupportingFeesOnTransferToken function instead
            bool token0Fees, // FOR LP IN CASE IT HAS FEES
            bool token1Fees, // FOR LP IN CASE ITS TOKEN HAS FEES
            /**
            if it's an LP token we need to remove that Liquidity
            else it's a Single asset token and have to swap it for core ETH (BNB)
            before buying anything else.
        **/
            address router // main router for this token
        );

    function addorEditFee(
        uint256[5] calldata _fees, // 0 pid, 1 buyback, 2 liquidity, 3 team, 4 slippage
        bool _bbNice,
        bool _liqNice,
        address router,
        address[] calldata _tokens,
        address[] calldata _token0Path,
        address[] calldata _token1Path
    ) external;

    /// @notice Function that distributes fees to the respective flows
    /// @dev This function requires funds to be sent beforehand to this contract
    function receiveFees(uint256 _pid, uint256 _amount) external;

    /// @notice Check that current Nice Price is above IDO
    /// @dev 
    function checkPrice() external view returns (bool _aboveIDO);

    function setBaseRouter(address _newRouter) external;

    function setBaseRouting(
        bool _isNice,
        address _liquidity,
        address[] calldata _path
    ) external;

    function setTeamWallet(address _newTeamW) external;

    //EVENTS

    // Adding or editing fee
    event AddPoolFee(uint256 indexed _pid);

    // Unused
    event EditFee(uint256 indexed _pid, uint256 bb, uint256 liq, uint256 team);

    // Unused/duplicated
    event UpdateRouter(uint256 indexed _pid, address router);

    // Unused
    event UpdatePath(uint256 indexed _pid, address router);

    // Setting team wallet
    event UpdateTeamWallet(address _teamW);

    // Setting router address
    event UpdateRouter(address _router);

    // Setting base routing
    event UpdateCore(bool isNice, address liquidity, uint256 pathSize);
}
