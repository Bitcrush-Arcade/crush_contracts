// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Remix style import
//import { IERC20 } from "@openzeppelin/contracts@4.0.0/token/ERC20/IERC20.sol";

// Imports
import './NiceTokenErc20.sol'; //Depends on chain, BEP for BSC, ERC for FTM
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title MetaBridge
/// @notice Communicates with a BEP20 CRUSH and NICE tokens, it either locks or burns tokens depending on type
/// @dev $NICE will have a Burn From fn
contract InvaderverseBridge is Ownable, ReentrancyGuard {

    using SafeERC20 for NiceTokenFtm;
    using SafeMath for uint;
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

    address public gateway;

    event ChainEdit(uint _chainId, bool _active);
    event TokensLocked(address indexed requester, address indexed token, bytes32 indexed mainDepositHash);
    event TokensUnlocked(address indexed requester, bytes32 indexed sideDepositHash);
    event RequestBridge(address indexed requester, bytes32 bridgeHash);
    event BridgeSuccess(address indexed requester, bytes32 bridgeHash);
    event BridgeFailed(address indexed requester, bytes32 bridgeHash);
    event FulfillBridgeRequest(uint _otherChainId, bytes32 _otherChainHash);
    event ModifiedBridgeToken(uint indexed _chain, address indexed _token, bool _type, bool _status);
    event MirrorBurned(address tokenAddress, uint256 otherChain, uint256 amount, bytes32 otherChainHash);
    event SetGateway(address gatewayAddress);
    event SetDev(address dev);
    /// Modifiers
    modifier onlyGateway {
        require(msg.sender == gateway, "onlyGateway");
        _;
    }
    /// Constructor
    constructor () {
        gateway = msg.sender;
        devAddress = msg.sender;
    }

    /// External Functions
    function requestBridge(
        address _receiverAddress,
        uint _chainId,
        address _tokenAddress,
        uint _amount
    ) external nonReentrant returns(bytes32 _bridgeHash){
        require(validChains[_chainId], "Invalid Chain");
        BridgeToken storage tokenInfo = validTokens[_chainId][_tokenAddress];
        
        require(tokenInfo.status, "Invalid Token");
        NiceTokenFtm bridgedToken = NiceTokenFtm(_tokenAddress);

        // Calcualte fee and apply to transfer
        
        // Transferring funds to bridge wallet and fee to dev
        if(tokenInfo.tokenFee > 0){
            bridgedToken.safeTransferFrom(msg.sender, devAddress, _amount.mul(tokenInfo.tokenFee).div(DIVISOR));
        }
        _bridgeHash = keccak256(abi.encode(_amount, msg.sender, _receiverAddress, block.timestamp, _tokenAddress, _chainId));
        
        if(tokenInfo.bridgeType){
            bridgedToken.safeTransferFrom(msg.sender, address(this), _amount);
            emit TokensLocked( msg.sender, _tokenAddress, _bridgeHash);
        }
        else
            bridgedToken.bridgeBurnFrom(msg.sender, _amount);
        
        transactions[_bridgeHash] = BridgeTx(_amount, msg.sender, _receiverAddress, block.timestamp, _tokenAddress, _chainId, bytes32(0));

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
    function sendTransactionSuccess(bytes32 _thisChainHash, bytes32 _otherChainHash) external onlyGateway nonReentrant{
        BridgeTx storage transaction = transactions[_thisChainHash];
        require(transaction.amount > 0, "Invalid Hash");
        require(transaction.otherChainHash == bytes32(0), "Hash already claimed");
        transaction.otherChainHash = _otherChainHash;
        emit BridgeSuccess(transaction.sender, _thisChainHash);
    }
    /// @notice When transaction fails, we proceed to emit an event and refund the tokens
    /// @param _thisChainHash tx hash to update mapping of.
    function sendTransactionFailure(bytes32 _thisChainHash) external onlyGateway nonReentrant{
        BridgeTx storage transaction = transactions[_thisChainHash];
        require(transaction.amount > 0, "Invalid Hash");
        require(transaction.otherChainHash == bytes32(0), "Hash already claimed");
        BridgeToken storage tokenInfo = validTokens[transaction.otherChainId][transaction.tokenAddress];
        require(transaction.tokenAddress != address(0), "InvalidToken");

        transaction.otherChainHash = bytes32("1");
        if(tokenInfo.bridgeType){
            NiceTokenFtm(transaction.tokenAddress).safeTransfer(transaction.sender,transaction.amount);
            emit TokensUnlocked(transaction.sender, _thisChainHash);
        }
        else{
            NiceTokenFtm(transaction.tokenAddress).mint(transaction.sender, transaction.amount);
        }
        emit BridgeFailed(transaction.sender, _thisChainHash);
    }
    /// @notice Gateway notifies Blockchain that it's receiving a transaction
    /// @param _receiver Address to receive the funds
    /// @param _amount Amount to send to _receiver
    /// @param _tokenAddress token that is being bridged
    /// @param _otherChainId Chain ID the request comes from
    /// @param _otherChainHash Hash Pairing on otherChain
    function fulfillBridge(address _receiver, uint _amount, address _tokenAddress, uint _otherChainId, bytes32 _otherChainHash) external onlyGateway nonReentrant{

        BridgeToken storage tokenInfo = validTokens[_otherChainId][_tokenAddress];
        require(tokenInfo.status, "Invalid Token");

        if(tokenInfo.bridgeType){
            require(NiceTokenFtm(_tokenAddress).balanceOf(address(this)) >= _amount, "Insufficient Locked Balance");
            NiceTokenFtm(_tokenAddress).safeTransfer(_receiver, _amount);
        }
        emit FulfillBridgeRequest(_otherChainId, _otherChainHash);

    }

    function mirrorBurn(address _tokenAddress, uint _amount, uint _fromChain, bytes32 _burnHash) external onlyGateway{
        NiceTokenFtm(_tokenAddress).burn(_amount);
        emit MirrorBurned(_tokenAddress, _fromChain, _amount, _burnHash );
    }
    // Owner functions
    function toggleChain(uint _chainID) external onlyOwner{
        validChains[_chainID] = !validChains[_chainID];
        emit ChainEdit(_chainID, validChains[_chainID]);
    }
    /// @notice Add token to map. This map holds the properties of each token/bridge implementation. These properties are used in
    /// most of this bridge's functions.
    /// @param _thisChainTokenAddress the token's address on this chain
    /// @param tokenFee fee that will be charged for the bridge transaction. Fee is always charged on the sender chain.
    /// @param bridgeType type of bridge implemented on this chain, false => mint/burn, true => lock/unlock
    /// @param status true for on, false for off
    /// @param _otherChainId the other chain ID, where we have the receiver
    function addToken(address _thisChainTokenAddress, uint tokenFee, bool bridgeType, bool status, uint _otherChainId) external onlyOwner{
        validTokens[_otherChainId][_thisChainTokenAddress] = BridgeToken(tokenFee, bridgeType, status);
        emit ModifiedBridgeToken(_otherChainId, _thisChainTokenAddress, bridgeType, status);
    }
    /// @notice Set the Gateway user Address
    /// @param _gateway the address to set
    function setGateway(address _gateway) external onlyOwner{
        gateway = _gateway;
        emit SetGateway(_gateway);
    }
    /// @notice Set the Dev Address
    /// @param _devAddress the address to set
    function setDev(address _devAddress) external onlyOwner{
        devAddress = _devAddress;
        emit SetDev(_devAddress);
    }
}
