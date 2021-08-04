//SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "./HouseBankroll.sol";

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
contract BitcrushLiveWallet is Ownable {
    using SafeMath for uint256;
    struct bet {
        //rename to balance
        uint256 bet;
        uint256 winnings;
    }
    //todo make a balanceOf function
    struct blackList {
        bool blacklisted;
    }
    mapping (address => blackList) public blacklistedUsers;
    //mapping of gameids to users address with bet amount
    mapping (uint256 => mapping (address => bet)) public betAmounts;
    //address of the crush token
    CRUSHToken public crush;
    BitcrushBankroll public bankroll;
    //todo dont deduct bet on winning
    // todo winnings added to live wallet

    
    event Withdraw (uint256 indexed _gameId, address indexed _address, uint256 indexed _amount);

    constructor (CRUSHToken _crush, BitcrushBankroll _bankroll) public{
        crush = _crush;
        bankroll = _bankroll;
    }

    function addbet (uint256 _amount, uint256 _gameId) public {
        //todo add validation for valid game id
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[msg.sender].blacklisted == false, "User is black Listed");
        crush.transferFrom(msg.sender, address(this), _amount);
        betAmounts[_gameId][msg.sender].bet = betAmounts[_gameId][msg.sender].bet.add(_amount);
        
    }

    function registerWin (uint256 _gameId,  uint256 _win, address _user) public onlyOwner {
        require(betAmounts[_gameId][_user].bet > 0, "No Bet Made");
        bankroll.payOutUserWinning(_win, _user, _gameId);
    }
    
    function registerLoss (uint256 _gameId, uint256 _bet, address _user) public onlyOwner {
        require(betAmounts[_gameId][_user].bet > 0, "No Bet Made");
        require(betAmounts[_gameId][_user].bet >= _bet, "amount greater than live wallet balance");
        transferToBankroll(_bet, _gameId);
        betAmounts[_gameId][msg.sender].bet = betAmounts[_gameId][msg.sender].bet.sub(_bet);
    }

    function transferToBankroll (uint256 _amount, uint256 _gameId) internal {
        crush.approve(address(bankroll), _amount);
        bankroll.addUserLoss(_amount, _gameId);       
    }

    function WithdrawBet(uint256 _gameId, uint256 _amount) public {
        require(betAmounts[_gameId][msg.sender].bet >= _amount, "bet less than amount withdraw");
        betAmounts[_gameId][msg.sender].bet = betAmounts[_gameId][msg.sender].bet.sub(_amount);
        crush.transfer(msg.sender, _amount);
        emit Withdraw(_gameId, msg.sender, _amount);
    }

    function addToUserWinnings (uint256 _gameId, uint256 _amount, address _user) public {
        require(msg.sender == address(bankroll),"Caller must be bankroll");
        betAmounts[_gameId][_user].winnings = betAmounts[_gameId][_user].winnings.add(_amount);

    }
    function withdrawWinnings (uint256 _gameId, uint256 _amount) public {
        require(betAmounts[_gameId][msg.sender].winnings >= _amount, "winnings less than amount withdraw");
        betAmounts[_gameId][msg.sender].winnings = betAmounts[_gameId][msg.sender].winnings.sub(_amount);
        crush.transfer(msg.sender, _amount);
    }

    function blacklistUser (address _address) public onlyOwner {
        blacklistedUsers[_address].blacklisted = true;
    }

    function whitelistUser (address _address) public onlyOwner {
        delete blacklistedUsers[_address];
    }

    function blacklistSelf () public  {
        blacklistedUsers[msg.sender].blacklisted = true;
    }

}