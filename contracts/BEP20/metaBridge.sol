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

    struct BridgeToken{
        uint tokenFee;
        bool bridgeType; // true => lock/unlock; false => mint/burn
        bool status;
        // bool hasBurnFrom;
    }
    struct BridgeTx{
        uint amount;
        address sender;
        uint requestTime;
        address tokenAddress;
        uint otherChainId;
        bytes32 _otherChainHash;
    }

    uint public lockDuration = 3600; // Minimum lock time before unlocking/failing 1 hour

    mapping( bytes32 => BridgeTx) public transactions;
    mapping( uint => bool) public validChains; // key1 = otherChainId
    mapping( uint => mapping( address => BridgeToken)) public validTokens; // Key1 = otherChainId, key2 = thisChainTokenAddress

    MetaCoin private mainToken;

    address public gateway;

    event RequestBridge(address indexed requester, bytes32 bridgeHash);
    event TokensLocked(address indexed requester, address indexed token, bytes32 indexed mainDepositHash);
    event TokensUnlocked(address indexed requester, bytes32 indexed sideDepositHash);
    /// Modifiers
    modifier onlyGateway {
        require(msg.sender == gateway, "Only gateway can execute this function");
        _;
    }
    /// Constructor
    constructor (address _gateway) {
        gateway = _gateway;
    }

    /// External Functions
    function requestBridge(address _receiverAddress, uint _chainId, address _tokenAddress, uint _amount) external returns(bytes32 _bridgeHash){
        require(validChains[_chainId], "Invalid Chain");
        BridgeToken storage tokenInfo = validTokens[_chainId][_tokenAddress];
        require(tokenInfo.status, "Invalid Token");
        MetaCoin bridgedToken = MetaCoin(_tokenAddress);
        bridgedToken.safeTransferFrom(msg.sender,address(this),_amount);
        
        _bridgeHash = keccak256(abi.encodePacked(_amount, msg.sender , block.timestamp, _tokenAddress, _chainId));
        transactions[_bridgeHash] = BridgeTx(_amount, msg.sender, block.timestamp, _tokenAddress, _chainId, bytes32(0));

        if(tokenInfo.bridgeType)
            emit TokensLocked( msg.sender, _bridgeHash);
        else
            bridgedToken.burn(address(this), _amount);
        emit RequestBridge(msg.sender, _bridgeHash);
    }
    /// EMERGENCY FN
    /// @notice this function will check if lock duration has passed and then it retrieves the funds;
    function emergencyCancelBridge()external{
        // check lock duration
        // && check if processed
        // if both true, refund/unlock the tokens/// PENDING
    }
    /// onlyGateway
    function sendTransactionSuccess(bytes32 _thisChainHash, bytes32 _otherChainHash,) external onlyGateway{
    }
    function sendTransactionFailure(uint _nonce) external onlyGateway{
    }
    function receiveTransaction(uint _nonce) external onlyGateway{
    }
    // Owner functions
    function toggleChain(uint _newChainId) external onlyOwner{
    }
    function addToken(address _thisChainTokenAddress, uint tokenFee, bool bridgeType, bool status, uint _otherChainId) external onlyOwner{
    }
    /// Public Functions

    /// Internal Functions
    
    /// Pure Functions
}
