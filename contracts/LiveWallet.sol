//SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "./HouseBankroll.sol";

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
contract BitcrushLiveWallet is Ownable {
    using SafeMath for uint256;
    struct wallet {
        //rename to balance
        uint256 balance;
        //uint256 winnings;
    }
    
    struct blackList {
        bool blacklisted;
    }
    mapping (address => blackList) public blacklistedUsers;
    //mapping users address with bet amount
    mapping (address => wallet) public betAmounts;
    
    //address of the crush token
    CRUSHToken public crush;
    BitcrushBankroll public bankroll;
    
    uint256 public lossBurn = 10;
    uint256 constant public DIVISOR = 10000;

    
    event Withdraw (address indexed _address, uint256 indexed _amount);

    constructor (CRUSHToken _crush, BitcrushBankroll _bankroll) public{
        crush = _crush;
        bankroll = _bankroll;
    }

    function addbet (uint256 _amount) public {
        
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[msg.sender].blacklisted == false, "User is black Listed");
        crush.transferFrom(msg.sender, address(this), _amount);
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.add(_amount);
        
    }

    function addbetWithAddress (uint256 _amount, address _user) public {
        //todo add validation for valid game id
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[_user].blacklisted == false, "User is black Listed");
        crush.transferFrom(_user, address(this), _amount);
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);
        
    }

    function balanceOf ( address _user) public view returns (uint256){
        return betAmounts[_user].balance;
    }

    function registerWin (uint256[] memory _wins, address[] memory _users) public onlyOwner {
        require (_wins.length == _users.length, "Parameter lengths should be equal");
        for(uint256 i=0; i < _users.length; i++){
            if(betAmounts[_users[i]].balance > 0){
                bankroll.payOutUserWinning(_wins[i], _users[i]);
            }
        }
    }
    
    function registerLoss (uint256[] memory _bets, address[] memory _users) public onlyOwner {
        require (_bets.length == _users.length, "Parameter lengths should be equal");
        for(uint256 i=0; i < _users.length; i++){
            if(_bets[i] > 0){
            transferToBankroll(_bets[i]);
            betAmounts[_users[i]].balance = betAmounts[_users[i]].balance.sub(_bets[i]);
            }
            
        }
    }

    function transferToBankroll (uint256 _amount) internal {
        uint256 burnShare = _amount.mul(lossBurn).div(DIVISOR);
        crush.burn(burnShare);
        uint256 remainingAmount = _amount.sub(burnShare);
        crush.approve(address(bankroll), remainingAmount);
        bankroll.addUserLoss(remainingAmount);       
    }

    function WithdrawBet(uint256 _amount) public {
        require(betAmounts[msg.sender].balance >= _amount, "bet less than amount withdraw");
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.sub(_amount);
        crush.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function addToUserWinnings (uint256 _amount, address _user) public {
        require(msg.sender == address(bankroll),"Caller must be bankroll");
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);

    }
    /* function withdrawWinnings (uint256 _gameId, uint256 _amount) public {
        require(betAmounts[_gameId][msg.sender].winnings >= _amount, "winnings less than amount withdraw");
        betAmounts[_gameId][msg.sender].winnings = betAmounts[_gameId][msg.sender].winnings.sub(_amount);
        crush.transfer(msg.sender, _amount);
    } */

    function blacklistUser (address _address) public onlyOwner {
        blacklistedUsers[_address].blacklisted = true;
    }

    function whitelistUser (address _address) public onlyOwner {
        delete blacklistedUsers[_address];
    }

    function blacklistSelf () public  {
        blacklistedUsers[msg.sender].blacklisted = true;
    }

    function setLossBurn(uint256 _lossBurn) public onlyOwner {
        require(_lossBurn > 0, "Loss burn cant be 0");
        lossBurn = _lossBurn;
    }

}