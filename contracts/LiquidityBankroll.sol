//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "./TokenLiveWallet.sol";

contract BitcrushLiquidityBankroll is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for BEP20;
    mapping (address => uint256) public bankroll;
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

    constructor( address _admin) public {
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
    function addToBankroll(uint256 _amount, address _token) public adminOnly {
        BEP20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bankroll[_token] = bankroll[_token].add(_amount);
    }

    /// Add users loss to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll if bankroll is in positive, otherwise its transfered to the staking pool to recover frozen funds
    function addUserLoss(uint256 _amount, address _token) public {
        BEP20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        bankroll[_token] = bankroll[_token].add(_amount);
    }


    /// Deduct users win from the bankroll
    /// @param _amount the amount to deduct
    /// @dev deducts funds from the bankroll if bankroll is in positive, otherwise theyre pulled from staking pool and bankroll marked as negative
    function payOutUserWinning(uint256 _amount, address _winner, address _token) public {
        require(
            authorizedAddresses[msg.sender] == true,
            "Caller must be authorized"
        );
        transferWinnings(_amount, _winner, msg.sender, _token);
        bankroll[_token] = bankroll[_token].sub(_amount);
    }
    /// transfer winnings from bankroll contract to live wallet
    /// @param _amount the amount to tranfer
    /// @param _winner the winners address
    /// @dev transfers funds from the bankroll to the live wallet as users winnings
    function transferWinnings(
        uint256 _amount,
        address _winner,
        address _lwAddress,
        address _token
    ) internal {
        BEP20(_token).safeTransfer(_lwAddress, _amount);
        BitcrushTokenLiveWallet currentLw = BitcrushTokenLiveWallet( _lwAddress);
        currentLw.addToUserWinningsNative(_amount, _winner);
    }
    /// return the current balance of user in the live wallet
    /// @dev return current the balance of provided user addrss in the live wallet
    function balance(address _token) public view returns (uint256) {
        return bankroll[_token];
    }

    ///store new address in admin address
    /// @param _admin the new address to store
    /// @dev changes the address which is used by the adminOnly modifier
    function setAdmin(address _admin) public onlyOwner {
        admin = _admin;
    }

    function withdrawAllFunds (address _token)public onlyOwner {
        BEP20(_token).safeTransfer(msg.sender, bankroll[_token]);
    }
}
