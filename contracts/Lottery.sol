// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// VRF
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./CrushCoin.sol";


contract BitcrushLottery is VRFConsumerBase {
    
    // Libraries
    using SafeMath for uint256;
    
    // Contracts
    CRUSHToken public crush;
    address public devAddress; //Address to send Ticket cut to.
    
    // Data Structures
    struct Ticket {
        uint256 ticketNumber;
        bool    claimed;
    }
    
    // VRF Specific
    bytes32 internal keyHashVRF;
    uint256 internal feeVRF;
    
    // CONSTANTS
    uint256 constant PERCENT_BASE = 100000;
    uint256 constant WINNER_BASE = 1000000; //6 digits are necessary
    uint256 constant MAX_BASE = 2000000; //6 digits are necessary
    // Variables
    
    address public owner;
    
    bool public currentIsActive = false;
    uint256 public currentRound = 0;
    uint256 public duration; // ROUND DURATION
    uint256 public roundStart; //Timestamp of roundstart
    uint256 public ticketValue = 30 ; //Value of Ticket
    uint256 public devTicketCut = 10000; // This is 10% of ticket sales taken on ticket sale
    
    // Fee Distributions
    // @dev these are all percentages so should always be divided by 100 when used
    uint256 public match6 = 40000;
    uint256 public match5 = 20000;
    uint256 public match4 = 10000;
    uint256 public match3 =  5000;
    uint256 public match2 =  3000;
    uint256 public match1 =  2000;
    uint256 public noMatch = 2000;
    uint256 public burn =   18000;
    
    // Mappings
    mapping( uint256 => uint256 ) public totalTickets; //Total Tickets emmited per round
    mapping( uint256 => uint256 ) public roundPool; // Winning Pool
    mapping( uint256 => uint256 ) public winnerNumbers; // record of winner Number per round
    mapping( uint256 => address ) public bonusCoins; //Track bonus partner coins to distribute
    mapping( uint256 => mapping( uint256 => uint256 ) ) public holders; // ROUND => DIGITS => #OF HOLDERS
    mapping( uint256 => mapping( address => Ticket[] ) )public userTickets; // User Bought Tickets
    mapping( address => uint256 ) public exchangeableTickets;
    
    mapping( address => bool ) public operators; //Operators allowed to execute certain functions
    
    
    // EVENTS
    event FundPool( uint256 indexed _round, uint256 _amount);
    event OperatorChanged ( address indexed operators, bool active_status );
    event RoundStarted(uint256 indexed _round, address indexed _starter, uint256 _timestamp );
    event TicketBought(uint256 indexed _round, address indexed _user, uint256 _ticketStandardNumber );
    event SelectionStarted( uint256 indexed _round, address _caller, bytes32 _requestId);
    event WinnerPicked(uint256 indexed _round, uint256 _winner, bytes32 _requestId);
    event TicketClaimed( uint256 indexed _round, address winner, Ticket ticketClaimed );
    event TicketsRewarded( address _rewardee, uint256 _ticketAmount );
    
    // MODIFIERS
    modifier operatorOnly {
        require( operators[msg.sender] == true || msg.sender == owner, 'Sorry Only Operators');
        _;
    }
    
    // CONSTRUCTOR
    constructor (address _crush)
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
        owner = msg.sender;
    }
    
    // USER FUNCTIONS
    // Buy Tickets to participate in current Round
    // @args takes in an array of uint values as the ticket IDs to buy
    // @dev max bought tickets at any given time shouldn't be more than 10
    function buyTickets( uint256[] calldata _ticketNumbers ) external {
        require(_ticketNumbers.length > 0, "Cant buy zero tickets");
        require(currentIsActive == true, "Round not active");
        
        // Check if User has funds for ticket
        uint userCrushBalance = crush.balanceOf( msg.sender );
        uint ticketCost = ticketValue.mul( _ticketNumbers.length ).mul( 10 **18 );
        require( userCrushBalance >= ticketCost, "Not enough funds to purchase Tickets" );
        
        // Add Tickets to respective Mappings
        for( uint i = 0; i < _ticketNumbers.length; i++ ){
            createTicket(msg.sender, _ticketNumbers[i], currentRound);
        }
        
        uint devCut = getFraction( ticketCost, devTicketCut, PERCENT_BASE );
        addToPool(ticketCost.sub(devCut));
        crush.transferFrom( msg.sender, devAddress, devCut );
        totalTickets[currentRound] += _ticketNumbers.length;
    }

    function createTicket( address _owner, uint256 _ticketNumber, uint256 _round) internal {
        uint256 currentTicket = standardTicketNumber(_ticketNumber, WINNER_BASE, MAX_BASE);
        uint[6] memory digits = getDigits( currentTicket );
        
        for( uint digit = 0; digit < digits.length; digit++){
            holders[ _round ][ digits[digit] ] += 1;
        }
        Ticket memory ticket = Ticket( currentTicket, false);
        userTickets[ _round ][ _owner ].push(ticket);
        emit TicketBought( _round, _owner, currentTicket );
    }
    // Reward Tickets to a particular user
    function rewardTicket( address _rewardee, uint256 ticketAmount ) external operatorOnly{
        exchangeableTickets[_rewardee] += ticketAmount;
        emit TicketsRewarded( _rewardee, ticketAmount );
    }

    // EXCHANGE TICKET FOR THIS ROUND
    function exchangeForTicket( uint256[] calldata _ticketNumbers) external{
        require( _ticketNumbers.length <= exchangeableTickets[msg.sender], "You don't have enough redeemable tickets.");
        for( uint256 exchange = 0; exchange < _ticketNumbers.length; exchange ++ ){
            createTicket( msg.sender, _ticketNumbers[ exchange ], currentRound);
            exchangeableTickets[msg.sender] -= 1;
        }
        emit TicketBought(currentRound, msg.sender, _ticketNumbers.length, userTickets[ currentRound ][ msg.sender ]);
    }

    // Get Tickets for a specific round
    function getRoundTickets(uint256 _round) public view returns( Ticket[] memory tickets) {
      return userTickets[ _round ][ msg.sender ];
    }

    // ClaimReward
    function isNumberWinner( uint256 _round, uint256 luckyTicket ) public view returns( bool _winner, uint8 _match){
        uint256 roundWinner = winnerNumbers[ _round ];
        require( roundWinner > 0 , "Winner not yet determined" );
        _match = 0;
        uint256 luckyNumber = standardTicketNumber( luckyTicket, WINNER_BASE, MAX_BASE);
        uint[6] memory winnerDigits = getDigits( roundWinner );
        uint[6] memory luckyDigits = getDigits( luckyNumber );
        for( uint8 i = 0; i < 6; i++){
            if( !_winner ){
                if( winnerDigits[i] == luckyDigits[i] ){
                    _match = 6 - i;
                    _winner = true;
                }
            }
        }
        if(!_winner)
            _match = 0;
    }

    function claimNumber(uint256 _round, uint256 luckyTicket) public {
        // Check if round is over
        require( winnerNumbers[_round] > 0, "Round not done yet");
        // check if Number belongs to caller
        Ticket[] memory ownedTickets = userTickets[ _round ][ msg.sender ];
        require( ownedTickets.length > 0, "It would be nice if I had tickets");
        uint256 ticketCheck = standardTicketNumber(luckyTicket, WINNER_BASE, MAX_BASE);
        bool ownsTicket = false;
        uint256 ticketIndex = 0;
        for( uint i = 0; i < ownedTickets.length; i ++){
            if( ownedTickets[i].ticketNumber == ticketCheck ){
                ownsTicket = true;
                ticketIndex = i;
            }
        }
        require( ownsTicket, "This ticket doesn't belong to you.");
        require( ownedTickets[ ticketIndex ].claimed == false, "Ticket already claimed");
        // GET AND TRANSFER TICKET CLAIM AMOUNT
        uint256[6] memory matches = [ match1, match2, match3, match4, match5, match6];
        (bool isWinner, uint amountMatch) = isNumberWinner(_round, luckyTicket);
        uint256 claimAmount = 0;
        uint[6] memory digits = getDigits( ticketCheck );
        
        if(isWinner){
            uint256 matchAmount = getFraction( roundPool[_round], matches[ amountMatch - 1 ], PERCENT_BASE);
            claimAmount = matchAmount.div( holders[ _round ][ digits[ 6 - amountMatch ] ] );
            if( bonusCoins[_round] != address(0) ){
                ERC20( bonusCoins[_round] )
                    .transfer( msg.sender,
                        getFraction(
                            ERC20( bonusCoins[ _round ]).balanceOf( address(this) ),
                            matches[ amountMatch - 1 ],
                            PERCENT_BASE
                        )
                    );
            }
        }
        else{
            uint256 totalWinners = 0;
            uint256[6] memory winnerDigits = getDigits( winnerNumbers[_round] );
            // Calculate no match holders and transfer that amount
            for( uint tw = 0; tw < 6; tw++ ){
                totalWinners += holders[ _round ][ winnerDigits[tw] ];
            }
            uint256 matchAmount = getFraction( roundPool[_round], noMatch, PERCENT_BASE);
            if( bonusCoins[_round] != address(0) ){
                ERC20( bonusCoins[_round] )
                    .transfer( msg.sender,
                        getFraction(
                            ERC20( bonusCoins[ _round ]).balanceOf( address(this) ),
                            noMatch,
                            PERCENT_BASE
                        )
                    );
            }
            // matchAmount / nonWinners
            claimAmount = matchAmount.div( calcNonWinners( _round, totalWinners ) );
        }
        crush.transfer( msg.sender, claimAmount );
        userTickets[ _round ][ msg.sender ][ ticketIndex ].claimed = true;
        emit TicketClaimed(_round, msg.sender, ownedTickets[ ticketIndex ] );
    }

    function calcNonWinners( uint256 _round, uint256 totalPlayers) internal view returns (uint256 nonWinners){
        uint256 ticketsSold = totalTickets[ _round ];
        nonWinners = ticketsSold.sub( totalPlayers );
    }
    // AddToPool
    function addToPool(uint256 _amount) public {
        uint256 userBalance = crush.balanceOf( msg.sender );
        require( userBalance >= _amount, "Insufficient Funds to Send to Pool");
        crush.transferFrom( msg.sender, address(this), _amount);
        roundPool[ currentRound ] = roundPool[ currentRound ].add( _amount );
        emit FundPool( currentRound, _amount);
    }

    // OPERATOR FUNCTIONS
    // Starts a new Round
    // @dev only applies if current Round is over
    function firstStart() public operatorOnly{
        require(currentRound == 0, "First Round only");
        startRound();
    }

    function startRound() internal {
        require( currentIsActive == false, "Current Round is not over");
        // Add new Round
        currentRound ++;
        currentIsActive = true;
        roundStart = block.timestamp;
        emit RoundStarted( currentRound, msg.sender, block.timestamp);
    }
    
    // Ends current round This will always be after 12pm GMT -6 (6pm UTC)
    function endRound() public{
        require( LINK.balanceOf(address(this)) >= feeVRF, "Not enough LINK - please contact mod to fund to contract" );
        require( currentIsActive == true, "Current Round is over");
        require ( block.timestamp > roundStart + 3600, "Can't end round immediately");
        uint endHour = getHour(block.timestamp);
        uint sec = getSecond(block.timestamp);
        require( endHour >= 18 && sec > 0, "End Time hasn't been reached" );

        currentIsActive = false;
        // Request Random Number for Winner
        bytes32 rqId = requestRandomness( keyHashVRF, feeVRF);
        emit SelectionStarted(currentRound, msg.sender, rqId);
    }
    // BURN AND ROLLOVER
    function distributeCrush() internal {
        uint256 rollOver;
        uint256 burnAmount;

        (rollOver, burnAmount) = calculateRollover();
        crush.burn( burnAmount );
        roundPool[ currentRound + 1 ] = rollOver;
    }

    function calculateRollover() internal returns( uint256 _rollover, uint256 _burn ) {
        uint totalPool = roundPool[currentRound];
        _rollover = 0;
        // for zero match winners
        uint roundTickets = totalTickets[currentRound];
        uint256 currentWinner = winnerNumbers[currentRound];
        uint256[6] memory winnerDigits = getDigits(currentWinner);
        uint256[6] memory matchPercents = [ match6, match5, match4, match3, match2, match1 ];
        uint256[6] memory matchHolders;
        uint256 totalMatchHolders = 0;
        uint256 bonusRollOver = 0;
        uint256 bonusTotal;
        if( bonusCoins[ currentRound ] != address(0) ){
            bonusTotal = ERC20(bonusCoins[currentRound]).balanceOf( address(this) );
        }
        for( uint8 i = 0; i < 6; i ++){
            uint256 digitToCheck = winnerDigits[i];
            matchHolders[i] = holders[currentRound][digitToCheck];
            if( matchHolders[i] > 0 ){
                if(i == 0){
                    totalMatchHolders = matchHolders[i];
                }
                else{
                    matchHolders[i] = matchHolders[i].sub(totalMatchHolders);
                    totalMatchHolders = totalMatchHolders.add( matchHolders[i] );
                    holders[currentRound][digitToCheck] = matchHolders[i];
                }
            }
            // single check to remove duplicate code
            if(matchHolders[i] == 0){
                _rollover = _rollover.add( getFraction(totalPool, matchPercents[i], PERCENT_BASE) );
                if( bonusCoins[ currentRound ] != address(0) ){
                    bonusRollOver += getFraction( bonusTotal, matchPercents[i], PERCENT_BASE);
                }
            }
        }
        uint256 nonWinners = roundTickets.sub(totalMatchHolders);
        // Are there any noMatch tickets
        if( nonWinners == 0 ){
            _rollover += getFraction(totalPool, noMatch, PERCENT_BASE);
            if( bonusCoins[ currentRound ] != address(0) ){
                bonusRollOver += getFraction( bonusTotal, noMatch, PERCENT_BASE);
            }
        }

        // Transfer bonus coin excedent to devAddress
        if(bonusRollOver > 0){
            ERC20(bonusCoins[currentRound]).transfer(devAddress, bonusTotal.sub(bonusRollOver) );
        }
        _burn = getFraction( totalPool, burn, PERCENT_BASE);
        
    }
    
    // Add or remove operator
    function toggleOperator( address _operator) public operatorOnly{
        bool operatorIsActive = operators[ _operator ];
        if(operatorIsActive){
            operators[ _operator ] = false;
        }
        else {
            operators[ _operator ] = true;
        }
        emit OperatorChanged(_operator, operators[msg.sender] );
    }
    
    // GET Verifiable RandomNumber from VRF
    // This gets called by VRF Contract only
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint winnerNumber = standardTicketNumber(randomness, WINNER_BASE, MAX_BASE);
        winnerNumbers[currentRound] = winnerNumber;
        distributeCrush();
        emit WinnerPicked(currentRound, winnerNumber, requestId);
        startRound();
    }
    
    // HELPFUL FUNCTION TO TEST WITHOUT GOING LIVE
    function setWinner( uint256 randomness ) public operatorOnly{
        uint winnerNumber = standardTicketNumber(randomness, WINNER_BASE, MAX_BASE);
        winnerNumbers[currentRound] = winnerNumber;
        emit WinnerPicked(currentRound, winnerNumber, "ADMIN_SET_WINNER");
    }
    
    // PURE FUNCTIONS
    // Function to get the fraction amount from a value
    function getFraction(uint256 _amount, uint256 _percent, uint256 _base) internal pure returns(uint256 fraction) {
        return _amount.mul( _percent ).div( _base );
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

    

    // -------------------------------------------------------------------
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
    uint constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint constant SECONDS_PER_HOUR = 60 * 60;
    uint constant SECONDS_PER_MINUTE = 60;

    function getHour(uint timestamp) internal pure returns (uint hour) {
        uint secs = timestamp % SECONDS_PER_DAY;
        hour = secs / SECONDS_PER_HOUR;
    }
    function getMinute(uint timestamp) internal pure returns (uint minute) {
        uint secs = timestamp % SECONDS_PER_HOUR;
        minute = secs / SECONDS_PER_MINUTE;
    }
    function getSecond(uint timestamp) internal pure returns (uint second) {
        second = timestamp % SECONDS_PER_MINUTE;
    }
}