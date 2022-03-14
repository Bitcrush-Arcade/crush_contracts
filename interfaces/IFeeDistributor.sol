// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IFeeDistributor {
    function receiveFees(uint256 _pid, uint256 _amount) external;
}
