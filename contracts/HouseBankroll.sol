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

    function setLiveWallet(BitcrushLiveWallet _liveWallet) public {
        liveWallet = _liveWallet;
    }

    

    function addToBankroll(uint256 _amount) public onlyOwner {
        crush.transferFrom(msg.sender, address(this), _amount);
        totalBankroll = totalBankroll.add(_amount);
    }

    function addUserLoss(uint256 _amount) public {
        require(
            msg.sender == address(liveWallet),
            "Caller must be bitcrush live wallet"
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

    function payOutUserWinning(
        uint256 _amount,
        address _winner
    ) public {
        require(
            msg.sender == address(liveWallet),
            "Caller must be bitcrush live wallet"
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

    function transferWinnings(
        uint256 _amount,
        address _winner
    ) internal {
        crush.transfer(address(liveWallet), _amount);
        liveWallet.addToUserWinnings(_amount, _winner);
    }


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

    function setProfitThreshold(uint256 _threshold) public onlyOwner {
        profitThreshold = _threshold;
    }

    function setHouseBankrollShare (uint256 _houseBankrollShare) public onlyOwner {
        houseBankrollShare = _houseBankrollShare;
    }

    function setProfitShare (uint256 _profitShare) public onlyOwner {
        profitShare = _profitShare;
    }

    function setLotteryShare (uint256 _lotteryShare) public onlyOwner {
        lotteryShare = _lotteryShare;
    }

    function setReserveShare (uint256 _reserveShare) public onlyOwner {
        reserveShare = _reserveShare;
    }

    function EmergencyWithdrawBankroll () public onlyOwner {
        crush.transfer(msg.sender, totalBankroll);
        totalBankroll = 0;
    }
    function setBitcrushStaking (BitcrushStaking _stakingPool)public onlyOwner{
        stakingPool = _stakingPool;
    }

}
