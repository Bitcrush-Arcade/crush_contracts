const { expectRevert } = require('@openzeppelin/test-helpers');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup');

const MetaCoin = artifacts.require("MetaCoin");
const MetaCoin = artifacts.require("MainBridge");

// These tests are for our main bridge contract that can work both as a main chain bridge (lock/unlock) and as a side bridge (mint/burn). 
// In order to bridge or recieve tokens correctly, the type of the bridge has to be specified both bridges. 
// accounts[0] contract owner address
// accounts[1] user address
// accounts[2] bridge address
// accounts[3] gateway address
// accounts[4] user address in the other blockchain

contract('mainBridgeTest', (accounts) => {
  beforeEach( async() => {

    this.token = await metaCoin.new('Nice Token','NICE');
    this.bridge = await metaBridge.new();
  
  });

  // addValidChain(struct chainId) onlyOwner
  // validChains stores all the chains where we have implemented bridges and token contracts
  it('Should allow owner only to add valid chainId', async() => {
  
    // Checking if onlyOwner
    await expectRevert(this.bridge.addValidChain(2222, {from: accounts[1]}), 'onlyOwner');
        
    // Checking if chain was already valid
    const isValid = await this.bridge.validChains('2222');
    assert.ok(!isValid, 'Chain was already valid');

    // Adding valid chainId 
    await this.bridge.addValidChain(2222, {from: accounts[0]});
    const validChain = await this.bridge.validChains('2222');
    assert.ok(validChain, 'Chain was not valid');

  });

  // addToken(address tokenAddress, uint 256 tokenFee, bool bridgeType, bool status) onlyOwner.
  // bridgeType is the type of bridge implemented on target chain. True for lock/unlock, false for mint/burn.
  // tokenMap stores all the implemented token contracts in other chains.
  // Fee has a min and a max. 
  it('Should allow owner only to add valid chainId', async() => {

    // Checking if onlyOwner
    await expectRevert(this.bridge.addToken(1111, 1, false, true, {from: accounts[1]}), 'onlyOwner');
        
    // Checking if token was already added
    const isValid = await this.bridge.tokenMap('1111').status;
    assert.ok(!isValid, 'Token was already added');

    // Adding token
    await this.bridge.addToken(this.bridge.addToken(1111, 1, false, true, {from: accounts[0]}));
    const addedToken = await this.bridge.tokenMap('1111').status;
    assert.ok(addedToken, 'Token was not added');

  });

  // setBridge(bool type) onlyOwner allows owner to set this type of bridge to true (lock/unlock)  or false (mint/burn)
  // const bridgeType = bool
  it('Should allow owner to set this bridge type', async() => {

    // Checking if lock/unlock by default
    const bridgeType = await this.bridge.bridgeType;
    assert.ok(!bridgeType, 'Bridge should be mint/burn by default');

    // Checking if onlyOwner
    await expectRevert(this.bridge.setBridge(true, {from: accounts[1]}), 'onlyOwner');

    // setBridge
    await this.bridge.setBridge(true, {from: accounts[0]});
    const isSet = await this.bridge.bridgeType;
    assert.ok(isSet, 'Bridge was not correctly set');

  });


  // RequestBridge(address userAddress, uint256 chainId, uint256 tokenAddress, uint256 amount) external
  it('Should allow user to request bridge to send tokens to another chain', async () => {
    
    // Adding valid chain
    await this.bridge.addValidChain(2222, {from: accounts[0]});

    // Adding token
    await this.bridge.addToken(this.bridge.addToken(1111, 1, false, true, {from: accounts[0]}));

    // Minting tokens to user
    await this.token.mint(accounts[1], 10,{ from: accounts[0]});

    // User approves bridge
    await this.token.approve(accounts[2], 8, {from: accounts[1]});

    // Checking that the bridge only happens to valid chain ID. Valid chain ID is 2222 checking revert first.
    await expectRevert(this.bridge.requestBridge(accounts[4], 1234, 1111, 3, {from: accounts[1]}), 'requestBridge to invalid chain ID' );

    // Checking that the bridge only happens to added tokens. Working token address is 1111 checking revert first.
    await expectRevert(this.bridge.requestBridge(accounts[4], 2222, 1234, 3, {from: accounts[1]}), 'requestBridge to invalid token address' );

    // Checking if external
    await expectRevert(this.bridge.requestBridge(accounts[4], 2222, 1111, 3, {from: accounts[0]}), 'External');

    // bridgeType == false (mint/burn)
    // Executing the function from user address and valid chainId main chain. 
    await this.bridge.requestBridge(accounts[4], 2222, 1111, 3, {from: accounts[1]});
    const burnedBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(burnedBalance, '5', 'Tokens are not burned from user account correctly');

    // bridgeType == true (lock/unlock)
    // Executing the function from user address and valid chainId main chain. 
    await this.bridge.setBridge(true);
    await this.bridge.requestBridge(accounts[4], 2222, 1111, 4, {from: accounts[1]});
    
    // Checking user balance
    const userBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(userBalance, '1', 'Tokens are not being locked correctly');

    // Checking bridge balance
    const bridgeLockedBalance = new BN(await this.token.balanceOf(accounts[2])).toString();
    assert.equal(bridgeBalance, '4', 'Tokens are not being locked correctly');

  });

  // sendTransactionSuccess(uint256 hash) onlyGateway
  it('Should emit bridge success', async() => {
    
    // Checking if onlyGateway
    await expectRevert(this.bridge.sendTransactionSuccess(3333, {from: accounts[1]}), 'onlyGateway');

    // Checking if transaction success event is being emitted 
    const wasSent = await this.bridge.sendTransactionSuccess(3333, {from: accounts[3]});
    assert.ok(wasSent, 'txn success event is not being emitted');

  });

  // sendTransactionFailiure(uint256 hash, address userAddress, uint256 amount) onlyGateway
  it('Should emit bridge failiure and refund', async() => {
  
    // Checking if onlyGateway
    await expectRevert(this.bridge.sendTransactionFailiure(3333, accounts[1], 3, {from: accounts[1]}), 'onlyGateway');

    // Checking transaction failiure, mint refund
    await this.bridge.sendTransactionFailiure(3333, accounts[1], 3, {from: accounts[3]});
    const mintedBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(userFinalBalance, '3', 'Amount is not minted back');

    // Checking transaction failiure, unlock refund 
    await this.bridge.setBridge(true);
    await this.token.mint(accounts[2], 5,{ from: accounts[0]});
    await this.bridge.sendTransactionFailiure(3333, accounts[1], 5, {from: accounts[3]});

    const transferedUserBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    const transferedBridgeBalance = new BN(await this.token.balanceOf(accounts[2])).toString();

    assert.equal(transferedUserBalance, '8', 'Amount is not transfered back');
    assert.equal(transferedBridgeBalance, '0', 'Amount is not transfered from bridge');
    
  });

  // recieveTransactionSuccess(address userAddress, uint256 amount, uint256 fromChainID) onlyGateway
  it('Should recieve transaction success', async() => {

    // Checking valid chainId
    await expectRevert(this.bridge.recieveTransactionSuccess(accounts[1], 3, 1234, {from: accounts[3]}), 'Invalid chainId' );

     // Adding valid chain
     await this.bridge.addValidChain(2222, {from: accounts[0]});

    // Adding token
    await this.bridge.addToken(this.bridge.addToken(1111, 1, false, true, {from: accounts[0]}));

    // Checking if onlyGateway
    await expectRevert(this.bridge.recieveTransactionSuccess(accounts[1], 3, 2222, {from: accounts[1]}), 'onlyGateway');

    // Recieving from valid chain, bridgeType == false (mint/burn), should mint to user
    await this.bridge.recieveTransactionSuccess(accounts[1], 3, 2222, {from: accounts[3]});
    const userFinalBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(userFinalBalance, '3', 'Amount is not being refunded');

    // Recieving from valid chain, bridgeType == true (lock/unlock), should transfer to user
    await this.bridge.setBridge(true);
    await this.token.mint(accounts[2], 5,{ from: accounts[0]});
    await this.bridge.recieveTransactionSuccess(accounts[1], 5, 2222, {from: accounts[3]});
    
    const transferUserBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    const transferBridgeBalance = new BN(await this.token.balanceOf(accounts[2])).toString();
    
    assert.equal(transferUserBalance, '8', 'Amount is not being refunded');
    assert.equal(transferBridgeBalance, '0', 'Amount is not being refunded');

  });
    
});


