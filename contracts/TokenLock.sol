// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IGalacticChef.sol";

contract TokenLock is Ownable {
    using SafeERC20 for IERC20;

    IGalacticChef public chef;
    uint256 public currentChains = 1;

    constructor(address _chef) {
        chef = IGalacticChef(_chef);
    }

    /// @notice claim Locked tokens in this contract.
    /// tokens are only claimable when new chains launch to migrate funds
    /// @param amount Amount to withdraw
    /// @param _liqToken Token to withdraw
    /// @param _chainChange Lock tokens in contract again until next change.
    function claimTokens(
        uint256 amount,
        address _liqToken,
        bool _chainChange
    ) external onlyOwner {
        require(chef.chains() > currentChains, "Liquidity locked");
        ERC20 token = ERC20(_liqToken);
        require(token.balanceOf(address(this)) > 0, "No funds");
        if (_chainChange) currentChains++;
        token.safeTransfer(msg.sender, amount);
    }
}
