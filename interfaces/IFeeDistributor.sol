// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IFeeDistributor {
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

    function swapForWrap(
        uint256 inputAmount,
        address[] storage path,
        FeeData storage feeInfo
    ) internal returns (uint256 amountLeft, uint256 wBnbReturned);

    function setBaseRouter(address _newRouter) external;

    function setBaseRouting(
        bool _isNice,
        address _liquidity,
        address[] calldata _path
    ) external;

    function setTeamWallet(address _newTeamW) external;
}
