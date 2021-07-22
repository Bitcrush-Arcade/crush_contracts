//SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "./CrushCoin.sol";
import "./HouseBankroll.sol";

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
contract BitcrushLiveWallet is Ownable {
    using SafeMath for uint256;
    struct bet {
        uint256 bet;
    }
    mapping (uint256 => mapping (address => bet)) public betAmounts;
    //address of the crush token
    CRUSHToken public crush;
    BitcrushBankroll public bankroll;

    //todo add emergency methods
    event Withdraw (uint256 indexed _gameId, address indexed _address, uint256 indexed _amount);

    function addbet (uint256 _amount, uint256 _gameId) public {
        //todo add validation for valid game id
        require(_amount > 0, "Bet amount should be greater than 0");
        crush.transferFrom(msg.sender, address(this), _amount);
        betAmounts[_gameId][msg.sender].bet = betAmounts[_gameId][msg.sender].bet.add(_amount);
        
    }

    function registerWin (uint256 _gameId, uint256 _bet, uint256 _win) public {
        require(betAmounts[_gameId][msg.sender].bet > 0, "No Bet Made");
        require(betAmounts[_gameId][msg.sender].bet >= _bet, "amount greater than live wallet balance");
        transferToBankroll(_bet);
        betAmounts[_gameId][msg.sender].bet = betAmounts[_gameId][msg.sender].bet.sub(_bet);
        bankroll.payOutUserWinning(_win);
    }

    function registerLoss (uint256 _gameId, uint256 _bet) public {
        require(betAmounts[_gameId][msg.sender].bet > 0, "No Bet Made");
        require(betAmounts[_gameId][msg.sender].bet >= _bet, "amount greater than live wallet balance");
        transferToBankroll(_bet);
        betAmounts[_gameId][msg.sender].bet = betAmounts[_gameId][msg.sender].bet.sub(_bet);
    }

    function transferToBankroll (uint256 _amount) internal {
        crush.approve(address(bankroll), _amount);
        bankroll.addUserLoss(_amount);       
    }
}