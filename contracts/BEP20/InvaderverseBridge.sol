// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Remix style import
//import { IERC20 } from "@openzeppelin/contracts@4.0.0/token/ERC20/IERC20.sol";

//Brownie style import
import './MetaCoin.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MetaBridge
/// @notice Communicates with a BEP20 CRUSH and NICE tokens, it either locks or burns tokens depending on type
/// @dev $NICE will have a Burn From fn
contract MetaBridge is Ownable {

    using SafeERC20 for MetaCoin;

    uint constant DIVISOR = 100000;
    address public devAddress;

    struct BridgeToken{
        uint tokenFee;
        bool bridgeType; // true => lock/unlock; false => mint/burn
        bool status;
        // bool hasBurnFrom;
    }
    struct BridgeTx{
        uint amount;
        address sender;
        address receiver;
        uint requestTime;
        address tokenAddress;
        uint otherChainId;
        bytes32 otherChainHash;
    }

    uint public lockDuration = 3600; // Minimum lock time before unlocking/failing 1 hour

    mapping( bytes32 => BridgeTx) public transactions;
    mapping( uint => bool) public validChains; // key1 = otherChainId
    mapping( uint => mapping( address => BridgeToken)) public validTokens; // Key1 = otherChainId, key2 = thisChainTokenAddress

    MetaCoin private mainToken;

    address public gateway;

    event ChainEdit(uint _chainId, bool _active);
    event TokensLocked(address indexed requester, address indexed token, bytes32 indexed mainDepositHash);
    event TokensUnlocked(address indexed requester, bytes32 indexed sideDepositHash);
    event RequestBridge(address indexed requester, bytes32 bridgeHash);
    event BridgeSuccess(address indexed requester, bytes32 bridgeHash);
    event BridgeFailed(address indexed requester, bytes32 bridgeHash);
    event FulfillBridgeRequest(uint _otherChainId, bytes32 _otherChainHash);
    event ModifiedBridgeToken(uint indexed _chain, address indexed _token, bool _type, bool _status);
    /// Modifiers
    modifier onlyGateway {
        require(msg.sender == gateway, "Only gateway can execute this function");
        _;
    }
    /// Constructor
    constructor (address _gateway, address _dev) {
        gateway = _gateway;
        devAddress = _dev;
    }

    /// External Functions
    function requestBridge(address _receiverAddress, uint _chainId, address _tokenAddress, uint _amount) external returns(bytes32 _bridgeHash){
        require(validChains[_chainId], "Invalid Chain");
        BridgeToken storage tokenInfo = validTokens[_chainId][_tokenAddress];
        
        require(tokenInfo.status, "Invalid Token");
        MetaCoin bridgedToken = MetaCoin(_tokenAddress);

        // Calcualte fee and apply to transfer
        uint fee = _amount.mul(tokenInfo.tokenFee).div(DIVISOR);
        
        // Transferring funds to bridge wallet and fee to dev
        bridgedToken.safeTransferFrom(msg.sender, address(this), _amount);
        bridgedToken.safeTransferFrom(msg.sender, devAddress, fee);
        
        _bridgeHash = keccak256(abi.encode(_amount, msg.sender, _receiverAddress, block.timestamp, _tokenAddress, _chainId));
        transactions[_bridgeHash] = BridgeTx(_amount, msg.sender, _receiverAddress, block.timestamp, _tokenAddress, _chainId, bytes32(0));

        if(tokenInfo.bridgeType)
            emit TokensLocked( msg.sender, _bridgeHash);
        else
            bridgedToken.burn(address(this), _amount);
        emit RequestBridge(msg.sender, _bridgeHash);
    }
    /// EMERGENCY FN
    /// @notice this function will check if lock duration has passed and then it retrieves the funds;
    // function emergencyCancelBridge()external{
    //     // check lock duration
    //     // && check if processed
    //     // if both true, refund/unlock the tokens/// PENDING
    // }
    /// onlyGateway
    /// @notice Notify blockchain that bridging was successful.
    /// @param _thisChainHash the hash that is successful.
    /// @param _otherChainHash the other chain hash to pair it with, we'll try to make this the txhash.
    function sendTransactionSuccess(bytes32 _thisChainHash, bytes32 _otherChainHash) external onlyGateway{
        BridgeTx storage transaction = transactions[_thisChainHash];
        require(transaction.amount > 0, "Invalid Hash");
        require(transaction.otherChainHash == bytes32(0), "Hash already claimed");
        transaction.otherChainHash = _otherChainHash;
        emit BridgeSuccess(transaction.sender, _thisChainHash);
    }
    /// @notice When transaction fails, we proceed to emit an event and refund the tokens
    /// @param _thisHash tx hash to update mapping of.
    function sendTransactionFailure(uint _thisHash) external onlyGateway{
        BridgeTx storage transaction = transactions[_thisChainHash];
        require(transaction.amount > 0, "Invalid Hash");
        require(transaction.otherChainHash == bytes32(0), "Hash already claimed");
        BridgeToken storage tokenInfo = validTokens[transaction.otherChainId][transaction.tokenAddress];
        require(transaction.tokenAddress != address(0), "InvalidToken");

        transaction.otherChainHash = bytes32(1);
        if(tokenInfo.bridgeType){
            MetaCoin(transaction.tokenAddress).safeTransfer(transaction.sender,transaction.amount);
            emit TokensUnlocked(transaction.sender, _thisChainHash);
        }
        else{
            MetaCoin(transaction.tokenAddress).mint(transaction.sender, transaction.amount);
        }
        emit BridgeFailed(transaction.sender, _thisChainHash);
    }
    /// @notice Gateway notifies Blockchain that it's receiving a transaction
    /// @param _receiver Address to receive the funds
    /// @param _amount Amount to send to _receiver
    /// @param _tokenAddress token that is being bridged
    /// @param _otherChainId Chain ID the request comes from
    /// @param _otherChainHash Hash Pairing on otherChain
    function fulfillBridge(address _receiver, uint _amount, address _tokenAddress, uint _otherChainId, bytes32 _otherChainHash) external onlyGateway{

        BridgeToken storage tokenInfo = validTokens[_otherChainId][_tokenAddress];
        require(tokenInfo.status, "Invalid Token");

        if(tokenInfo.bridgeType){
            require(MetaCoin(_tokenAddress).balanceOf(address(this)) >= _amount, "Insufficient Locked Balance");
            MetaCoin(_tokenAddress).safeTransfer(_receiver, _amount);
        }
        emit FulfillBridgeRequest(_otherChainId, _otherChainHash);

    }

    function mirrorBurn(address _tokenAddress, uint _amount, uint _fromChain, bytes32 _burnHash) onlyGateway{}
    // Owner functions
    function toggleChain(uint _chainID) external onlyOwner{
        validChains[_chainID] = !validChains[_chainID];
        emit ChainEdit(_chainID, validChains[_chainID]);
    }
    function addToken(address _thisChainTokenAddress, uint tokenFee, bool bridgeType, bool status, uint _otherChainId) external onlyOwner{
        validTokens[_otherChainId][_thisChainTokenAddress] = BridgeToken(tokenFee, bridgeType, status);
        emit ModifiedBridgeToken(_otherChainId, _thisChainTokenAddress, bridgeType, status);
    }
    /// Public Functions

    /// Internal Functions
    
    /// Pure Functions
}
