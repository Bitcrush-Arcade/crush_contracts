// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// VRF
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./CrushCoin.sol";

interface Bankroll {
    function addUserLoss(uint256 _amount) external;
}

/**
 * @title  Bitcrush's lottery game
 * @author Bitcrush Devs
 * @notice Simple Lottery contract, matches winning numbers from left to right.
 *
 *
 *
 */
contract BitcrushLottery is VRFConsumerBase, Ownable, ReentrancyGuard {
    
    // Libraries
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using SafeERC20 for CRUSHToken;

    // Contracts
    CRUSHToken immutable public crush;
    Bankroll immutable public bankAddress;
    address public devAddress; //Address to send Ticket cut to.
    
    // Data Structures
    struct RoundInfo {
        uint256 totalTickets;
        uint256 ticketsClaimed;
        uint256 winnerNumber;
        uint256 pool;
        uint256 endTime;
        uint256 match6;
        uint256 match5;
        uint256 match4;
        uint256 match3;
        uint256 match2;
        uint256 match1;
        uint256 noMatch;
        uint256 burn;
    }

    struct Ticket {
        uint256 ticketNumber;
        bool    claimed;
    }

    struct Claimer {
        address claimer;
        uint256 percent;
    }
    // This struct defines the values to be stored on a per Round basis
    struct BonusCoin {
        address bonusToken;
        uint256 bonusAmount;
        uint256 bonusClaimed;
        uint bonusMaxPercent; // accumulated percentage of winners for a round
    }

    struct Partner {
        uint256 spread;
        uint256 id;
        bool set;
    }
    
    // VRF Specific
    bytes32 internal keyHashVRF;
    uint256 internal feeVRF;

    /// Timestamp Specific
    uint constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint constant SECONDS_PER_HOUR = 60 * 60;
    uint constant SECONDS_PER_MINUTE = 60;
    int constant OFFSET19700101 = 2440588;
    // CONSTANTS
    uint256 constant ONE100PERCENT = 10000000;
    uint256 constant ONE__PERCENT = 1000000000;
    uint256 constant PERCENT_BASE = 100000000000;
    uint256 constant WINNER_BASE = 1000000; //6 digits are necessary
    uint256 constant MAX_BASE = 2000000; //6 digits are necessary
    // Variables
    bool public currentIsActive = false;
    uint256 public currentRound = 0;
    uint256 public roundStart; //Timestamp of roundstart
    uint256 public roundEnd;
    uint256 public ticketValue = 30 * 10**18 ; //Value of Ticket value in WEI
    uint256 public devTicketCut = 10 * ONE__PERCENT; // This is 10% of ticket sales taken on ticket sale

    uint256 public burnThreshold = 10 * ONE__PERCENT;
    uint256 public distributionThreshold = 10 * ONE__PERCENT;
    
    // Fee Distributions
    /// @dev these values are used with PERCENT_BASE as 100%
    uint256 public match6 = 40 * ONE__PERCENT;
    uint256 public match5 = 20 * ONE__PERCENT;
    uint256 public match4 = 10 * ONE__PERCENT;
    uint256 public match3 = 5 * ONE__PERCENT;
    uint256 public match2 = 3 * ONE__PERCENT;
    uint256 public match1 = 2 * ONE__PERCENT;
    uint256 public noMatch = 2 * ONE__PERCENT;
    uint256 public burn = 18 * ONE__PERCENT;
    uint256 public claimFee = 75 * ONE100PERCENT; // This is deducted from the no winners 2%
    // Mappings
    mapping(uint256 => RoundInfo) public roundInfo; //Round Info
    mapping(uint256 => BonusCoin) public bonusCoins; //Track bonus partner coins to distribute
    mapping(uint256 => mapping(uint256 => uint256)) public holders; // ROUND => DIGITS => #OF HOLDERS
    mapping(uint256 => mapping(address => Ticket[]))public userTickets; // User Bought Tickets
    mapping(address => uint256) public exchangeableTickets;
    mapping(address => Partner) public partnerSplit;

    mapping(uint256 => Claimer) private claimers; // Track claimers to autosend claiming Bounty
    
    mapping(address => bool) public operators; //Operators allowed to execute certain functions
    
    address[] private partners;

    uint8[] public endHours = [18];
    uint8 public endHourIndex;
    // EVENTS
    event FundedBonusCoins(address indexed _partner, uint256 _amount, uint256 _startRound, uint256 _numberOfRounds );
    event FundPool(uint256 indexed _round, uint256 _amount);
    event OperatorChanged (address indexed operators, bool active_status);
    event RoundStarted(uint256 indexed _round, address indexed _starter, uint256 _timestamp);
    event TicketBought(uint256 indexed _round, address indexed _user, uint256 _ticketStandardNumber);
    event SelectionStarted(uint256 indexed _round, address _caller, bytes32 _requestId);
    event WinnerPicked(uint256 indexed _round, uint256 _winner, bytes32 _requestId);
    event TicketClaimed(uint256 indexed _round, address winner, Ticket ticketClaimed);
    event TicketsRewarded(address _rewardee, uint256 _ticketAmount);
    event UpdateTicketValue(uint256  _timeOfUpdate, uint256 _newValue);
    event PartnerUpdated(address indexed _partner);
    event PercentagesChanged( address indexed owner, string percentName, uint256 newPercent);
    
    // MODIFIERS
    modifier operatorOnly {
        require(operators[msg.sender] == true || msg.sender == owner(), 'Sorry Only Operators');
        _;
    }
    
    /// @dev Select the appropriate VRF Coordinator and LINK Token addresses
    constructor (address _crush, address _bankAddress)
        VRFConsumerBase(
            // BSC MAINNET
            // 0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31, //VRFCoordinator
            // 0x404460C6A5EdE2D891e8297795264fDe62ADBB75,  //LINK Token
            // BSC TESTNET
            0xa555fC018435bef5A13C6c6870a9d4C11DEC329C, // VRF Coordinator
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06  // LINK Token
        ) 
    {
        // VRF Init
        // keyHash = 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c; //MAINNET HASH
        keyHashVRF = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186; //TESTNET HASH
        // fee = 0.2 * 10 ** 18; // 0.2 LINK (MAINNET)
        feeVRF = 0.1 * 10 ** 18; // 0.1 LINK (TESTNET)
        crush = CRUSHToken(_crush);
        devAddress = msg.sender;
        operators[msg.sender] = true;
        bankAddress = Bankroll(_bankAddress);
    }

    // External functions
    /// @notice Buy Tickets to participate in current round from a partner
    /// @param _ticketNumbers takes in an array of uint values as the ticket number to buy
    /// @param _partnerId the id of the partner to send the funds to if 0, no partner is checked.
    function buyTickets(uint256[] calldata _ticketNumbers, uint256 _partnerId) external nonReentrant {
        require(_ticketNumbers.length > 0, "Cant buy zero tickets");
        require(_ticketNumbers.length <= 100, "Cant buy more than 100 tickets at any given time");
        require(currentIsActive == true, "Round not active");
        // Check if User has funds for ticket
        uint userCrushBalance = crush.balanceOf(msg.sender);
        uint ticketCost = ticketValue.mul(_ticketNumbers.length);
        require(userCrushBalance >= ticketCost, "Not enough funds to purchase Tickets");
        // Add Tickets to respective Mappings
        for(uint i = 0; i < _ticketNumbers.length; i++){
            createTicket(msg.sender, _ticketNumbers[i], currentRound);
        }
        uint devCut = getFraction(ticketCost, devTicketCut, PERCENT_BASE);
        addToPool(ticketCost.sub(devCut));
        
        if(_partnerId > 0){
            require(_partnerId <= partners.length, "Cheeky aren't you, partner Id doesn't exist. Contact us for partnerships");
            Partner storage _p = partnerSplit[partners[_partnerId -1]];
            require(_p.set, "Partnership ended");
            // Split cut with partner
            uint partnerCut = getFraction(devCut, _p.spread, 100);
            devCut = devCut.sub(partnerCut);
            crush.safeTransferFrom(msg.sender, partners[_partnerId-1], partnerCut);
        }
        crush.safeTransferFrom(msg.sender, devAddress, devCut);
        roundInfo[currentRound].totalTickets = roundInfo[currentRound].totalTickets.add(_ticketNumbers.length);
    }

    /// @notice add/remove/edit partners 
    /// @param _partnerAddress the address where funds will go to.
    /// @param _split the negotiated split percentage. Value goes from 0 to 90.
    /// @dev their ID doesn't change, nor is it removed once partnership ends.
    function editPartner(address _partnerAddress, uint8 _split) external operatorOnly {
        require(_split <= 90, "No greedyness, thanks");
        Partner storage _p = partnerSplit[_partnerAddress];
        if(!_p.set){
            partners.push(_partnerAddress);
            _p.id = partners.length;
        }
        _p.spread = _split;
        if(_split > 0)
            _p.set = true;
        emit PartnerUpdated(_partnerAddress);
    }
    /// @notice retrieve a provider wallet ID
    /// @param _checkAddress the address to check
    /// @return _id the ID of the provider
    function getProviderId(address _checkAddress) external view returns(uint256 _id){
        Partner storage partner = partnerSplit[_checkAddress];
        require( partner.set , "Not a partner");
        _id = partner.id;
    }

    /// @notice Give Redeemable Tickets to a particular user
    /// @param _rewardee Address the tickets will be awarded to
    /// @param ticketAmount number of tickets awarded
    function rewardTicket(address _rewardee, uint256 ticketAmount) external operatorOnly {
        exchangeableTickets[_rewardee] += ticketAmount;
        emit TicketsRewarded(_rewardee, ticketAmount);
    }

    /// @notice Exchange awarded tickets for the current round
    /// @param _ticketNumbers array of numbers to add to the caller as tickets
    function exchangeForTicket(uint256[] calldata _ticketNumbers) external {
        require(currentIsActive, "Current round is not active please wait for next round start" );
        require(_ticketNumbers.length <= exchangeableTickets[msg.sender], "You don't have enough redeemable tickets.");
        for(uint256 exchange = 0; exchange < _ticketNumbers.length; exchange ++) {
            createTicket(msg.sender, _ticketNumbers[ exchange ], currentRound);
            exchangeableTickets[msg.sender] -= 1;
        }
    }
    /// @notice Claim rewards for given ticket number
    /// @param _round the round the ticket number was emitted for
    /// @param luckyTicket the ticket number to claim
    function claimNumber(uint256 _round, uint256 luckyTicket) external nonReentrant{
        // Check if round is over
        RoundInfo storage info = roundInfo[_round];
        require(info.winnerNumber > 0, "Round not done yet");
        // check if Number belongs to caller
        Ticket[] storage ownedTickets = userTickets[ _round ][ msg.sender ];
        require( ownedTickets.length > 0, "It would be nice if I had tickets");
        bool ownsTicket = false;
        uint256 ticketIndex;
        for(uint i = 0; i < ownedTickets.length; i ++) {
            if(ownedTickets[i].ticketNumber == standardTicketNumber(luckyTicket, WINNER_BASE, MAX_BASE) && !ownedTickets[i].claimed) {
                ownsTicket = true;
                ticketIndex = i;
                break;
            }
        }
        require(ownsTicket && ownedTickets[ticketIndex].claimed == false, "Not owner or Ticket already claimed");
        // GET AND TRANSFER TICKET CLAIM AMOUNT
        uint256[6] memory matches = [info.match1, info.match2, info.match3, info.match4, info.match5, info.match6];
        (bool isWinner, uint amountMatch) = isNumberWinner(_round, luckyTicket);
        uint256 claimAmount = 0;
        uint256[6] memory digits = getDigits(standardTicketNumber(luckyTicket, WINNER_BASE, MAX_BASE));

        if(isWinner) {
            claimAmount = getFraction(info.pool, matches[amountMatch - 1], PERCENT_BASE)
                .div(holders[_round][digits[6 - amountMatch]]);
            transferBonus(msg.sender, holders[_round][digits[6 - amountMatch]], _round, matches[amountMatch - 1]);
        }
        else{
            uint256 matchReduction = info.noMatch.sub(claimers[_round].percent);
            transferBonus(msg.sender, calcNonWinners(_round), _round, matchReduction);
            // -- matchAmount / nonWinners --
            claimAmount = getFraction(info.pool, matchReduction, PERCENT_BASE)
                .div(calcNonWinners(_round));
        }
        if(claimAmount > 0)
            crush.safeTransfer(msg.sender, claimAmount);
        info.ticketsClaimed = info.ticketsClaimed.add(1);
        userTickets[_round][msg.sender][ticketIndex].claimed = true;
        emit TicketClaimed(_round, msg.sender, ownedTickets[ticketIndex]);
    }

    /// @notice Claim all user unclaimed tickets for a particular round
    /// @param _round the round of tickets that will be claimed
    function claimAll(uint256 _round) external nonReentrant{
        RoundInfo storage info = roundInfo[_round];
        require(info.winnerNumber > 0, "Round not done yet");
        // GET AND TRANSFER TICKET CLAIM AMOUNT
        uint256[6] memory matches = [info.match1, info.match2, info.match3, info.match4, info.match5, info.match6];
        // check if Number belongs to caller
        Ticket[] storage ownedTickets = userTickets[ _round ][ msg.sender ];
        require( ownedTickets.length > 0, "It would be nice if I had tickets");
        uint256 claimAmount;
        uint256 bonusAmount;
        for( uint i = 0; i < ownedTickets.length; i ++){
            if(ownedTickets[i].claimed)
                continue;
            ownedTickets[i].claimed = true;
            (bool isWinner, uint amountMatch) = isNumberWinner(_round, ownedTickets[i].ticketNumber);
            uint256[6] memory digits = getDigits(standardTicketNumber(ownedTickets[i].ticketNumber, WINNER_BASE, MAX_BASE));
            if(isWinner) {
                claimAmount = claimAmount.add(
                    getFraction(info.pool, matches[amountMatch - 1], PERCENT_BASE)
                        .div(holders[_round][digits[6 - amountMatch]])
                );
                bonusAmount = bonusAmount.add(
                    getBonusReward(holders[_round][digits[6 - amountMatch]], _round, matches[amountMatch - 1])
                );
            }
            else{
                uint256 matchReduction = info.noMatch.sub(claimers[_round].percent);
                bonusAmount = bonusAmount.add(
                    getBonusReward( calcNonWinners(_round),_round, matchReduction)
                );
                // -- matchAmount / nonWinners --
                claimAmount = claimAmount.add(
                    getFraction(info.pool, matchReduction, PERCENT_BASE)
                        .div(calcNonWinners(_round))
                );
            }
            emit TicketClaimed(_round, msg.sender, ownedTickets[i]);
        }
        if(claimAmount > 0)
            crush.safeTransfer(msg.sender, claimAmount);
        if(bonusAmount > 0){
            BonusCoin storage bonus = bonusCoins[_round];
            ERC20 bonusTokenContract = ERC20(bonus.bonusToken);
            uint256 availableFunds = bonusTokenContract.balanceOf(address(this));
            if( roundInfo[_round].totalTickets.sub(roundInfo[_round].ticketsClaimed) == 1)
                bonusAmount = bonus.bonusAmount.sub(bonus.bonusClaimed);
            if( bonusAmount > availableFunds)
                bonusAmount = availableFunds;
            bonus.bonusClaimed = bonus.bonusClaimed.add(bonusAmount);
            bonusTokenContract.safeTransfer( msg.sender, bonusAmount);
        }
    }

    /// @notice Start of new Round. This function is only needed for the first round, next rounds will be automatically started once the winner number is received
    function firstStart() external operatorOnly{
        require(currentRound == 0, "First Round only");
        calcNextHour();
        startRound();
        // Rollover all of pool zero at start
        roundInfo[currentRound] = RoundInfo(0,0,0,roundInfo[0].pool, roundEnd, match6, match5, match4, match3, match2, match1, noMatch, 0);
    }

    /// @notice Ends current round
    /// @dev WIP - the end of the round will always happen at set intervals
    function endRound() external {
        require(LINK.balanceOf(address(this)) >= feeVRF, "Not enough LINK - please contact mod to fund to contract");
        require(currentIsActive == true, "Current Round is over");
        require(block.timestamp > roundInfo[currentRound].endTime, "Can't end round just yet");

        calcNextHour();
        currentIsActive = false;
        roundInfo[currentRound.add(1)].endTime = roundEnd;
        claimers[currentRound] = Claimer(msg.sender, 0);
        // Request Random Number for Winner
        bytes32 rqId = requestRandomness(keyHashVRF, feeVRF);
        emit SelectionStarted(currentRound, msg.sender, rqId);
    }

    /// @notice Add or remove operator
    function toggleOperator(address _operator) external operatorOnly{
        bool operatorIsActive = operators[_operator];
        if(operatorIsActive) {
            operators[_operator] = false;
        }
        else {
            operators[_operator] = true;
        }
        emit OperatorChanged(_operator, operators[msg.sender]);
    }

    // SETTERS
    /// @notice Change the claimer's fee
    /// @param _fee the value of the new fee
    /// @dev Fee cannot be greater than noMatch percentage ( since noMatch percentage is the amount given out to nonWinners )
    function setClaimerFee( uint256 _fee ) external onlyOwner{
        require(_fee.mul(ONE100PERCENT) < noMatch, "Invalid fee amount");
        claimFee = _fee.mul(ONE100PERCENT);
        emit PercentagesChanged(msg.sender, 'claimFee', _fee.mul(ONE100PERCENT));
    }
    /// @notice Set the token that will be used as a Bonus for a particular round
    /// @param _partnerToken Token address
    /// @param _round round where this token applies
    function setBonusCoin( address _partnerToken, uint256 _amount ,uint256 _round, uint256 _roundAmount ) external operatorOnly{
        require(_roundAmount > 0, "Thanks for the tokens, but these need to go.");
        require(_round > currentRound, "This round has passed.");
        require(_partnerToken != address(0),"Cant set bonus Token" );
        require( bonusCoins[ _round ].bonusToken == address(0), "Bonus token has already been added to this round");
        ERC20 bonusToken = ERC20(_partnerToken);
        require( bonusToken.balanceOf(msg.sender) >= _amount, "Funds are needed, can't conjure from thin air");
        require( bonusToken.allowance(msg.sender, address(this)) >= _amount, "Please approve this contract for spending :)");
        uint256 spreadAmount = _amount.div(_roundAmount);
        uint256 totalAmount = spreadAmount.mul(_roundAmount);//get the actual total to take into account division issues
        for( uint rounds = _round; rounds < _round.add(_roundAmount); rounds++){
            require( bonusCoins[ rounds ].bonusToken == address(0), "Bonus token has already been added to round");
            // Uses the claimFee as the base since that will always be distributed to the claimer.
            bonusCoins[ rounds ] = BonusCoin(_partnerToken, spreadAmount, 0, 0);
        }
        bonusToken.safeTransferFrom(msg.sender, address(this), totalAmount);
        emit FundedBonusCoins(_partnerToken, _amount, _round, _roundAmount);
    }

    /// @notice Set the ticket value
    /// @param _newValue the new value of the ticket
    /// @dev Ticket value MUST BE IN WEI format, minimum is left as greater than 1 due to the deflationary nature of CRUSH
    function setTicketValue(uint256 _newValue) external onlyOwner{
        require(_newValue < 50 * 10**18 && _newValue > 1, "Ticket value exceeds MAX");
        ticketValue = _newValue;
        emit UpdateTicketValue(block.timestamp, _newValue);
    }

    /// @notice Edit the times array
    /// @param _newTimes Array of hours when Lottery will end
    /// @dev adding a sorting algorithm would be nice but honestly we have too much going on to add that in. So help us out and add your times sorted
    function setEndHours( uint8[] calldata _newTimes) external operatorOnly{
        require( _newTimes.length > 0, "There must be a time somewhere");
        for( uint i = 0; i < _newTimes.length; i ++){
            require(_newTimes[i] < 24, "We all wish we had more hours per day");
            if(i>0)
                require( _newTimes[i] > _newTimes[i-1], "Help a brother out, sort your times first");
        }
        endHours = _newTimes;
    }

    /// @notice Setup the burn threshold
    /// @param _threshold new threshold in percent amount
    /// @dev setting the minimum threshold as 0 will always burn, setting max as 50
    function setBurnThreshold( uint256 _threshold ) external onlyOwner{
        require(_threshold <= 50, "Out of range");
        burnThreshold = _threshold * ONE__PERCENT;
    }
    /// @notice Set the distribution percentage amounts... all amounts must be given for this to work
    /// @param _newDistribution array of distribution amounts 
    /// @dev we expect all values to sum 100 and that all items are given. The new distribution only applies to next rounds
    /// @dev all values are in the one onehundreth percentile amount.
    /// @dev expected order [ jackpot, match5, match4, match3, match2, match1, noMatch, burn]
    function setDistributionPercentages( uint256[] calldata _newDistribution ) external onlyOwner{
        require(_newDistribution.length == 8, "Missed a few values");
        require(_newDistribution[7] > 0, "We need to burn something");
        match6 = _newDistribution[0].mul(ONE100PERCENT);
        match5 = _newDistribution[1].mul(ONE100PERCENT);
        match4 = _newDistribution[2].mul(ONE100PERCENT);
        match3 = _newDistribution[3].mul(ONE100PERCENT);
        match2 = _newDistribution[4].mul(ONE100PERCENT);
        match1 = _newDistribution[5].mul(ONE100PERCENT);
        noMatch = _newDistribution[6].mul(ONE100PERCENT);
        burn = _newDistribution[7].mul(ONE100PERCENT);
        require( match6.add(match5).add(match4).add(match3).add(match2).add(match1).add(noMatch).add(burn) == PERCENT_BASE, "Numbers don't add up");
        emit PercentagesChanged(msg.sender, "jackpot", match6);
        emit PercentagesChanged(msg.sender, "match5", match5);
        emit PercentagesChanged(msg.sender, "match4", match4);
        emit PercentagesChanged(msg.sender, "match3", match3);
        emit PercentagesChanged(msg.sender, "match2", match2);
        emit PercentagesChanged(msg.sender, "match1", match1);
        emit PercentagesChanged(msg.sender, "noMatch", noMatch);
        emit PercentagesChanged(msg.sender, "burnPercent", burn);
    }

    // External functions that are view
    /// @notice Get Tickets for the caller for during a specific round
    /// @param _round The round to query
    function getRoundTickets(uint256 _round) external view returns(Ticket[] memory tickets) {
      return userTickets[_round][msg.sender];
    }

    // Public functions
    /// @notice Check if number is the winning number
    /// @param _round Round the requested ticket belongs to
    /// @param luckyTicket ticket number to check
    /// @return _winner Winner of one or more matching numbers
    /// @return _match Number of winning matches
    function isNumberWinner(uint256 _round, uint256 luckyTicket) public view returns(bool _winner, uint8 _match){
        uint256 roundWinner = roundInfo[_round].winnerNumber;
        require(roundWinner > 0 , "Winner not yet determined");
        _match = 0;
        uint256 luckyNumber = standardTicketNumber(luckyTicket, WINNER_BASE, MAX_BASE);
        uint256[6] memory winnerDigits = getDigits(roundWinner);
        uint256[6] memory luckyDigits = getDigits(luckyNumber);
        for( uint8 i = 0; i < 6; i++){
            if(!_winner) {
                if(winnerDigits[i] == luckyDigits[i]) {
                    _match = 6 - i;
                    _winner = true;
                }
            }
        }
        if(!_winner)
            _match = 0;
    }

    /// @notice Add funds to pool directly, only applies funds to currentRound
    /// @param _amount the amount of CRUSH to transfer from current account to current Round
    /// @dev Approve needs to be run beforehand so the transfer can succeed.
    function addToPool(uint256 _amount) public {
        uint256 userBalance = crush.balanceOf( msg.sender );
        require( userBalance >= _amount, "Insufficient Funds to Send to Pool");
        crush.safeTransferFrom( msg.sender, address(this), _amount);
        roundInfo[ currentRound ].pool = roundInfo[ currentRound ].pool.add( _amount );
        emit FundPool( currentRound, _amount);
    }

    // Internal functions
    /// @notice Set the next start hour and next hour index
    function calcNextHour() internal {
        uint256 tempEnd = roundEnd;
        uint8 newIndex = endHourIndex;
        bool nextDay = true;
        while(tempEnd <= block.timestamp){
            newIndex = newIndex + 1 >= endHours.length ? 0 : newIndex + 1;
            tempEnd = setNextRoundEndTime(block.timestamp, endHours[newIndex], newIndex != 0 && nextDay);
            if(newIndex == endHours.length)
                nextDay = false;
        }
        roundEnd = tempEnd;
        endHourIndex = newIndex;
    }

    function createTicket( address _owner, uint256 _ticketNumber, uint256 _round) internal {
        uint256 currentTicket = standardTicketNumber(_ticketNumber, WINNER_BASE, MAX_BASE);
        uint256[6] memory digits = getDigits( currentTicket );
        
        for( uint256 digit = 0; digit < 6; digit++){
            holders[ _round ][ digits[digit] ] = holders[ _round ][ digits[digit] ].add(1);
        }
        Ticket memory ticket = Ticket( currentTicket, false);
        userTickets[ _round ][ _owner ].push(ticket);
        emit TicketBought( _round, _owner, currentTicket );
    }

    function calcNonWinners( uint256 _round) internal view returns (uint256 nonWinners){
        uint256[6] memory winnerDigits = getDigits( roundInfo[_round].winnerNumber );
        uint256 winners=0;
        for( uint tw = 0; tw < 6; tw++ ){
            winners = winners.add( holders[ _round ][ winnerDigits[tw] ]);
        }
        nonWinners = roundInfo[ _round ].totalTickets.sub( winners );
    }

    //
    function getBonusReward(uint256 _holders, uint256 _round, uint256 _match) internal view returns (uint256 bonusAmount) {
        BonusCoin storage bonus = bonusCoins[_round];
        if(_holders == 0)
            return 0;
        if( bonus.bonusToken != address(0) ){
            if(_match == 0)
                return 0;
            bonusAmount = getFraction( bonus.bonusAmount, _match, bonus.bonusMaxPercent ).div(_holders);
            return bonusAmount;
        }
        return 0;
    }

    // Transfer bonus to
    function transferBonus(address _to, uint256 _holders, uint256 _round, uint256 _match) internal {
        BonusCoin storage bonus = bonusCoins[_round];
        if(_holders == 0)
            return;
        if( bonus.bonusToken != address(0) ){
            ERC20 bonusTokenContract = ERC20(bonus.bonusToken);
            uint256 availableFunds = bonusTokenContract.balanceOf(address(this));
            if(_match == 0)
                return;
            uint256 bonusReward = getFraction( bonus.bonusAmount, _match, bonus.bonusMaxPercent ).div(_holders);
            if(bonusReward == 0)
                return;
            if( roundInfo[_round].totalTickets.sub(roundInfo[_round].ticketsClaimed) == 1)
                bonusReward = bonus.bonusAmount.sub(bonus.bonusClaimed);
            if( bonusReward > availableFunds)
                bonusReward = availableFunds;
            bonus.bonusClaimed = bonus.bonusClaimed.add(bonusReward);
            bonusTokenContract.safeTransfer( _to, bonusReward);
        }
    }

    function startRound() internal {
        require( currentIsActive == false, "Current Round is not over");
        // Add new Round
        currentRound ++;
        currentIsActive = true;
        roundStart = block.timestamp;
        RoundInfo storage newRound = roundInfo[currentRound];
        newRound.match6 = match6;
        newRound.match5 = match5;
        newRound.match4 = match4;
        newRound.match3 = match3;
        newRound.match2 = match2;
        newRound.match1 = match1;
        newRound.noMatch = noMatch;
        emit RoundStarted( currentRound, msg.sender, block.timestamp);
    }

    // BURN AND ROLLOVER
    function distributeCrush() internal {
        uint256 rollOver;
        uint256 burnAmount;
        uint256 forClaimer;
        RoundInfo storage thisRound = roundInfo[currentRound];
        (rollOver, burnAmount, forClaimer) = calculateRollover();
        // Transfer Amount to Claimer
        Claimer storage roundClaimer = claimers[currentRound];
        if(forClaimer > 0)
            crush.safeTransfer( roundClaimer.claimer, forClaimer );
        transferBonus( roundClaimer.claimer, 1 ,currentRound, roundClaimer.percent );
        // Can distribute rollover
        if( rollOver > 0 && thisRound.totalTickets.mul(ticketValue) >= getFraction(thisRound.pool, distributionThreshold, PERCENT_BASE)){
            uint256 profitDistribution = getFraction(rollOver, distributionThreshold, PERCENT_BASE);
            crush.approve( address(bankAddress), profitDistribution);
            bankAddress.addUserLoss(profitDistribution);
            rollOver = rollOver.sub(profitDistribution);
        }

        // BURN AMOUNT
        if( burnAmount > 0 ){
            crush.burn( burnAmount );
            thisRound.burn = burnAmount;
        }
        roundInfo[ currentRound + 1 ].pool = rollOver;
    }

    function calculateRollover() internal returns ( uint256 _rollover, uint256 _burn, uint256 _forClaimer ) {
        RoundInfo storage info = roundInfo[currentRound];
        _rollover = 0;
        // for zero match winners
        BonusCoin storage roundBonusCoin = bonusCoins[currentRound];
        uint256[6] memory winnerDigits = getDigits(info.winnerNumber);
        uint256[6] memory matchPercents = [ info.match6, info.match5, info.match4, info.match3, info.match2, info.match1 ];
        uint256 totalMatchHolders = 0;
        
        for( uint8 i = 0; i < 6; i ++){
            uint256 digitToCheck = winnerDigits[i];
            uint256 matchHolders = holders[currentRound][digitToCheck];
            if( matchHolders > 0 ){
                if(i == 0)
                    totalMatchHolders = matchHolders;
                else{
                    matchHolders = matchHolders.sub(totalMatchHolders);
                    totalMatchHolders = totalMatchHolders.add( matchHolders );
                    holders[currentRound][digitToCheck] = matchHolders;
                }
                _forClaimer = _forClaimer.add(matchPercents[i]);
                roundBonusCoin.bonusMaxPercent = roundBonusCoin.bonusMaxPercent.add(matchPercents[i]);
            }
            else
                _rollover = _rollover.add( getFraction(info.pool, matchPercents[i], PERCENT_BASE) );
        }
        _forClaimer = _forClaimer.mul(claimFee).div(PERCENT_BASE);
        uint256 nonWinners = info.totalTickets.sub(totalMatchHolders);
        // Are there any noMatch tickets
        if( nonWinners == 0 )
            _rollover = _rollover.add(getFraction(info.pool, info.noMatch.sub(_forClaimer ), PERCENT_BASE));
        else
            roundBonusCoin.bonusMaxPercent = roundBonusCoin.bonusMaxPercent.add(info.noMatch);
        if( getFraction(info.pool, burnThreshold, PERCENT_BASE) <=  info.totalTickets.mul(ticketValue) )
            _burn = getFraction( info.pool, burn, PERCENT_BASE);
        else{
            _burn = 0;
            _rollover = _rollover.add( getFraction( info.pool, burn, PERCENT_BASE) );
        }
        claimers[currentRound].percent = _forClaimer;
        _forClaimer = getFraction(info.pool, _forClaimer, PERCENT_BASE);
    }

    // GET Verifiable RandomNumber from VRF
    // This gets called by VRF Contract only
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        RoundInfo storage info = roundInfo[currentRound];
        info.winnerNumber = standardTicketNumber(randomness, WINNER_BASE, MAX_BASE);
        distributeCrush();
        emit WinnerPicked(currentRound, info.winnerNumber, requestId);
        startRound();
    }

    // Function to get the fraction amount from a value
    function getFraction(uint256 _amount, uint256 _percent, uint256 _base) internal pure returns(uint256 fraction) {
        fraction = _amount.mul( _percent ).div( _base );
    }

    // Get all participating digits from number
    function getDigits( uint256 _ticketNumber ) internal pure returns(uint256[6] memory digits){
        digits[5] = _ticketNumber.div(100000); // WINNER_BASE
        digits[4] = _ticketNumber.div(10000);
        digits[3] = _ticketNumber.div(1000);
        digits[2] = _ticketNumber.div(100);
        digits[1] = _ticketNumber.div(10);
        digits[0] = _ticketNumber.div(1);
    }

    // Get the requested ticketNumber from the defined range
    function standardTicketNumber( uint256 _ticketNumber, uint256 _base, uint256 maxBase) internal pure returns( uint256 ){
        uint256 ticketNumber;
        if(_ticketNumber < _base ){
            ticketNumber = _ticketNumber.add( _base );
        }
        else if( _ticketNumber > maxBase ){
            ticketNumber = _ticketNumber.mod( _base ).add( _base );
        }
        else{
            ticketNumber = _ticketNumber;
        }
        return ticketNumber;
    }

    // Get timestamp end for next round to be at the specified _hour
    function setNextRoundEndTime(uint256 _currentTimestamp, uint256 _hour, bool _sameDay) internal pure returns (uint256 _endTimestamp ) {
        uint nextDay = _sameDay ? _currentTimestamp : SECONDS_PER_DAY.add(_currentTimestamp);
        (uint year, uint month, uint day) = timestampToDateTime(nextDay);
        _endTimestamp = timestampFromDateTime(year, month, day, _hour, 0, 0);
    }

    // -------------------------------------------------------------------`
    // Timestamp fns taken from BokkyPooBah's DateTime Library
    //
    // Gas efficient Solidity date and time library
    //
    // https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
    //
    // Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2018.
    //
    // GNU Lesser General Public License 3.0
    // https://www.gnu.org/licenses/lgpl-3.0.en.html
    // ----------------------------------------------------------------------------
    function timestampToDateTime(uint timestamp) internal pure returns (uint year, uint month, uint day) {
        (year, month, day) = _daysToDate(timestamp / SECONDS_PER_DAY);
    }
    
    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
    }

    function _daysToDate(uint _days) internal pure returns (uint year, uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + OFFSET19700101;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }

    function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
          - OFFSET19700101;

        _days = uint(__days);
    }
    
    /// @notice HELPFUL FUNCTION TO TEST WINNERS LOCALLY THIS FUNCTION IS NOT MEANT TO GO LIVE
    /// This function sets the random value for the winner.
    /// @param randomness simulates a number given back by the randomness function
    function setWinner( uint256 randomness, address _claimer ) public operatorOnly{
        currentIsActive = false;
        RoundInfo storage info = roundInfo[currentRound];
        info.winnerNumber = standardTicketNumber(randomness, WINNER_BASE, MAX_BASE);
        claimers[currentRound] = Claimer(_claimer, 0);
        distributeCrush();
        startRound();
        calcNextHour();
        emit WinnerPicked(currentRound, info.winnerNumber, "ADMIN_SET_WINNER");
    }
}