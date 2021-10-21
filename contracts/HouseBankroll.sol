//SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "./staking.sol";
import "./HouseBankroll.sol";
import "./LiveWallet.sol";
contract BitcrushBankroll is Ownable {
    
    using SafeMath for uint256;

    uint256 public totalBankroll;
    bool public poolDepleted = false;
    uint256 public negativeBankroll;
    //address of the crush token
    CRUSHToken public crush;
    BitcrushStaking public stakingPool;
    BitcrushLiveWallet public liveWallet;
    address public reserve;
    address public lottery;
    
    uint256 public constant DIVISOR = 10000;
    uint256 public constant BURN_RATE = 100;
    uint256 public profitThreshold = 0;
    
    //consistent 1% burn
    uint256 public profitShare;
    uint256 public houseBankrollShare;
    uint256 public lotteryShare;
    uint256 public reserveShare;
    
    //profit tracking
    uint256 public brSinceCompound;
    uint256 public negativeBrSinceCompound;

    //tracking historical winnings and profits
    uint256 public totalWinnings = 0;
    uint256 public totalProfit = 0;

    //authorized addresses
    mapping (address => bool) public authorizedAddresses;

    constructor(
        CRUSHToken _crush,
        BitcrushStaking _stakingPool,
        address _reserve,
        address _lottery,
        uint256 _profitShare,
        uint256 _houseBankrollShare,
        uint256 _lotteryShare,
        uint256 _reserveShare
    ) public {
        crush = _crush;
        stakingPool = _stakingPool;
        reserve = _reserve;
        lottery = _lottery;
        profitShare = _profitShare;
        houseBankrollShare = _houseBankrollShare;
        lotteryShare = _lotteryShare;
        reserveShare = _reserveShare;

    }

    /// Store `_liveWallet`.
    /// @param _liveWallet the new value to store
    /// @dev stores the _liveWallet address in the state variable `liveWallet`
    function setLiveWallet(BitcrushLiveWallet _liveWallet) public onlyOwner{
        liveWallet = _liveWallet;
    }

    /// authorize address to register wins and losses
    /// @param _address the address to be authorized
    /// @dev updates the authorizedAddresses mapping to true for given address
    function authorizeAddress (address _address) public onlyOwner {
        authorizedAddresses[_address] = true;
    }

    /// remove authorization of an address from register wins and losses
    /// @param _address the address to be removed
    /// @dev updates the authorizedAddresses mapping by deleting entry for given address
    function removeAuthorization (address _address) public onlyOwner {
        delete authorizedAddresses[_address];
    }
    
    /// Add funds to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll
    function addToBankroll(uint256 _amount) public onlyOwner {
        crush.transferFrom(msg.sender, address(this), _amount);
        totalBankroll = totalBankroll.add(_amount);
    }

    /// Add users loss to the bankroll
    /// @param _amount the amount to add
    /// @dev adds funds to the bankroll if bankroll is in positive, otherwise its transfered to the staking pool to recover frozen funds
    function addUserLoss(uint256 _amount) public {
        require(
            authorizedAddresses[msg.sender] == true,
            "Caller must be authorized"
        );
        //make game specific
        //check if bankroll is in negative
        //uint is unsigned, keep a bool to track
        //if negative send to staking to replenish
        //otherwise add to bankroll and check for profit
        if (poolDepleted == true) {
            if (_amount >= negativeBankroll) {
                uint256 remainder = _amount.sub(negativeBankroll);
                crush.transferFrom(
                    msg.sender,
                    address(stakingPool),
                    negativeBankroll
                );
                stakingPool.unfreezeStaking(negativeBankroll);
                negativeBankroll = 0;
                poolDepleted = false;
                crush.transferFrom(msg.sender, address(this), remainder);
                totalBankroll = totalBankroll.add(remainder);
                
            } else {
                crush.transferFrom(msg.sender, address(stakingPool), _amount);
                stakingPool.unfreezeStaking(_amount);
                negativeBankroll = negativeBankroll.sub(_amount);
            }
        } else {
            crush.transferFrom(msg.sender, address(this), _amount);
            totalBankroll = totalBankroll.add(_amount);
            
        }
        addToBrSinceCompound(_amount);
    }



    /// Deduct users win from the bankroll
    /// @param _amount the amount to deduct
    /// @dev deducts funds from the bankroll if bankroll is in positive, otherwise theyre pulled from staking pool and bankroll marked as negative
    function payOutUserWinning(
        uint256 _amount,
        address _winner
    ) public {
        require(
            authorizedAddresses[msg.sender] == true,
            "Caller must be authorized"
        );
        
        
        //check if bankroll has funds available
        //if not dip into staking pool for any remainder
        // update bankroll accordingly
        if (_amount > totalBankroll) {
            uint256 remainder = _amount.sub(totalBankroll);
            poolDepleted = true;
            stakingPool.freezeStaking(remainder, _winner);
            negativeBankroll = negativeBankroll.add(remainder);
            transferWinnings(totalBankroll, _winner);

            totalBankroll = 0;
        } else {
            totalBankroll = totalBankroll.sub(_amount);
            transferWinnings(_amount, _winner);
        }
        removeFromBrSinceCompound(_amount);
        totalWinnings = totalWinnings.add(_amount);
    }

    /// transfer winnings from bankroll contract to live wallet
    /// @param _amount the amount to tranfer
    /// @param _winner the winners address
    /// @dev transfers funds from the bankroll to the live wallet as users winnings
    function transferWinnings(
        uint256 _amount,
        address _winner
    ) internal {
        crush.transfer(address(liveWallet), _amount);
        liveWallet.addToUserWinnings(_amount, _winner);
    }

    /// track funds added since last compound and profit transfer
    /// @param _amount the amount to add
    /// @dev add funds to the variable brSinceCompound
    function addToBrSinceCompound (uint256 _amount) internal{
        if(negativeBrSinceCompound > 0){
            if(_amount > negativeBrSinceCompound){
                uint256 difference = _amount.sub(negativeBrSinceCompound);
                negativeBrSinceCompound = 0;
                brSinceCompound = brSinceCompound.add(difference);
            }else {
                negativeBrSinceCompound = negativeBrSinceCompound.sub(_amount);
            }
        }else {
            brSinceCompound = brSinceCompound.add(_amount);
        }
    }

    /// track funds remvoed since last compound and profit transfer
    /// @param _amount the amount to remove
    /// @dev deduct funds to the variable brSinceCompound
    function removeFromBrSinceCompound (uint256 _amount) internal{
        if(negativeBrSinceCompound > 0 ){
            negativeBrSinceCompound = negativeBrSinceCompound.add(_amount);
            
        }else {
            if(_amount > brSinceCompound){
                uint256 difference = _amount.sub(brSinceCompound);
                brSinceCompound = 0;
                negativeBrSinceCompound = negativeBrSinceCompound.add(difference);
            }else {
                negativeBrSinceCompound = negativeBrSinceCompound.add(_amount);
            }
        }
    }

    /// transfer profits to staking pool to be ditributed to stakers.
    /// @dev transfer profits since last compound to the staking pool while taking out necessary fees.
    function transferProfit() public returns (uint256) {
        require(
            msg.sender == address(stakingPool),
            "Caller must be staking pool"
        );
        if (brSinceCompound >= profitThreshold) {

            //-----
            uint256 profit = 0;
            if(profitShare > 0 ){
                uint256 stakingBakrollProfit = brSinceCompound.mul(profitShare).div(DIVISOR);
                profit = profit.add(stakingBakrollProfit);
            }
            if(reserveShare > 0 ){
                uint256 reserveCrush = brSinceCompound.mul(reserveShare).div(DIVISOR);
                crush.transfer(reserve, reserveCrush);
            }
            if(lotteryShare > 0){
                uint256 lotteryCrush = brSinceCompound.mul(lotteryShare).div(DIVISOR);
                crush.transfer(lottery, lotteryCrush);
            }
            
            uint256 burn = brSinceCompound.mul(BURN_RATE).div(DIVISOR);
            crush.burn(burn); 

            if(houseBankrollShare > 0){
                uint256 bankrollShare = brSinceCompound.mul(houseBankrollShare).div(DIVISOR);
                brSinceCompound = brSinceCompound.sub(bankrollShare);
            }

            totalBankroll = totalBankroll.sub(brSinceCompound);
            //-----
            crush.transfer(address(stakingPool), profit);
            totalProfit= totalProfit.add(profit);
            brSinceCompound = 0;
            return profit;
        } else {
            return 0;
        }
    }

    /// Store `_threshold`.
    /// @param _threshold the new value to store
    /// @dev stores the _threshold address in the state variable `profitThreshold`
    function setProfitThreshold(uint256 _threshold) public onlyOwner {
        profitThreshold = _threshold;
    }

    /// Store `_houseBankrollShare`.
    /// @param _houseBankrollShare the new value to store
    /// @dev stores the _houseBankrollShare address in the state variable `houseBankrollShare`
    function setHouseBankrollShare (uint256 _houseBankrollShare) public onlyOwner {
        houseBankrollShare = _houseBankrollShare;
    }

    /// Store `_profitShare`.
    /// @param _profitShare the new value to store
    /// @dev stores the _profitShare address in the state variable `profitShare`
    function setProfitShare (uint256 _profitShare) public onlyOwner {
        profitShare = _profitShare;
    }

    /// Store `_lotteryShare`.
    /// @param _lotteryShare the new value to store
    /// @dev stores the _lotteryShare address in the state variable `lotteryShare`
    function setLotteryShare (uint256 _lotteryShare) public onlyOwner {
        lotteryShare = _lotteryShare;
    }

    /// Store `_reserveShare`.
    /// @param _reserveShare the new value to store
    /// @dev stores the _reserveShare address in the state variable `reserveShare`
    function setReserveShare (uint256 _reserveShare) public onlyOwner {
        reserveShare = _reserveShare;
    }

    /// withdraws the total bankroll in case of emergency.
    /// @dev drains the total bankroll and sets the state variable `totalBankroll` to 0
    function EmergencyWithdrawBankroll () public onlyOwner {
        crush.transfer(msg.sender, totalBankroll);
        totalBankroll = 0;
    }

    /// Store `_stakingPool`.
    /// @param _stakingPool the new value to store
    /// @dev stores the _stakingPool address in the state variable `stakingPool`
    function setBitcrushStaking (BitcrushStaking _stakingPool)public onlyOwner{
        stakingPool = _stakingPool;
    }

}
