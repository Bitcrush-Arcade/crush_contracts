const { expectRevert,expectEvent } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const NiceBEP = artifacts.require("NICEToken");
const NiceERC = artifacts.require("NiceToken");
const CrushERC = artifacts.require("CrushErc20");
const MetaBridge = artifacts.require("InvaderverseBridge");

// These tests are for our main bridge contract that connects tokens in EVM chains. This bridge contract can work both as a main chain bridge (lock/unlock) 
// and as a side bridge (mint/burn), depending on the token that's being bridged or recieved.  
// The type of bridge has to be specified for the token on both bridges. 
// accounts[0] contract owner address (minter)
// accounts[1] user1
// accounts[2] other user
// accounts[3] gateway address
// accounts[4] user1 recieving wallet on other chain
// accounts[5] dev wallet
// accounts[6] user2 receiving wallet on other chain
// Other chainId: 8888

// Chain Id 1 = 1111
// Chain Id 2 = 2222

contract('metaBridgeTest', ([minter, user1, user2, gateway, receiver1, dev, receiver2]) => {
  beforeEach( async() => {

    this.token1 = await NiceBEP.new('Nice Token','NICE',{from: minter});
    this.token2 = await NiceERC.new('Test Token1','TOKEN1',{from: minter});
    this.token3 = await CrushERC.new('Test Token2','TOKEN2',{from: minter});
    this.bridge1 = await MetaBridge.new({from: gateway});
    this.bridge2 = await MetaBridge.new({from: gateway});
    
    await this.token1.setBridge( this.bridge1.address, { from: minter});
    await this.token2.setBridge( this.bridge1.address, { from: minter});
    await this.token3.setBridge( this.bridge1.address, { from: minter});

    await this.bridge1.toggleChain(2222, {from: gateway});
    await this.bridge2.toggleChain(1111, {from: gateway});
    
    await this.token1.toggleMinter(this.bridge1.address, {from: minter})
  });

  // toggleChain(uint256 chainId, bool status) onlyOwner
  // validChains stores all otherChainIds from chains where we've implemented bridges and token contracts
  it('Should allow owner only to add valid chainId', async() => {
  
    // Checking if onlyOwner
    await expectRevert(this.bridge1.toggleChain(2222, {from: user1}), 'Ownable: caller is not the owner');
        
    // Checking if chain was already valid
    const isValid = await this.bridge1.validChains('3333');
    assert.ok(!isValid, 'Chain was already valid');

    // Adding valid chainId 
    await this.bridge1.toggleChain(4444, {from: gateway});
    const validChain = await this.bridge1.validChains('4444');
    assert.ok(validChain, 'Chain was not valid');

  });
_
  // addToken(address tokenAddress, uint256 tokenFee, bool bridgeType, bool status, uint otherChainId) onlyOwner.
  // bridgeType is the type of bridge implemented on target chain. True for lock/unlock, false for mint/burn.
  // tokenMap stores all the implemented in this chain.
  // Fee has a min and a max. 
  it('Should allow owner only to add valid token', async() => {

    // Checking if onlyOwner
    await expectRevert(this.bridge1.addToken(this.token1.address, 1, false, true, 8888, {from: user1}), 'Ownable: caller is not the owner');
        
    // Checking if token was already added
    const isValid = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(!isValid, 'Token was already added');

    // Adding NiceBEP
    await this.bridge1.addToken(this.token1.address, 1, false, true, 8888, {from: gateway});
    let addedToken = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(addedToken, 'Token was not added');

    // Adding NiceERC
    await this.bridge1.addToken(this.token2.address, 1, false, true, 8888, {from: gateway});
    addedToken = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(addedToken, 'Token was not added');

    // Adding CrushERC
    await this.bridge1.addToken(this.token3.address, 1, false, true, 8888, {from: gateway});
    addedToken = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(addedToken, 'Token was not added');

  });

  // setGateway (address _gateway) external onlyOwner
  it('Should set gateway address', async() => {

    // onlyOwner
    await expectRevert(this.bridge1.setGateway(gateway, {from: user1}), 'Ownable: caller is not the owner');

    // Setting Gateway
    await this.bridge1.setGateway(gateway, {from: gateway});
    const gatewayAddress = await this.bridge1.gateway();
    assert.equal(gatewayAddress, gateway, 'Address not set');

    // Checking event
    const {logs} =  await this.bridge2.setGateway(gateway, {from: gateway});
    assert.ok(Array.isArray(logs));
    assert.equal(logs.length, 1, "Only one event should've been emitted");

    const log = logs[0];
    assert.equal(log.event, 'SetGateway', "Wront event emitted");
    assert.equal(log.args.gatewayAddress, gateway, "Wrong gateway");

  });

  // setDev (address _devAddress) external onlyOwner
  it('Should set developer wallet', async() => {

   // onlyOwner
   await expectRevert(this.bridge1.setDev(dev, {from: user1}), 'Ownable: caller is not the owner');

   // Setting Dev
   await this.bridge1.setDev(dev, {from: gateway});
   const devAddress = await this.bridge1.devAddress();
   assert.equal(devAddress, dev, 'Dev address not set');

   // Checking event
   const {logs} =  await this.bridge2.setDev(dev, {from: gateway});
   assert.ok(Array.isArray(logs));
   assert.equal(logs.length, 1, "Only one event should've been emitted");

   const log = logs[0];
   assert.equal(log.event, 'SetDev', "Wront event emitted");
   assert.equal(log.args.dev, dev, "Wrong dev");

  });
 
  // RequestBridge( address recieverAddress, uint256 chainId, uint256 tokenAddress, uint256 amount) external
  it('Should allow user to request bridge to send tokens to another chain - BURN', async () => {

    // Adding tokens
    await this.bridge1.addToken(this.token1.address, 1, false, true, 2222, {from: gateway}); //Token that needs mint/burn on this blockchain
    await this.bridge1.addToken(this.token2.address, 1, true, true, 2222, {from: gateway}); //Token that needs lock/unlock on this blockchain

    // Minting tokens to user1
    await this.token1.mint(user1, 10,{ from: minter});
    await this.token1.mint(user2, 10,{ from: minter});
    await this.token2.mint(user1, 20,{ from: minter});

    // user1 approves bridge
    await this.token1.approve( this.bridge1.address, 100, {from: user1});
    await this.token2.approve( this.bridge1.address, 100, {from: user1});

    // Checking that the bridge only happens to valid chain ID. Valid chain ID is 2222 checking revert first.
    // PARAMS (receiverAddress, receivingChain, tokenAddress, amount)
    await expectRevert(this.bridge1.requestBridge(receiver1, 1234, this.token1.address, 3, {from: user1}), 'Invalid Chain' );

    // Checking that the bridge only happens to added tokens. Working token address is 1111 checking revert first.
    await expectRevert(this.bridge1.requestBridge(receiver1, 2222, this.token3.address, 3, {from: user1}), 'Invalid Token' );

    // bridgeType == false (mint/burn)
    // Executing the function from user1 address and valid chainId main chain.
    const sendAmount = 3;
    const testFee = 0.1/100;
    // This gets the txevent only
    const receipt = await this.bridge1.requestBridge(receiver1, 2222, this.token1.address, sendAmount, {from: user1});
    const returnHash = await this.bridge1.requestBridge.call(receiver1, 2222, this.token1.address, sendAmount, {from: user1});
    // console.log('return', returnHash, receipt.logs[0].args) // Manual check that return hash is the same
    expectEvent(receipt, 'RequestBridge',{
      requester: user1,
      bridgeHash: returnHash,
    })
    const feeRequired = web3.utils.toBN(sendAmount).mul( web3.utils.toBN(1)).div( web3.utils.toBN(1000))
    .toString();
    const devBalance = web3.utils.toBN( await this.token1.balanceOf(dev)).toString();
    let totalSupply = web3.utils.toBN(await this.token1.totalSupply()).toString();
    assert.equal(totalSupply, '17', 'Tokens are not burned from user1 account properly');
    assert.equal( devBalance, feeRequired, "fee not deducted");

    // bridgeType == true (lock/unlock)
    // Executing the function from user1 address and valid chainId main chain. 
    await this.bridge1.requestBridge(receiver2, 2222, this.token2.address, 4, {from: user1});
    
    // Checking user1 balance
    totalSupply = web3.utils.toBN(await this.token2.totalSupply() ).toString()
    const userBalance = web3.utils.toBN(await this.token2.balanceOf(user1)).toString();
    assert.equal(userBalance, '16', 'Tokens are not being locked properly');
    assert.equal(totalSupply, '20', 'Were the tokens burned?');
    // Checking bridge balance
    const bridgeBalance = web3.utils.toBN(await this.token2.balanceOf(this.bridge1.address)).toString();
    assert.equal(bridgeBalance, '4', 'Tokens are not being locked properly');
  });

  // sendTransactionSuccess(uint256 nonce) onlyGateway
  it('Should emit bridge success', async() => {

    // Setting up
    await this.token1.mint(user1, 10, {from: minter});
    await this.token1.approve(this.bridge1.address, 100, {from: user1});
    await this.bridge1.addToken(this.token1.address, 1, false, true, 2222, {from: gateway}); //Token that needs mint/burn on this blockchain

    const receipt = await this.bridge1.requestBridge(receiver1, 2222, this.token1.address, 4, {from: user1});
    const bridgeHash = await this.bridge1.requestBridge.call(receiver1, 2222, this.token1.address, 4, {from: user1})

    let successHash = web3.utils.asciiToHex("SUCCESS_HASH")
    if(successHash)
    // Checking if onlyGateway
    await expectRevert(this.bridge1.sendTransactionSuccess(bridgeHash, successHash, {from: user1}), 'onlyGateway');

    // Checking if event was emitted
    const {logs} =  await this.bridge1.sendTransactionSuccess(bridgeHash, successHash, {from: gateway});
    assert.ok(Array.isArray(logs));
    assert.equal(logs.length, 1, "Only one event should've been emitted");

    const log = logs[0];
    assert.equal(log.event, 'BridgeSuccess', "Wront event emitted");
    assert.equal(log.args.requester, user1, "Wrong User");
    assert.equal(log.args.bridgeHash, bridgeHash);

    const txInfo = await this.bridge1.transactions(bridgeHash)
    assert.equal( txInfo.otherChainHash.replace(/[0]{2}/g,""), successHash, "Different Hashes saved");

  });

  // sendTransactionFailure(bytes32 thisChainHash) onlyGateway
  it('Should emit bridge failure and refund', async() => {

    const token1Fee = 100
    const token2Fee = 100
    const tokenFeeDivisor = 100000

    const token1Minted = 1
    const token1Transfered = 4
    const token1MintedWei = web3.utils.toWei(""+token1Minted)
    const token1TransferedWei = web3.utils.toWei(""+token1Transfered)

    const token2Minted = 11
    const token2Transfered = 5
    const token2MintedWei = web3.utils.toWei(""+token2Minted)
    const token2TransferedWei = web3.utils.toWei(""+token2Transfered)

    await this.token1.mint(user1, token1MintedWei, {from: minter});
    await this.token1.approve(this.bridge1.address, web3.utils.toWei("100"), {from: user1});
    await this.bridge1.addToken(this.token1.address, token1Fee, false, true, 2222, {from: gateway}); //Token that needs mint/burn on this blockchain
    await this.bridge1.addToken(this.token2.address, token2Fee, true, true, 2222, {from: gateway}); //Token that needs lock/unlock on this blockchain

    const receipt = await this.bridge1.requestBridge(receiver1, 2222, this.token1.address, token1TransferedWei, {from: user1});
    const bridgeRequestHash = await this.bridge1.requestBridge.call(receiver1, 2222, this.token1.address, token1TransferedWei, {from: user1});
    // Checking if onlyGateway
    await expectRevert(this.bridge1.sendTransactionFailure( bridgeRequestHash,{from: user1}), 'onlyGateway');

    // Checking transaction failiure, mint refund
    const failReceipt = await this.bridge1.sendTransactionFailure(bridgeRequestHash, {from: gateway});

    expectEvent( failReceipt, 'BridgeFailed',{
      requester: user1,
      bridgeHash: bridgeRequestHash,
    })
    const mintedBalance = web3.utils.fromWei(await this.token1.balanceOf(user1));
    assert.equal(mintedBalance, "" + (token1Minted-(token1Transfered*(token1Fee/tokenFeeDivisor))), 'Amount is not minted back');

    // Checking transaction failiure, unlock refund 
    await this.token2.mint(user2, web3.utils.toWei(token2MintedWei),{ from: minter});
    await this.token2.approve(this.bridge1.address, web3.utils.toWei("100"), {from: user2});
    
    const failReceipt2 = await this.bridge1.requestBridge(receiver1, 2222, this.token2.address, token2TransferedWei, {from: user2})
    const bridgeRequest2 = await this.bridge1.requestBridge.call(receiver1, 2222, this.token2.address, token2TransferedWei, {from: user2});
    
    await this.bridge1.sendTransactionFailure(bridgeRequest2, {from: gateway});

    const transferedUserBalance = web3.utils.fromWei(await this.token2.balanceOf(user2));
    const transferedBridgeBalance = web3.utils.fromWei(await this.token2.balanceOf(this.bridge1.address));

    assert.equal(transferedUserBalance, "" + (token2Minted-(token2Transfered*(token2Fee/tokenFeeDivisor) )), 'Amount is not transfered back');
    assert.equal(transferedBridgeBalance, '0', 'Amount is not transfered from bridge');
    
  });

  // fulfillBridge(address _userAddress, uint256 _amount, address, _tokenAddress, uint256 _otherChainID, uint256 _otherChainHash) onlyGateway
  it('Should receive transaction success', async() => {

    // Checking valid chainId
    await expectRevert(this.bridge1.fulfillBridge(receiver1, 3, this.token1.address, 1234, 'TEST_STRING', {from: gateway}), 'Invalid Chain' );

    // Adding valid chain
     await this.bridge1.toggleChain(2222, {from: gateway});

    // Adding token
    await this.bridge1.addToken(this.token1.address, 1, false, true, 8888, {from: gateway});
    await this.bridge1.addToken(this.token2.address, 1, true, true, 8888, {from: gateway});

    // Checking if onlyGateway
    await expectRevert(this.bridge1.fulfillBridge(user1, 3, 7777, 2222, {from: user1}), 'onlyGateway');

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


  // mirrorBurn(address _tokenAddress, uint256 _amount, uint256 _fromChain, bytes32 _burnHash) external onlyGateway
  // emits event MirrorBurned(address tokenAddress, uint256 otherChain, uint256 amount, bytes32 otherChainHash);
  it('Should mirror burn when it happens in other chain', async() => {

    // Setting up
    await this.token1.mint(this.bridge1.address, 10, {from: minter});

    // Checking if validChain
    await expectRevert(this.bridge1.mirrorBurn(this.token1.address, 4, 3333, 'TEST_HASH', {from: gateway}), 'validChain');

    // onlyGateway
    await expectRevert(this.bridge1.mirrorBurn(this.token1.address, 4, 2222, 'TEST_HASH', {from: user1}), 'onlyGateway');

    // Mirror burning
    const {logs} = await this.bridge1.mirrorBurn(this.token1.address, 4, 2222, 'TEST_HASH', {from: gateway});   
    const finalBridgeBalance = this.token1.balanceOf(this.bridge1.address);
    assert.equal(finalBridgeBalance, '6', 'Amount is not being burned');

    // Checking event
    assert.ok(Array.isArray(logs));
    assert.equal(logs.length, 1, "Only one event should've been emitted");

    const log = logs[0];
    assert.equal(log.event, 'MirrorBurned', "Wrong event emitted");
    assert.equal(log.args.tokenAddress, this.token1.address, "Wrong token address");
    assert.equal(log.args.otherChain, 1111, "Wrong otherChainId");
    assert.equal(log.args.amount, 4, "Wrong amount mirror burned");
    assert.equal(log.args.otherChainHash, 'TEST_HASH' , "Hashes do not match");

  });
  
});


