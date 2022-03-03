// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IFeeDistributor{
  function receiveFees(uint _pid, uint _amount) external;
}