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
        uint256 lockTimeStamp;
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
    uint256 public lockPeriod = 10800;
    address public reserveAddress;
    uint256  public earlyWithdrawFee         = 50; // 50/10000 * 100 = 0.5% 
    
    event Withdraw (address indexed _address, uint256 indexed _amount);
    event Deposit (address indexed _address, uint256 indexed _amount);
    event LockPeriodUpdated (uint256 indexed _lockPeriod);

    constructor (CRUSHToken _crush, BitcrushBankroll _bankroll, address _reserveAddress) public{
        crush = _crush;
        bankroll = _bankroll;
        reserveAddress = _reserveAddress;
    }

    function addbet (uint256 _amount) public {
        
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[msg.sender].blacklisted == false, "User is black Listed");
        crush.transferFrom(msg.sender, address(this), _amount);
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.add(_amount);
        betAmounts[msg.sender].lockTimeStamp = block.timestamp;
        emit Deposit(msg.sender, _amount);
        
    }

    function addbetWithAddress (uint256 _amount, address _user) public {
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[_user].blacklisted == false, "User is black Listed");
        crush.transferFrom(msg.sender, address(this), _amount);
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);
        
    }

    function balanceOf ( address _user) public view returns (uint256){
        return betAmounts[_user].balance;
    }

    function registerWin (uint256[] memory _wins, address[] memory _users) public onlyOwner {
        require (_wins.length == _users.length, "Parameter lengths should be equal");
        for(uint256 i=0; i < _users.length; i++){
                bankroll.payOutUserWinning(_wins[i], _users[i]);
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

    function withdrawBet(uint256 _amount) public {
        require(betAmounts[msg.sender].balance >= _amount, "bet less than amount withdraw");
        require(betAmounts[msg.sender].lockTimeStamp == 0 || betAmounts[msg.sender].lockTimeStamp.add(lockPeriod) < block.timestamp, "Bet Amount locked, please try again later");
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.sub(_amount);
        crush.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function withdrawBetForUser(uint256 _amount, address _user) public onlyOwner {
        require(betAmounts[_user].balance >= _amount, "bet less than amount withdraw");
        betAmounts[_user].balance = betAmounts[_user].balance.sub(_amount);
        emit Withdraw(_user, _amount);
        uint256 withdrawalFee = _amount.mul(earlyWithdrawFee).div(DIVISOR);
        _amount = _amount.sub(withdrawalFee);
        crush.transfer(reserveAddress, withdrawalFee);
        crush.transfer(_user, _amount);
        
        
    }


    function addToUserWinnings (uint256 _amount, address _user) public {
        require(msg.sender == address(bankroll),"Caller must be bankroll");
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);

    }
    function updateBetLock (address[] memory _users) public {
        for(uint256 i=0; i < _users.length; i++){
            betAmounts[_users[i]].lockTimeStamp = block.timestamp;
        }
        
    }

    function releaseBetLock (address[] memory _users) public {
        for(uint256 i=0; i < _users.length; i++){
            betAmounts[_users[i]].lockTimeStamp = 0;
        }
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

    function setLossBurn(uint256 _lossBurn) public onlyOwner {
        require(_lossBurn > 0, "Loss burn cant be 0");
        lossBurn = _lossBurn;
    }
    function setLockPeriod (uint256 _lockPeriod) public onlyOwner {
        lockPeriod = _lockPeriod;
        emit LockPeriodUpdated(lockPeriod);
    }

    function setReserveAddress (address _reserveAddress) public onlyOwner {
        reserveAddress = _reserveAddress;
    }

    function setEarlyWithdrawFee (uint256 _earlyWithdrawFee ) public onlyOwner {
        earlyWithdrawFee = _earlyWithdrawFee;
    }
    function setBitcrushBankroll (BitcrushBankroll _bankRoll) public onlyOwner {
        bankroll = _bankRoll;
    }

}