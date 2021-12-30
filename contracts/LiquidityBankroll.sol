//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "./LiveWallet.sol";

contract BitcrushLiquidityBankroll is Ownable {
    using SafeMath for uint256;

    using SafeBEP20 for BEP20;
    uint256 public totalBankroll;
    BEP20 public immutable token;
    address admin;
    // MODIFIERS
    modifier adminOnly() {
        require(
            msg.sender == address(admin),
            "Access restricted to admin only"
        );
        _;
    }

    //authorized addresses
    mapping(address => bool) public authorizedAddresses;

    constructor(BEP20 _token, address _admin) public {
        token = _token;
        admin = _admin;
    }

    /// authorize address to register wins and losses
    /// @param _address the address to be authorized
    /// @dev updates the authorizedAddresses mapping to true for given address
    function authorizeAddress(address _address) public onlyOwner {
        authorizedAddresses[_address] = true;
    }

    /// remove authorization of an address from register wins and losses
    /// @param _address the address to be removed
    /// @dev updates the authorizedAddresses mapping by deleting entry for given address
    function removeAuthorization(address _address) public onlyOwner {
        delete authorizedAddresses[_address];
    }

    /// Add funds to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll
    function addToBankroll(uint256 _amount) public adminOnly {
        token.safeTransferFrom(msg.sender, address(this), _amount);
        totalBankroll = totalBankroll.add(_amount);
    }

    /// Add users loss to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll if bankroll is in positive, otherwise its transfered to the staking pool to recover frozen funds
    function addUserLoss(uint256 _amount) public {
        token.safeTransferFrom(msg.sender, address(this), _amount);
        totalBankroll = totalBankroll.add(_amount);
    }

    /// Deduct users win from the bankroll
    /// @param _amount the amount to deduct
    /// @dev deducts funds from the bankroll if bankroll is in positive, otherwise theyre pulled from staking pool and bankroll marked as negative
    function payOutUserWinning(uint256 _amount, address _winner) public {
        require(
            authorizedAddresses[msg.sender] == true,
            "Caller must be authorized"
        );
        transferWinnings(_amount, _winner, msg.sender);
        totalBankroll = totalBankroll.sub(_amount);
    }
    /// transfer winnings from bankroll contract to live wallet
    /// @param _amount the amount to tranfer
    /// @param _winner the winners address
    /// @dev transfers funds from the bankroll to the live wallet as users winnings
    function transferWinnings(
        uint256 _amount,
        address _winner,
        address _lwAddress
    ) internal {
        token.safeTransfer(_lwAddress, _amount);
        BitcrushLiveWallet currentLw = BitcrushLiveWallet( _lwAddress);
        currentLw.addToUserWinnings(_amount, _winner);
    }
    /// return the current balance of user in the live wallet
    /// @dev return current the balance of provided user addrss in the live wallet
    function balance() public view returns (uint256) {
        return totalBankroll;
    }

    ///store new address in admin address
    /// @param _admin the new address to store
    /// @dev changes the address which is used by the adminOnly modifier
    function setAdmin(address _admin) public onlyOwner {
        admin = _admin;
    }
}
