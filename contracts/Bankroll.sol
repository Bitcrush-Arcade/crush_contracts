//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5;

//BSC Address: 0xF43A7d04DcD76601dE0B0d03D761B09fBF095502
//openzeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
//bitcrush
import "./BankStaking.sol";
//import "../interfaces/IBankroll.sol";
///@dev use interface IBitcrushBankroll
import "./LiveWallet.sol";

contract BitcrushBankroll is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20Burnable;
    uint256 public totalBankroll;
    bool public poolDepleted;
    uint256 public negativeBankroll;
    //address of the crush token
    ERC20Burnable public immutable crush;
    BitcrushStaking public immutable stakingPool;

    address public reserve;
    address public lottery;

    uint256 public constant DIVISOR = 10000;
    uint256 public constant BURN_RATE = 100;
    uint256 public profitThreshold;

    //consistent 1% burn
    uint256 public profitShare;
    uint256 public houseBankrollShare;
    uint256 public lotteryShare;
    uint256 public reserveShare;

    //profit tracking
    uint256 public brSinceCompound;
    uint256 public negativeBrSinceCompound;

    //tracking historical winnings and profits
    uint256 public totalWinnings;
    uint256 public totalProfit;

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
    event SharesUpdated(
        uint256 _houseBankrollShare,
        uint256 _profitShare,
        uint256 _lotteryShare,
        uint256 _reserveShare
    );

    constructor(
        ERC20Burnable _crush,
        BitcrushStaking _stakingPool,
        address _reserve,
        address _lottery,
        uint256 _profitShare,
        uint256 _houseBankrollShare,
        uint256 _lotteryShare,
        uint256 _reserveShare,
        address _admin
    ) {
        crush = _crush;
        stakingPool = _stakingPool;
        reserve = _reserve;
        lottery = _lottery;
        profitShare = _profitShare;
        houseBankrollShare = _houseBankrollShare;
        lotteryShare = _lotteryShare;
        reserveShare = _reserveShare;
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

    /// DESCRIPTION PENDING
    function addToBankroll(uint256 _amount) public adminOnly {
        if (poolDepleted == true) {
            if (_amount >= negativeBankroll) {
                uint256 remainder = _amount.sub(negativeBankroll);
                crush.safeTransferFrom(
                    msg.sender,
                    address(stakingPool),
                    negativeBankroll
                );
                stakingPool.unfreezeStaking(negativeBankroll);
                negativeBankroll = 0;
                poolDepleted = false;
                crush.safeTransferFrom(msg.sender, address(this), remainder);
                totalBankroll = totalBankroll.add(remainder);
            } else {
                crush.safeTransferFrom(
                    msg.sender,
                    address(stakingPool),
                    _amount
                );
                stakingPool.unfreezeStaking(_amount);
                negativeBankroll = negativeBankroll.sub(_amount);
            }
        } else {
            crush.safeTransferFrom(msg.sender, address(this), _amount);
            totalBankroll = totalBankroll.add(_amount);
        }
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
                crush.safeTransferFrom(
                    msg.sender,
                    address(stakingPool),
                    negativeBankroll
                );
                stakingPool.unfreezeStaking(negativeBankroll);
                negativeBankroll = 0;
                poolDepleted = false;
                crush.safeTransferFrom(msg.sender, address(this), remainder);
                totalBankroll = totalBankroll.add(remainder);
            } else {
                crush.safeTransferFrom(
                    msg.sender,
                    address(stakingPool),
                    _amount
                );
                stakingPool.unfreezeStaking(_amount);
                negativeBankroll = negativeBankroll.sub(_amount);
            }
        } else {
            crush.safeTransferFrom(msg.sender, address(this), _amount);
            totalBankroll = totalBankroll.add(_amount);
        }
        addToBrSinceCompound(_amount);
    }

    /// Deduct users win from the bankroll
    /// @param _amount the amount to deduct
    /// @dev deducts funds from the bankroll if bankroll is in positive, otherwise theyre pulled from staking pool and bankroll marked as negative
    function recoverBankroll(uint256 _amount) public {
        require(
            msg.sender == address(stakingPool),
            "Caller must be staking pool"
        );
        if (_amount >= negativeBankroll) {
            uint256 remainder = _amount.sub(negativeBankroll);
            negativeBankroll = 0;
            poolDepleted = false;
            crush.safeTransferFrom(msg.sender, address(this), remainder);
            totalBankroll = totalBankroll.add(remainder);
        } else {
            negativeBankroll = negativeBankroll.sub(_amount);
        }
    }

    /// Deduct users win from the bankroll
    /// @param _amount the amount to deduct
    /// @dev deducts funds from the bankroll if bankroll is in positive, otherwise theyre pulled from staking pool and bankroll marked as negative
    function payOutUserWinning(uint256 _amount, address _winner) public {
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
            stakingPool.freezeStaking(remainder, _winner, msg.sender);
            negativeBankroll = negativeBankroll.add(remainder);
            transferWinnings(totalBankroll, _winner, msg.sender);

            totalBankroll = 0;
        } else {
            totalBankroll = totalBankroll.sub(_amount);
            transferWinnings(_amount, _winner, msg.sender);
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
        address _winner,
        address _lwAddress
    ) internal {
        crush.safeTransfer(_lwAddress, _amount);
        BitcrushLiveWallet currentLw = BitcrushLiveWallet(_lwAddress);
        currentLw.addToUserWinnings(_amount, _winner);
    }

    /// track funds added since last compound and profit transfer
    /// @param _amount the amount to add
    /// @dev add funds to the variable brSinceCompound
    function addToBrSinceCompound(uint256 _amount) internal {
        if (negativeBrSinceCompound > 0) {
            if (_amount > negativeBrSinceCompound) {
                uint256 difference = _amount.sub(negativeBrSinceCompound);
                negativeBrSinceCompound = 0;
                brSinceCompound = brSinceCompound.add(difference);
            } else {
                negativeBrSinceCompound = negativeBrSinceCompound.sub(_amount);
            }
        } else {
            brSinceCompound = brSinceCompound.add(_amount);
        }
    }

    /// track funds remvoed since last compound and profit transfer
    /// @param _amount the amount to remove
    /// @dev deduct funds to the variable brSinceCompound
    function removeFromBrSinceCompound(uint256 _amount) internal {
        if (negativeBrSinceCompound > 0) {
            negativeBrSinceCompound = negativeBrSinceCompound.add(_amount);
        } else {
            if (_amount > brSinceCompound) {
                uint256 difference = _amount.sub(brSinceCompound);
                brSinceCompound = 0;
                negativeBrSinceCompound = negativeBrSinceCompound.add(
                    difference
                );
            } else {
                brSinceCompound = brSinceCompound.sub(_amount);
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
            if (profitShare > 0) {
                uint256 stakingBankrollProfit = brSinceCompound
                    .mul(profitShare)
                    .div(DIVISOR);
                profit = profit.add(stakingBankrollProfit);
            }
            if (reserveShare > 0) {
                uint256 reserveCrush = brSinceCompound.mul(reserveShare).div(
                    DIVISOR
                );
                crush.safeTransfer(reserve, reserveCrush);
            }
            if (lotteryShare > 0) {
                uint256 lotteryCrush = brSinceCompound.mul(lotteryShare).div(
                    DIVISOR
                );
                crush.safeTransfer(lottery, lotteryCrush);
            }

            uint256 burn = brSinceCompound.mul(BURN_RATE).div(DIVISOR);
            crush.burn(burn);

            if (houseBankrollShare > 0) {
                uint256 bankrollShare = brSinceCompound
                    .mul(houseBankrollShare)
                    .div(DIVISOR);
                brSinceCompound = brSinceCompound.sub(bankrollShare);
            }

            totalBankroll = totalBankroll.sub(brSinceCompound);
            //-----
            crush.safeTransfer(address(stakingPool), profit);
            totalProfit = totalProfit.add(profit);
            brSinceCompound = 0;
            return profit;
        } else {
            return 0;
        }
    }

    /// Store `_threshold`.
    /// @param _threshold the new value to store
    /// @dev stores the _threshold address in the state variable `profitThreshold`
    function setProfitThreshold(uint256 _threshold) public adminOnly {
        require(
            _threshold < 100000000000000000000000,
            "Max profit threshold cant be greater than 100k Crush"
        );
        profitThreshold = _threshold;
    }

    /// updates all share percentage values
    /// @param _houseBankrollShare the new value to store
    /// @param _profitShare the new value to store
    /// @param _lotteryShare the new value to store
    /// @param _reserveShare the new value to store
    /// @dev stores the _houseBankrollShare address in the state variable `houseBankrollShare`
    function setShares(
        uint256 _houseBankrollShare,
        uint256 _profitShare,
        uint256 _lotteryShare,
        uint256 _reserveShare
    ) public onlyOwner {
        require(
            _houseBankrollShare
                .add(_profitShare)
                .add(_lotteryShare)
                .add(_reserveShare)
                .add(BURN_RATE) == DIVISOR,
            "Sum of all shares should add up to 100%"
        );
        houseBankrollShare = _houseBankrollShare;
        profitShare = _profitShare;
        lotteryShare = _lotteryShare;
        reserveShare = _reserveShare;
        emit SharesUpdated(
            _houseBankrollShare,
            _profitShare,
            _lotteryShare,
            _reserveShare
        );
    }

    ///store new address in reserve address
    /// @param _reserve the new address to store
    /// @dev changes the address which recieves reserve fees
    function setReserveAddress(address _reserve) public onlyOwner {
        reserve = _reserve;
    }

    ///store new address in lottery address
    /// @param _lottery the new address to store
    /// @dev changes the address which recieves lottery fees
    function setLotteryAddress(address _lottery) public onlyOwner {
        lottery = _lottery;
    }

    ///store new address in admin address
    /// @param _admin the new address to store
    /// @dev changes the address which is used by the adminOnly modifier
    function setAdmin(address _admin) public onlyOwner {
        admin = _admin;
    }
}
