const { expectRevert } = require('@openzeppelin/test-helpers');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup');

const MetaCoin = artifacts.require("MetaCoin");
const MetaBridge = artifacts.require("MainBridge");

// These tests are for our main bridge contract that connects tokens in EVM chains. This bridge contract can work both as a main chain bridge (lock/unlock) 
// and as a side bridge (mint/burn), depending on the token that's being bridged or recieved.  
// The type of bridge has to be specified for the token on both bridges. 
// accounts[0] contract owner address
// accounts[1] user1
// accounts[2] other user
// accounts[3] gateway address
// accounts[4] user1 recieving wallet on other chain
// accounts[5] dev wallet
// accounts[6] user2 receiving wallet on other chain

contract('metaBridgeTest', ([minter, user1, user2, gateway, receiver1, dev, receiver2]) => {
  beforeEach( async() => {

    this.token1 = await MetaCoin.new('Nice Token','NICE',{from: minter});
    this.token2 = await MetaCoin.new('Test Token1','TOKEN1',{from: minter});
    this.token3 = await MetaCoin.new('Test Token2','TOKEN2',{from: minter});
    this.bridge1 = await MetaBridge.new({from: gateway});
    this.bridge2 = await MetaBridge.new({from: gateway});
  
  });

  // addValidChain(struct chainId) onlyOwner
  // validChains stores all the chains where we have implemented bridges and token contracts
  it('Should allow owner only to add valid chainId', async() => {
  
    // Checking if onlyOwner
    await expectRevert(this.bridge1.addValidChain(2222, {from: user1}), 'onlyOwner');
        
    // Checking if chain was already valid
    const isValid = await this.bridge1.validChains('2222');
    assert.ok(!isValid, 'Chain was already valid');

    // Adding valid chainId 
    await this.bridge1.addValidChain(2222, {from: gateway});
    const validChain = await this.bridge1.validChains('2222');
    assert.ok(validChain, 'Chain was not valid');

  });

  // addToken(address tokenAddress, uint 256 tokenFee, bool bridgeType, bool status) onlyOwner.
  // bridgeType is the type of bridge implemented on target chain. True for lock/unlock, false for mint/burn.
  // tokenMap stores all the implemented in this chain.
  // Fee has a min and a max. 
  it('Should allow owner only to add valid token', async() => {

    // Checking if onlyOwner
    await expectRevert(this.bridge1.addToken(this.token1.address, 1, false, true, {from: user1}), 'onlyOwner');
        
    // Checking if token was already added
    const isValid = (await this.bridge1.tokenMap(this.token1.address)).status;
    assert.ok(!isValid, 'Token was already added');

    // Adding token
    await this.bridge1.addToken(this.token1.address, 1, false, true, {from: gateway});
    const addedToken = (await this.bridge1.tokenMap('1111')).status;
    assert.ok(addedToken, 'Token was not added');

  });
 
  // RequestBridge(reciever Address, uint256 chainId, uint256 tokenAddress, uint256 amount) external
  it('Should allow user1 to request bridge to send tokens to another chain', async () => {
    
    // Adding valid chain
    await this.bridge1.addValidChain(2222, {from: gateway});

    // Adding tokens
    await this.bridge1.addToken(this.token1.address, 1, false, true, {from: gateway}); //Token that needs mint/burn on this blockchain
    await this.bridge1.addToken(this.token2.address, 1, true, true, {from: gateway}); //Token that needs lock/unlock on this blockchain

    // Minting tokens to user1
    await this.token1.mint(user1, 10,{ from: minter});
    await this.token1.mint(user2, 10,{ from: minter});
    await this.token2.mint(user1, 20,{ from: minter});

    // user1 approves bridge
    await this.token1.approve( this.bridge1.address, 100, {from: user1});
    await this.token2.approve( this.bridge1.address, 100, {from: user1});

    // Checking that the bridge only happens to valid chain ID. Valid chain ID is 2222 checking revert first.
    // PARAMS (receiverAddress, receivingChain, tokenAddress, amount)
    await expectRevert(this.bridge1.requestBridge(receiver1, 1234, this.token1.address, 3, {from: user1}), 'requestBridge to invalid chain ID' );

    // Checking that the bridge only happens to added tokens. Working token address is 1111 checking revert first.
    await expectRevert(this.bridge1.requestBridge(receiver1, 2222, this.token3.address, 3, {from: user1}), 'requestBridge to invalid token address' );

    // bridgeType == false (mint/burn)
    // Executing the function from user1 address and valid chainId main chain.
    const sendAmount = 3;
    const testFee = 0.1/100;
    await this.bridge.requestBridge(receiver1, 2222, this.token1.adress, sendAmount, {from: user1});
    const feeRequired = new BN(sendAmount).mul(testFee);
    const devBalance = new BN( await this.token1.balanceOf(dev)).toString();
    const totalSupply = new BN(await this.token1.totalSupply()).toString();
    assert.equal(totalSupply, '17', 'Tokens are not burned from user1 account correctly');
    assert.equal( devBalance, feeRequired, "fee not deducted");

    // bridgeType == true (lock/unlock)
    // Executing the function from user1 address and valid chainId main chain. 
    await this.bridge1.requestBridge(receiver2, 2222, this.token2.address, 4, {from: user1});
    
    // Checking user1 balance
    const totalSupply = new BN(await this.token2.totalSupply() ).toString()
    const userBalance = new BN(await this.token2.balanceOf(user1)).toString();
    assert.equal(userBalance, '16', 'Tokens are not being locked correctly');
    assert.equal(totalSupply, '20', 'Were the tokens burned?');
    // Checking bridge balance
    const bridgeBalance = new BN(await this.token2.balanceOf(this.bridge1.address)).toString();
    assert.equal(bridgeBalance, '4', 'Tokens are not being locked correctly');
  });

  // sendTransactionSuccess(uint256 nonce) onlyGateway
  it('Should emit bridge success', async() => {
    await this.token1.mint(user1, 10, {from: minter});
    await this.token1.approve(this.bridge1.address, 100, {from: user1});
    await this.bridge1.addToken(this.token1.address, 1, false, true, {from: gateway}); //Token that needs mint/burn on this blockchain

    const nonce = new BN(await this.bridge1.requestBridge(receiver4, 2222, this.token1.address, 4, {from: user1})).toString();
    // Checking if onlyGateway
    await expectRevert(this.bridge1.sendTransactionSuccess(nonce, {from: user1}), 'onlyGateway');

    // Checking if transaction success event is being emitted
    //require nonce exists 
    const wasSent = await this.bridge1.sendTransactionSuccess(nonce, {from: gateway});
    /// @dev Forcibly fail the test to check events for Success
    assert.ok(false, "Check events emitted");
    // assert.ok(wasSent, 'txn success event is not being emitted');
  });

  // sendTransactionFailiure(uint256 nonce) onlyGateway
  it('Should emit bridge failiure and refund', async() => {
    await this.bridge1.addValidChain(2222, {from: gateway});

    await this.token1.mint(user1, 10, {from: minter});
    await this.token1.approve(this.bridge1.address, 100, {from: user1});
    await this.bridge1.addToken(this.token1.address, 10, false, true, {from: gateway}); //Token that needs mint/burn on this blockchain
    await this.bridge1.addToken(this.token2.address, 10, false, true, {from: gateway}); //Token that needs lock/unlock on this blockchain

    const nonce = new BN(await this.bridge1.requestBridge(receiver1, 2222, this.token1.address, 4, {from: user1})).toString();
    // Checking if onlyGateway
    await expectRevert(this.bridge1.sendTransactionFailiure( nonce, user1,{from: user1}), 'onlyGateway');

    // Checking transaction failiure, mint refund
    await this.bridge.sendTransactionFailiure(nonce, {from: gateway});
    const mintedBalance = new BN(await this.token.balanceOf(user1)).toString();
    assert.equal(userFinalBalance, "" + (10-(4*0.001)), 'Amount is not minted back');

    // Checking transaction failiure, unlock refund 
    await this.token2.mint(user2, 10,{ from: minter});
    await this.token2.approve(this.bridge1.address, 100, {from: user1});
    
    const nonce2 = new BN(await this.bridge1.requestBridge(receiver1, 2222, this.token2.address, 5, {from: user1})).toString();
    
    await this.bridge1.sendTransactionFailiure(nonce2, user1, 5, {from: accounts[3]});

    const transferedUserBalance = new BN(await this.token.balanceOf(user1)).toString();
    const transferedBridgeBalance = new BN(await this.token.balanceOf(this.bridge1.address)).toString();

    assert.equal(transferedUserBalance, "" + (10-(5*0.001)), 'Amount is not transfered back');
    assert.equal(transferedBridgeBalance, '0', 'Amount is not transfered from bridge');
    
  });

  // fulfillBridge(address userAddress, uint256 amount, uint256 fromChainID) onlyGateway
  it('Should recieve transaction success', async() => {

    // Checking valid chainId
    await expectRevert(this.bridge1.fulfillBridge(receiver1, 3, 1234, {from: gateway}), 'Invalid chainId' );

     // Adding valid chain
     await this.bridge.addValidChain(2222, {from: gateway});

    // Adding token
    await this.bridge1.addToken(this.token1.address, 1, false, true, {from: gateway});
    await this.bridge1.addToken(this.token2.address, 1, true, true, {from: gateway});

    // Checking if onlyGateway
    await expectRevert(this.bridge1.fulfillBridge(user1, 3, 2222, {from: user1}), 'onlyGateway');

    // Recieving from valid chain, bridgeType == false (mint/burn), should mint to user1
    await this.bridge1.fulfillBridge(user1, 3, 2222, {from: gateway});
    const userFinalBalance = new BN(await this.token1.balanceOf(user1)).toString();
    assert.equal(userFinalBalance, '3', 'Amount is not being minted');

    // Recieving from valid chain, bridgeType == true (lock/unlock), should transfer to user1
    await this.token2.mint(this.bridge1.address, 5,{ from: user1});
    await this.bridge1.fulfillBridge(user1, 5, 2222, {from: gateway});
    
    const transferUserBalance = new BN(await this.token2.balanceOf(user1)).toString();
    const transferBridgeBalance = new BN(await this.token2.balanceOf(this.bridge1.address)).toString();
    
    assert.equal(transferUserBalance, '5', 'Amount is not transfered');
    assert.equal(transferBridgeBalance, '0', 'Amount is not transfered from bridge');

  });
    
});


