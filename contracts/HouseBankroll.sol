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
    uint256 public allTimeHigh;

    bool poolDepleted = false;
    uint256 negativeBankroll;
    //address of the crush token
    CRUSHToken public crush;
    BitcrushStaking public stakingPool;
    BitcrushLiveWallet public liveWallet;
    address public reserve;

    uint256 gameIds = 1;
    uint256 constant public DIVISOR = 10000;
    uint256 burnRate = 100;
    //todo add configurable values for distribution of house profit
    //consistent 1% burn

    struct game {
        uint256 profit;
        bytes32 identifier;
        uint256 houseShare;
    }
    mapping (uint256 => game) public games;


    constructor (CRUSHToken _crush, BitcrushStaking _stakingPool, BitcrushLiveWallet _liveWallet, address _reserve) public{
        crush = _crush;
        stakingPool = _stakingPool;
        liveWallet = _liveWallet;
        reserve = _reserve;
    }


    function addGame (uint256 _profit, bytes32 _identifier, uint256 _houseShare) public onlyOwner {
        games[gameIds].profit = _profit;
        games[gameIds].identifier = _identifier;
        games[gameIds].houseShare = _houseShare;
        gameIds = gameIds.add(1);
    }

    function addToBankroll (uint256 _amount) public onlyOwner {
        crush.transferFrom(msg.sender, address(this), _amount);
        totalBankroll = totalBankroll.add(_amount);
    }

    function addUserLoss (uint256 _amount) public {
        require(msg.sender == address(liveWallet),"Caller must be bitcrush live wallet");
        //make game specific
        //check if bankroll is in negative 
        //uint is unsigned, keep a bool to track
        //if negative send to staking to replenish
        //otherwise add to bankroll and check for profit
        if (poolDepleted == true) {
            if(_amount >= negativeBankroll){
                uint256 remainder = _amount.sub(negativeBankroll);
                crush.transferFrom(msg.sender, address(stakingPool), negativeBankroll);
                stakingPool.unfreezeStaking(negativeBankroll);
                negativeBankroll = 0;
                poolDepleted = false;
                crush.transferFrom(msg.sender, address(this), remainder);
                totalBankroll = totalBankroll.add(remainder);
            }else {
                crush.transferFrom(msg.sender, address(stakingPool), _amount);
                stakingPool.unfreezeStaking(_amount);
                negativeBankroll = negativeBankroll.sub(_amount);
            }
        }else {
            crush.transferFrom(msg.sender, address(this), _amount);
            totalBankroll = totalBankroll.add(_amount);

        }
        checkForRewardPayOut();
        

    }

    function payOutUserWinning (uint256 _amount, address _winner) public {
        require(msg.sender == address(liveWallet),"Caller must be bitcrush live wallet");
        //check if bankroll has funds available
        //if not dip into staking pool for any remainder
        // update bankroll accordingly
        if(_amount > totalBankroll){
            
            uint256 remainder = _amount.sub(totalBankroll); 
            poolDepleted = true;
            stakingPool.freezeStaking(remainder, _winner);
            negativeBankroll = negativeBankroll.add(remainder);
            crush.transfer(_winner, totalBankroll);
            totalBankroll = 0;
        }else {
            totalBankroll = totalBankroll.sub(_amount);
            crush.transfer(_winner, _amount);
        }
    }

    function checkForRewardPayOut () internal {
        if(totalBankroll > allTimeHigh) {
            //payout winning
            //todo handle transfer
            //handle calculation
            //calculate share
            //update all time high
            allTimeHigh = totalBankroll;

        }
    }



}