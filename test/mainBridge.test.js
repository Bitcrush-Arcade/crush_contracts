const { expectRevert } = require('@openzeppelin/test-helpers');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup');

const MetaCoin = artifacts.require("MetaCoin");
const MetaCoin = artifacts.require("MainBridge");

// These tests are for our main bridge contract that can work both as a main chain bridge (lock/unlock) and as a side bridge (mint/burn). 
// In order to bridge or recieve tokens correctly, the type of bridge involved in the other chain has to be specified when adding
// the token with the addToken function. 
// accounts[0] contract owner address
// accounts[1] user address
// accounts[2] bridge address
// accounts[3] gateway address
// accounts[4] user address in the other blockchain

contract('mainBridgeTest', (accounts) => {
  beforeEach( async() => {

    this.token = await MetaCoin.new('Nice Token','NICE');
    this.bridge = await MainBridge.new();
  
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


  // RequestBridge(address userAddress, uint256 chainId, uint256 tokenAddress, uint256 amount) external
  it('Should allow user to request bridge to send tokens to another chain', async () => {
    
    // Adding valid chain
    await this.bridge.addValidChain(2222, {from: accounts[0]});

     // Adding token
     await this.bridge.addToken(this.bridge.addToken(1111, 1, false, true, {from: accounts[0]}));

    // Minting tokens to user
    await this.token.mint(accounts[1], 5,{ from: accounts[0]});

    // User approves bridge
    await this.token.approve(accounts[2], 3, {from: accounts[1]});

    // Checking that the bridge only happens to valid chain ID. Valid chain ID is 2222 checking revert first.
    await expectRevert(this.bridge.requestBridge(accounts[4], 1234, 1111, 3, {from: accounts[1]}), 'requestBridge to invalid chain ID' );

    // Checking that the bridge only happens to added tokens. Working token address is 1111 checking revert first.
    await expectRevert(this.bridge.requestBridge(accounts[4], 2222, 1234, 3, {from: accounts[1]}), 'requestBridge to invalid token address' );

    // Checking if external
    await expectRevert(this.bridge.requestBridge(accounts[4], 2222, 1111, 3, {from: accounts[0]}), 'External');

    // Executing the function from Gateway address and valid chainId
    await this.bridge.requestBridge(accounts[4], 2222, 1111, 3, {from: accounts[1]});
    const finalBalance = new BN(await this.bridge.balanceOf(accounts[1])).toString();
    assert.equal(finalBalance, '2', 'Tokens are not burned from user account correctly');
      
  });

  // sendTransactionSuccess(uint256 hash) onlyGateway
  it('Should emit bridge success', async() => {
    
    // Checking if onlyGateway
    await expectRevert(this.bridge.sendTransactionSuccess(3333, {from: accounts[1]}), 'onlyGateway');

    // Checking if transaction success event is being emitted
    await this.bridge.sendTransactionSuccess(3333, {from: accounts[3]});
    assert.ok(txnHash, 'txn success event is not being emitted');

  });

  // sendTransactionFailiure(uint256 hash, address userAddress, uint256 amount) onlyGateway
  it('Should emit bridge failiure and refund', async() => {
  
    // Checking if onlyGateway
    await expectRevert(this.bridge.sendTransactionFailiure(3333, accounts[1], 3, {from: accounts[1]}), 'onlyGateway');

    // Checking transaction failiure
    await this.bridge.sendTransactionFailiure(3333, accounts[1], 3, {from: accounts[3]});
    const userFinalBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    
    // Checking if function was executed and if it refunded 
    assert.equal(userFinalBalance, '3', 'Amount is not being refunded');
    
  });

  // recieveTransactionSuccess(address userAddress, uint256 amount, uint256 fromChainID) onlyGateway
  it('Should recieve transaction success', async() => {

    // Checking if onlyGateway
    await expectRevert(this.bridge.recieveTransactionSuccess(accounts[1], 3, 2222, {from: accounts[1]}), 'onlyGateway');

    // Recieving from valid chain, should mint to user
    await this.bridge.recieveTransactionSuccess(accounts[1], 3, 2222, {from: accounts[3]});
    const userFinalBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
      
    // Checking if function was executed and if it minted
    assert.ok(txnHash, 'Recieved txn success event is not being emitted');
    assert.equal(userFinalBalance, '3', 'Amount is not being refunded');

  });
    
});


