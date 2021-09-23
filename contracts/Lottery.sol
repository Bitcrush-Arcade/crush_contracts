// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// VRF
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
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
    mapping( uint256 => mapping( uint256 => uint256 ) ) public holders; // ROUND => DIGITS => #OF HOLDERS
    mapping( uint256 => mapping( uint256 => uint256 ) ) public claimed; // ROUND => DIGITS => #OF Digits Claimed
    mapping( uint256 => mapping( address => Ticket[] ) )public userTickets; // User Bought Tickets
    
    mapping( address => bool ) public operators; //Operators allowed to execute certain functions
    
    
    // EVENTS
    event OperatorChanged ( address indexed operators, bool active_status );
    event RoundStarted(uint256 indexed _round, address indexed _starter, uint256 _timestamp );
    event TicketBought(uint256 indexed _round, address indexed _user, uint256 _ticketsEmmited , Ticket[] tickets );
    event SelectionStarted( uint256 indexed _round, address _caller, bytes32 _requestId);
    event WinnerPicked(uint256 indexed _round, uint256 _winner, bytes32 _requestId);
    
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
        crush = ERC20(_crush);
        devAddress = msg.sender;
        operators[msg.sender] = true;
        owner = msg.sender;
    }
    
    // USER FUNCTIONS
    // Buy Tickets to participate in current Round
    // @args takes in an array of uint values as the ticket IDs to buy
    // @dev max bought tickets at any given time shouldn't be more than 10
    function buyTickets( uint256[] calldata _ticketNumbers ) external {
        require(_ticketNumbers.length > 0, "Can't buy zero tickets");
        require(currentIsActive == true, "Round not active");
        
        // Check if User has funds for ticket
        uint userCrushBalance = crush.balanceOf( msg.sender );
        uint ticketCost = ticketValue.mul( _ticketNumbers.length ).mul( 10 **18 );
        require( userCrushBalance >= ticketCost, "Not enough funds to purchase Tickets" );
        
        // Add Tickets to respective Mappings
        for( uint i = 0; i < _ticketNumbers.length; i++ ){
            uint256 currentTicket = _ticketNumbers[i];
            
            if( currentTicket < 1000000 ){
                currentTicket += 1000000;
            }
            uint[6] memory digits = getDigits( currentTicket );
            for( uint j = 0; j < digits.length; j ++){
                holders[ currentRound ][ digits[j] ] += 1;
            }
            Ticket memory ticket = Ticket(currentTicket, false);
            userTickets[ currentRound ][ msg.sender ].push( ticket );
        }
        
        uint devCut = getFraction( ticketCost, devTicketCut, PERCENT_BASE );
        crush.transferFrom( msg.sender, address(this), ticketCost.sub(devCut) );
        crush.transferFrom( msg.sender, devAddress, devCut );
        totalTickets[currentRound] += _ticketNumbers.length;

        emit TicketBought( currentRound, msg.sender, _ticketNumbers.length, userTickets[ currentRound ][ msg.sender ] );
        
    }
    // Get Tickets for a specific round
    function getRoundTickets(uint256 _round) public view returns( Ticket[] memory tickets) {
      return userTickets[ _round ][ msg.sender ];
    }

    // ClaimReward
    // AddToPool
    // AddLink (?)
    
    // OPERATOR FUNCTIONS
    // Starts a new Round
    // @dev only applies if current Round is over
    function startRound() public operatorOnly{
        require( currentIsActive == false, "Current Round is not over");
        
        // Check if previous Winner Number has already been given, if First round hasn't started, set default value
        uint currentRoundWinner;
        if( currentRound == 0) currentRoundWinner = 1000000;
        else currentRoundWinner = winnerNumbers[currentRound];
        require( currentRoundWinner > 0, "No winner yet, can't start a new Round");

        // Add new Round
        currentRound ++;
        currentIsActive = true;
        roundStart = block.timestamp;
        emit RoundStarted( currentRound, msg.sender, block.timestamp);
    }
    
    // Ends current round This will always be 12pm GMT -6 (6pm UTC)
    // TODO!!!!
    function endRound() public operatorOnly{

        require( LINK.balanceOf(address(this)) >= feeVRF, "Not enough LINK - please add funds to contract" );

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

    function distributeCrush() external operatorOnly{
        require( currentIsActive == false, "Round in progress");
        uint256 rollOver;
        uint256 burnAmount;

        (rollOver, burnAmount) = calculateRollover();
        crush.burn( burnAmount );
        roundPool[ currentRound + 1 ] = rollOver;
    }

    function calculateRollover() internal view returns( uint256 _rollover, uint256 _burn ) {
        uint totalPool = roundPool[currentRound];
        _rollover = 0;
        // for zero match winners
        uint roundTickets = totalTickets[currentRound];
        uint256 currentWinner = winnerNumbers[currentRound];
        uint256[6] memory winnerDigits = getDigits(currentWinner);
        uint256[6] memory matchPercents = [ match6, match5, match4, match3, match2, match1 ];
        
        for( uint8 i = 0; i < 6; i ++){
            uint digitHolders = winnerDigits[i];
            if( digitHolders > 0){
                roundTickets = roundTickets.sub(digitHolders);
                _rollover += getFraction(totalPool, matchPercents[i], PERCENT_BASE );
            }
        }
        // Are there any noMatch tickets
        if( roundTickets > 0 ){
            _rollover += getFraction(totalPool, noMatch, PERCENT_BASE);
        }
        _burn = getFraction( totalPool, burn, PERCENT_BASE);
        
        _rollover += _burn;
        _rollover = totalPool.sub( _rollover );
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
        uint winnerNumber = randomness.add(1000000);
        winnerNumbers[currentRound] = winnerNumber;
        emit WinnerPicked(currentRound, winnerNumber, requestId);
    }
    
    // PURE FUNCTIONS
    // Function to get the fraction amount from a value
    function getFraction(uint256 _amount, uint256 _percent, uint256 _base) internal pure returns(uint256 fraction) {
        return _amount.mul( _percent ).div( _base );
    }
   
    // Get all participating digits from number
    function getDigits( uint256 _ticketNumber ) internal pure returns(uint256[6] memory digits){
        uint256[6] memory destructuredNumber;
        digits[0] = _ticketNumber.div(1000000);
        digits[1] = _ticketNumber.div(100000);
        digits[2] = _ticketNumber.div(10000);
        digits[3] = _ticketNumber.div(1000);
        digits[4] = _ticketNumber.div(100);
        digits[5] = _ticketNumber.div(10);
        return destructuredNumber;
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