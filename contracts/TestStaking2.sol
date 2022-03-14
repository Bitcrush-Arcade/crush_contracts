//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//BSC Address 0x87F8e8f9616689808176d3a97a506c8cEeD32674
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingTest {
    ERC20 public token;
    struct UserStaking {
        uint256 shares;
        uint256 stakedAmount;
        uint256 claimedAmount;
        uint256 lastBlockCompounded;
        uint256 lastBlockStaked;
        uint256 index;
        uint256 lastFrozenWithdraw;
        uint256 apyBaseline;
        uint256 profitBaseline;
    }

    mapping(address => UserStaking) public stakings;

    constructor(address _tokenAddress) {
        token = ERC20(_tokenAddress);
    }

    function addFunds(uint256 _amount) external {
        token.transferFrom(msg.sender, address(this), _amount);
        stakings[msg.sender].stakedAmount =
            stakings[msg.sender].stakedAmount +
            _amount;
    }
}
