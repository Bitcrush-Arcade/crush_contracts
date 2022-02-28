//SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IStaking {
    function compoundAll() external;

    function totalShares() external returns (uint256 totalShares);

    function stakings(address) external returns (
            uint256 shares,
            uint256 stakedAmount,
            uint256 claimedAmount,
            uint256 lastBlockCompounded,
            uint256 lastBlockStaked,
            uint256 index,
            uint256 lastFrozenWithdraw,
            uint256 apyBaseline,
            uint256 profitBaseline
        );
    function batchStartingIndex() external returns (uint256 batchStartingIndex);
    
    function indexesLength() external returns (uint256 _length);
    
    function autoCompoundLimit() external returns (uint256 autoCompoundLimit);
    
    function addressIndexes(uint256 index) external returns (address _address);


}
