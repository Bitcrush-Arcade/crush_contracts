//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "./HouseBankroll.sol";
import "./LiquidityBankroll.sol";
import "./staking.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "./libraries/IApeRouter02.sol";
contract BitcrushTokenLiveWallet is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for BEP20;
    using SafeBEP20 for CRUSHToken;

     IApeRouter02 public immutable swapRouter;

    struct wallet {
        uint256 balance;
        uint256 lockTimeStamp;
        uint256 amountToBorrow;
    }
    
    
    mapping (address => bool) public blacklistedUsers;
    //mapping users address with bet amount
    mapping (address => wallet) public betAmounts;
    
    //address of the crush token
    BEP20 public immutable token;
    CRUSHToken public immutable crush;
    BitcrushBankroll public immutable bankroll;
    BitcrushStaking public stakingPool;
    BitcrushLiquidityBankroll public liquidityBankroll;
    
    
    uint256 constant public DIVISOR = 10000;
    uint256 public lockPeriod = 10800;
    address public reserveAddress;
    uint256 public earlyWithdrawFee = 50; // 50/10000 * 100 = 0.5% 
    
    uint256 public borrowedCrush;
    uint256 public bankrollShare = 6000;
    uint256 public partnerShare = 2000;
    uint256 public reserveShare = 1000;
    uint256 public pendingBankroll;
    uint256 public pendingBakrollThreshold = 10000000000000000000000;
    uint256 public slipage = 100;

    address tokenPartner;

    event Withdraw (address indexed _address, uint256 indexed _amount);
    event Deposit (address indexed _address, uint256 indexed _amount);
    event DepositWin (address indexed _address, uint256 indexed _amount);
    event LockPeriodUpdated (uint256 indexed _lockPeriod);

    constructor (BEP20 _token, CRUSHToken _crush, BitcrushBankroll _bankroll, address _reserveAddress, IApeRouter02 _swapRouter, BitcrushLiquidityBankroll _liquidityBankroll, address _tokenPartner) public {
        token = _token;
        crush = _crush;
        bankroll = _bankroll;
        reserveAddress = _reserveAddress;
        swapRouter = _swapRouter;
        liquidityBankroll = _liquidityBankroll;
        tokenPartner = _tokenPartner;
        
    }

    /// add funds to the senders live wallet 
    /// @dev adds funds to the sender user's live wallets
    function addbet (uint256 _amount) public {
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[msg.sender] == false, "User is black Listed");
        token.safeTransferFrom(msg.sender, address(this), _amount);
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.add(_amount);
        betAmounts[msg.sender].lockTimeStamp = block.timestamp;
        emit Deposit(msg.sender, _amount);
        
    }

    /// add funds to the provided users live wallet 
    /// @dev adds funds to the specified users live wallets
    function addbetWithAddress (uint256 _amount, address _user) public {
        require(_amount > 0, "Bet amount should be greater than 0");
        require(blacklistedUsers[_user] == false, "User is black Listed");
        token.safeTransferFrom(msg.sender, address(this), _amount);
        betAmounts[_user].balance = betAmounts[_user].balance.add(_amount);
        betAmounts[_user].lockTimeStamp = block.timestamp;
        emit DepositWin(_user, _amount);
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
                if(_wins[i] <= liquidityBankroll.balance(address(token))){
                    liquidityBankroll.payOutUserWinning(_wins[i], _users[i],address(token));
                }else {
                    //win is greater than reserves, add to be borrowed
                    uint256 balanceInReserve = liquidityBankroll.balance(address(token));
                    uint256 difference = _wins[i].sub(balanceInReserve);
                    liquidityBankroll.payOutUserWinning(balanceInReserve, _users[i],address(token));
                    betAmounts[_users[i]].balance = betAmounts[_users[i]].balance.add(_wins[i].sub(balanceInReserve));
                    betAmounts[_users[i]].amountToBorrow = betAmounts[_users[i]].amountToBorrow.add(difference);
                }
        }
    }
    
    /// register loss for users in game with amounts
    /// @dev register loss for users during gameplay. loss is reported in aggregated form from the game server.
    function registerLoss (uint256[] memory _bets, address[] memory _users) public onlyOwner {
        require (_bets.length == _users.length, "Parameter lengths should be equal");
        for(uint256 i=0; i < _users.length; i++){
            if(_bets[i] > 0){
            require(betAmounts[_users[i]].balance >= _bets[i], "Loss bet amount is greater than available balance");    
            transferToBankroll(_bets[i]);
            betAmounts[_users[i]].balance = betAmounts[_users[i]].balance.sub(_bets[i]);
            }
            
        }
    }

    /// transfer funds from live wallet to the bankroll on user loss
    /// @dev transfer funds to the bankroll contract when users lose in game
    function transferToBankroll (uint256 _amount) internal { 
        //todo check if bankroll is in negative, if yes trasnfer all, if more than needed then compute required and then do a 60/40 split betweek bankroll and liquidity bankroll
        if(borrowedCrush > 0){
            //send all to bankroll
            address[] memory  tmp = new address[](2);
            tmp[0] = address(token);
            tmp[1] = address(crush);
            uint256[] memory amount = swapRouter.getAmountsOut(_amount, tmp);
            uint256 amountAdjusted = amount[1].sub(amount[1].mul(slipage).div(DIVISOR));
            if(amountAdjusted > borrowedCrush){
                //divide spillover between both bankrolls
                uint256[] memory requiredAmount = swapRouter.getAmountsIn(borrowedCrush, tmp);
                uint256 requiredAmountAdjusted = requiredAmount[1].add(requiredAmount[1].mul(slipage).div(DIVISOR));
                if(requiredAmountAdjusted > _amount){
                    //swap required amount and send to bankroll, send rest to liquidity
                    token.approve(address(swapRouter), requiredAmountAdjusted);
                    uint256[] memory amountSwapped = swapRouter.swapExactTokensForTokens(requiredAmountAdjusted, requiredAmount[0], tmp, address(this), block.timestamp+5);
                    crush.approve(address(bankroll), amountSwapped[1]);
                    bankroll.addUserLoss(amountSwapped[1]);
                    
                    //do partner split here
                    _amount = _amount.sub(requiredAmountAdjusted);
                    uint256 bankrollAmount = _amount.mul(bankrollShare).div(DIVISOR);
                    pendingBankroll = pendingBankroll.add(bankrollAmount);
                    uint256 reserveLiquidity = _amount.mul(reserveShare).div(DIVISOR);
                    uint256 partnerShareToBePaid = _amount.mul(partnerShare).div(DIVISOR);
                    _amount = _amount.sub(bankrollAmount);
                    _amount = _amount.sub(reserveLiquidity);
                    _amount = _amount.sub(partnerShareToBePaid);

                    token.approve(address(liquidityBankroll), reserveLiquidity);
                    liquidityBankroll.addUserLoss(reserveLiquidity,address(token));
                    token.safeTransfer(tokenPartner, partnerShareToBePaid);
                    token.safeTransfer(reserveAddress, _amount);
                    
                    token.approve(address(liquidityBankroll), _amount.sub(requiredAmountAdjusted));
                    liquidityBankroll.addUserLoss(_amount.sub(requiredAmountAdjusted),address(token));       

                }
                

            } else {
                token.approve(address(swapRouter), _amount);
                uint256[] memory amountSwapped = swapRouter.swapExactTokensForTokens(_amount, amountAdjusted, tmp, address(this), block.timestamp+5);
                crush.approve(address(bankroll), amountSwapped[1]);
                bankroll.addUserLoss(amountSwapped[1]);
                borrowedCrush = borrowedCrush.sub(amountSwapped[1]);
            }

        }else {
            uint256 bankrollAmount = _amount.mul(bankrollShare).div(DIVISOR);
            pendingBankroll = pendingBankroll.add(bankrollAmount);
            if(pendingBankroll >= pendingBakrollThreshold){
                //execute swap and transfer
                address[] memory  tmp = new address[](2);
                tmp[0] = address(token);
                tmp[1] = address(crush);
                
                uint256[] memory amount = swapRouter.getAmountsOut(pendingBankroll, tmp);
                uint256 amountAdjusted = amount[1].sub(amount[1].mul(slipage).div(DIVISOR));
                token.approve(address(swapRouter), pendingBankroll);
                uint256[] memory amountSwapped = swapRouter.swapExactTokensForTokens(pendingBankroll, amountAdjusted, tmp, address(this), block.timestamp+5);
                crush.approve(address(bankroll), amountSwapped[1]);
                bankroll.addUserLoss(amountSwapped[1]);
                pendingBankroll = 0;
                
            }
            //do partner splits here
            uint256 reserveLiquidity = _amount.mul(reserveShare).div(DIVISOR);
            uint256 partnerShareToBePaid = _amount.mul(partnerShare).div(DIVISOR);
            _amount = _amount.sub(bankrollAmount);
            _amount = _amount.sub(reserveLiquidity);
            _amount = _amount.sub(partnerShareToBePaid);

            token.approve(address(liquidityBankroll), reserveLiquidity);
            liquidityBankroll.addUserLoss(reserveLiquidity,address(token));
            token.safeTransfer(tokenPartner, partnerShareToBePaid);
            token.safeTransfer(reserveAddress, _amount);
            

        }
        
    }

    /// withdraw funds from live wallet of the senders address
    /// @dev withdraw amount from users wallet if betlock isnt enabled
    function withdrawBet(uint256 _amount) public {
        require(betAmounts[msg.sender].balance >= _amount, "bet less than amount withdraw");
        require(betAmounts[msg.sender].lockTimeStamp == 0 || betAmounts[msg.sender].lockTimeStamp.add(lockPeriod) < block.timestamp, "Bet Amount locked, please try again later");
        if(betAmounts[msg.sender].balance.sub(betAmounts[msg.sender].amountToBorrow) < _amount){
            fetchAmountOwed(_amount, msg.sender);
        }
        betAmounts[msg.sender].balance = betAmounts[msg.sender].balance.sub(_amount);
        token.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /// owner only function to override timelock and withdraw funds on behalf of user
    /// @dev withdraw preapproved amount from users wallet sidestepping the timelock on withdrawals
    function withdrawBetForUser(uint256 _amount, address _user) public onlyOwner {
        require(betAmounts[_user].balance >= _amount, "bet less than amount withdraw");
        if(betAmounts[msg.sender].balance.sub(betAmounts[msg.sender].amountToBorrow) < _amount){
            fetchAmountOwed(_amount, msg.sender);
        }
        betAmounts[_user].balance = betAmounts[_user].balance.sub(_amount);
        fetchAmountOwed(_amount, _user);
        emit Withdraw(_user, _amount);
        uint256 withdrawalFee = _amount.mul(earlyWithdrawFee).div(DIVISOR);
        _amount = _amount.sub(withdrawalFee);
        token.safeTransfer(reserveAddress, withdrawalFee);
        token.safeTransfer(_user, _amount);
    }

    function fetchAmountOwed (uint256 _amount, address _winner) internal {
        //register loss in crush bankroll for required amount;
        address[] memory  tmp = new address[](2);
        tmp[0] = address(crush);
        tmp[1] = address(token);
        uint256[] memory requiredAmount = swapRouter.getAmountsIn(_amount, tmp);
        uint256 requiredAmountAdjusted = requiredAmount[0].add(requiredAmount[0].mul(slipage).div(DIVISOR));
        bankroll.payOutUserWinning(requiredAmountAdjusted, _winner);
        
    }

    /// add funds to the users live wallet on wins by either the bankroll or the staking pool
    /// @dev add funds to the users live wallet as winnings
    function addToUserWinnings (uint256 _amount, address _user) public {
        //todo change to liquidity bankroll
        require(msg.sender == address(bankroll)  || msg.sender == address(stakingPool) ,"Caller must be bankroll or staking pool");
        //swap for token
        address[] memory  tmp = new address[](2);
        tmp[0] = address(crush);
        tmp[1] = address(token);
        crush.approve(address(swapRouter), _amount);
        uint256[] memory swappedAmount = swapRouter.swapExactTokensForTokens(_amount, betAmounts[_user].amountToBorrow, tmp, address(this), block.timestamp+5);
        
        if(swappedAmount[1] > betAmounts[_user].amountToBorrow){
            token.approve(address(liquidityBankroll), swappedAmount[1].sub(betAmounts[_user].amountToBorrow));
            liquidityBankroll.addUserLoss(swappedAmount[1].sub(betAmounts[_user].amountToBorrow), address(token));
        }
        betAmounts[_user].amountToBorrow = 0;
    }

    /// add funds to the users live wallet on wins by either the bankroll or the staking pool
    /// @dev add funds to the users live wallet as winnings
    function addToUserWinningsNative (uint256 _amount, address _user) public {
        //todo change to liquidity bankroll
        require(msg.sender == address(liquidityBankroll),"Caller must be liquidity bankroll");
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

   

    /// Store `_stakingPool`.
    /// @param _stakingPool the new value to store
    /// @dev stores the _stakingPool address in the state variable `stakingPool`
    function setStakingPool (BitcrushStaking _stakingPool) public onlyOwner {
        require(stakingPool == BitcrushStaking(0x0), "staking pool address already set");
        stakingPool = _stakingPool;
    }

    function setPendingBankrollThreshold (uint256 _amount) public onlyOwner {
        pendingBakrollThreshold = _amount;
    }

    function setBankrollShare (uint256 _amount) public onlyOwner {
        require(_amount < 9000, "Bankroll share must be less than 90%");
        bankrollShare = _amount;
    }

    function setSlipage (uint256 _amount) public onlyOwner {
        require(_amount < 3000, "slipage must be less than 30%");
        slipage = _amount;
    }

}