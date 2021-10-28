//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "./HouseBankroll.sol";
import "./staking.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
contract BitcrushLiveWallet is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for CRUSHToken;
    struct wallet {
        //rename to balance
        uint256 balance;
        uint256 lockTimeStamp;
    }
    
    
    mapping (address => bool) public blacklistedUsers;
    //mapping users address with bet amount
    mapping (address => wallet) public betAmounts;
    
    //address of the crush token
    CRUSHToken public immutable crush;
    BitcrushBankroll public bankroll;
    BitcrushStaking public stakingPool;
    
    
    uint256 constant public DIVISOR = 10000;
    uint256 public lockPeriod = 10800;
    address public reserveAddress;
    uint256  public earlyWithdrawFee         = 50; // 50/10000 * 100 = 0.5% 
    
    event Withdraw (address indexed _address, uint256 indexed _amount);
    event Deposit (address indexed _address, uint256 indexed _amount);
    event LockPeriodUpdated (uint256 indexed _lockPeriod);

    constructor (CRUSHToken _crush, BitcrushBankroll _bankroll, address _reserveAddress) public {
        crush = _crush;
        bankroll = _bankroll;
        reserveAddress = _reserveAddress;
    }

    /// add funds to the senders live wallet 
    /// @dev adds funds to the sender user's live wallets
    function addbet (uint256 _amount) public {
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[msg.sender] == false, "User is black Listed");
        crush.safeTransferFrom(msg.sender, address(this), _amount);
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.add(_amount);
        betAmounts[msg.sender].lockTimeStamp = block.timestamp;
        emit Deposit(msg.sender, _amount);
        
    }

    /// add funds to the provided users live wallet 
    /// @dev adds funds to the specified users live wallets
    function addbetWithAddress (uint256 _amount, address _user) public {
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[_user] == false, "User is black Listed");
        crush.safeTransferFrom(msg.sender, address(this), _amount);
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);
        betAmounts[_user].lockTimeStamp = block.timestamp;
        emit Deposit(_user, _amount);
    }

    /// return the current balance of user in the live wallet
    /// @dev return current the balance of provided user addrss in the live wallet
    function balanceOf ( address _user) public view returns (uint256){
        return betAmounts[_user].balance;
    }

    /// register wins for users in game with amounts
    /// @dev register wins for users during gameplay. wins are reported in aggregated form from the game server.
    function registerWin (uint256[] memory _wins, address[] memory _users) public onlyOwner {
        require (_wins.length == _users.length, "Parameter lengths should be equal");
        for(uint256 i=0; i < _users.length; i++){
                bankroll.payOutUserWinning(_wins[i], _users[i]);
        }
    }
    
    /// register loss for users in game with amounts
    /// @dev register loss for users during gameplay. loss is reported in aggregated form from the game server.
    function registerLoss (uint256[] memory _bets, address[] memory _users) public onlyOwner {
        require (_bets.length == _users.length, "Parameter lengths should be equal");
        for(uint256 i=0; i < _users.length; i++){
            if(_bets[i] > 0){
            transferToBankroll(_bets[i]);
            betAmounts[_users[i]].balance = betAmounts[_users[i]].balance.sub(_bets[i]);
            }
            
        }
    }

    /// transfer funds from live wallet to the bankroll on user loss
    /// @dev transfer funds to the bankroll contract when users lose in game
    function transferToBankroll (uint256 _amount) internal { 
        crush.approve(address(bankroll), _amount);
        bankroll.addUserLoss(_amount);       
    }

    /// withdraw funds from live wallet of the senders address
    /// @dev withdraw amount from users wallet if betlock isnt enabled
    function withdrawBet(uint256 _amount) public {
        require(betAmounts[msg.sender].balance >= _amount, "bet less than amount withdraw");
        require(betAmounts[msg.sender].lockTimeStamp == 0 || betAmounts[msg.sender].lockTimeStamp.add(lockPeriod) < block.timestamp, "Bet Amount locked, please try again later");
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.sub(_amount);
        crush.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /// owner only function to override timelock and withdraw funds on behalf of user
    /// @dev withdraw preapproved amount from users wallet sidestepping the timelock on withdrawals
    function withdrawBetForUser(uint256 _amount, address _user) public onlyOwner {
        require(betAmounts[_user].balance >= _amount, "bet less than amount withdraw");
        betAmounts[_user].balance = betAmounts[_user].balance.sub(_amount);
        emit Withdraw(_user, _amount);
        uint256 withdrawalFee = _amount.mul(earlyWithdrawFee).div(DIVISOR);
        _amount = _amount.sub(withdrawalFee);
        crush.safeTransfer(reserveAddress, withdrawalFee);
        crush.safeTransfer(_user, _amount);
        
        
    }

    /// add funds to the users live wallet on wins by either the bankroll or the staking pool
    /// @dev add funds to the users live wallet as winnings
    function addToUserWinnings (uint256 _amount, address _user) public {
        require(msg.sender == address(bankroll)  || msg.sender == address(stakingPool) ,"Caller must be bankroll or staking pool");
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);

    }
    
    /// update the lockTimeStamp of provided users to current timestamp to prevent withdraws
    /// @dev update bet lock to prevent withdraws during gameplay
    function updateBetLock (address[] memory _users) public onlyOwner {
        for(uint256 i=0; i < _users.length; i++){
            betAmounts[_users[i]].lockTimeStamp = block.timestamp;
        }
        
    }
    /// update the lockTimeStamp of provided users to 0 to allow withdraws
    /// @dev update bet lock to allow withdraws after gameplay
    function releaseBetLock (address[] memory _users) public onlyOwner {
        for(uint256 i=0; i < _users.length; i++){
            betAmounts[_users[i]].lockTimeStamp = 0;
        }
    }

    /// blacklist specified address from adding more funds to the pool
    /// @dev prevent specified address from adding funds to the live wallet
    function blacklistUser (address _address) public onlyOwner {
        blacklistedUsers[_address] = true;
    }

    /// whitelist sender address from adding more funds to the pool
    /// @dev allow previously blacklisted sender address to add funds to the live wallet
    function whitelistUser (address _address) public onlyOwner {
        delete blacklistedUsers[_address];
    }

    /// blacklist sender address from adding more funds to the pool
    /// @dev prevent sender address from adding funds to the live wallet
    function blacklistSelf () public  {
        blacklistedUsers[msg.sender] = true;
    }


    /// Store `_lockPeriod`.
    /// @param _lockPeriod the new value to store
    /// @dev stores the _lockPeriod in the state variable `lockPeriod`
    function setLockPeriod (uint256 _lockPeriod) public onlyOwner {
        require(_lockPeriod <= 604800, "Lock period cannot be greater than 1 week");
        lockPeriod = _lockPeriod;
        emit LockPeriodUpdated(lockPeriod);
    }

    /// Store `_reserveAddress`.
    /// @param _reserveAddress the new value to store
    /// @dev stores the _reserveAddress in the state variable `reserveAddress`
    function setReserveAddress (address _reserveAddress) public onlyOwner {
        reserveAddress = _reserveAddress;
    }

    /// Store `_earlyWithdrawFee`.
    /// @param _earlyWithdrawFee the new value to store
    /// @dev stores the _earlyWithdrawFee in the state variable `earlyWithdrawFee`
    function setEarlyWithdrawFee (uint256 _earlyWithdrawFee ) public onlyOwner {
        require(_earlyWithdrawFee < 4000, "Early withdraw fee must be less than 40%");
        earlyWithdrawFee = _earlyWithdrawFee;
    }

    /// Store `_bankRoll`.
    /// @param _bankRoll the new value to store
    /// @dev stores the _bankRoll address in the state variable `bankroll`
    function setBitcrushBankroll (BitcrushBankroll _bankRoll) public onlyOwner {
        bankroll = _bankRoll;
    }

    /// Store `_stakingPool`.
    /// @param _stakingPool the new value to store
    /// @dev stores the _stakingPool address in the state variable `stakingPool`
    function setStakingPool (BitcrushStaking _stakingPool) public onlyOwner {
        stakingPool = _stakingPool;
    }

}