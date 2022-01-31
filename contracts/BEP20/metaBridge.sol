// Communicates with a BEP20 MetaCoin
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Remix style import
//import { IERC20 } from "@openzeppelin/contracts@4.0.0/token/ERC20/IERC20.sol";

//Brownie style import
import { IERC20 } from "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC20/IERC20.sol";

contract MainBridge {

    IERC20 private mainToken;

    address gateway;

    event TokensLocked(address indexed requester, bytes32 indexed mainDepositHash, uint amount, uint timestamp);
    event TokensUnlocked(address indexed requester, bytes32 indexed sideDepositHash, uint amount, uint timestamp);

    constructor (address _mainToken, address _gateway) {
        mainToken = IERC20(_mainToken);
        gateway = _gateway;
    }

    function lockTokens (address _requester, uint _bridgedAmount, bytes32 _mainDepositHash) onlyGateway external {
        emit TokensLocked(_requester, _mainDepositHash, _bridgedAmount, block.timestamp);
    }

    function unlockTokens (address _requester, uint _bridgedAmount, bytes32 _sideDepositHash) onlyGateway external {
        mainToken.transfer(_requester, _bridgedAmount);
        emit TokensUnlocked(_requester, _sideDepositHash, _bridgedAmount, block.timestamp);
    }

    modifier onlyGateway {
      require(msg.sender == gateway, "only gateway can execute this function");
      _;
    }
    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Child } from "./IERC20Child.sol";

contract SideBridge {

    event BridgeInitialized(uint indexed timestamp);
    event TokensBridged(address indexed requester, bytes32 indexed mainDepositHash, uint amount, uint timestamp);
    event TokensReturned(address indexed requester, bytes32 indexed sideDepositHash, uint amount, uint timestamp);
    
    IERC20Child private sideToken;
    bool bridgeInitState;
    address owner;
    address gateway;


    constructor (address _gateway) {
        gateway = _gateway;
        owner = msg.sender;
    }

    function initializeBridge (address _childTokenAddress) onlyOwner external {
        sideToken = IERC20Child(_childTokenAddress);
        bridgeInitState = true;
    }

    function bridgeTokens (address _requester, uint _bridgedAmount, bytes32 _mainDepositHash) verifyInitialization onlyGateway  external {
        sideToken.mint(_requester,_bridgedAmount);
        emit TokensBridged(_requester, _mainDepositHash, _bridgedAmount, block.timestamp);
    }

    function returnTokens (address _requester, uint _bridgedAmount, bytes32 _sideDepositHash) verifyInitialization onlyGateway external {
        sideToken.burn(_bridgedAmount);
        emit TokensReturned(_requester, _sideDepositHash, _bridgedAmount, block.timestamp);
    }

    modifier verifyInitialization {
      require(bridgeInitState, "Bridge has not been initialized");
      _;
    }
    
    modifier onlyGateway {
      require(msg.sender == gateway, "Only gateway can execute this function");
      _;
    }

    modifier onlyOwner {
      require(msg.sender == owner, "Only owner can execute this function");
      _;
    }
    

}

