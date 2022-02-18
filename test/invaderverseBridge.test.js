const { BN, expectRevert,expectEvent } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const NiceBEP = artifacts.require("NICEToken");
const NiceERC = artifacts.require("NiceTokenFtm");
const CrushERC = artifacts.require("CrushErc20");
const InvaderverseBridge = artifacts.require("InvaderverseBridge");

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

contract('InvaderverseBridgeTest', ([minter, user1, user2, gateway, receiver1, dev, receiver2]) => {
  beforeEach( async() => {

    this.token1 = await NiceBEP.new('Nice Token','NICE',{from: minter});
    this.token2 = await NiceERC.new('Test Token1','TOKEN1',{from: minter});
    this.token3 = await CrushERC.new('Test Token2','TOKEN2',{from: minter});
    this.bridge1 = await InvaderverseBridge.new({from: gateway});
    this.bridge2 = await InvaderverseBridge.new({from: gateway});
    
    await this.token1.setBridge( this.bridge1.address, { from: minter});
    await this.token2.setBridge( this.bridge1.address, { from: minter});
    await this.token3.setBridge( this.bridge1.address, { from: minter});

    await this.bridge1.toggleChain(2222, {from: gateway});
    await this.bridge2.toggleChain(1111, {from: gateway});
    
    await this.token1.toggleMinter(this.bridge1.address, {from: minter})
    await this.token2.toggleMinter(this.bridge1.address, {from: minter})
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
    await expectRevert(this.bridge1.addToken(this.token1.address, 1, false, true, 8888, web3.utils.toWei("1000"), {from: user1}), 'Ownable: caller is not the owner');
        
    // Checking if token was already added
    const isValid = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(!isValid, 'Token was already added');

    // Adding NiceBEP
    await this.bridge1.addToken(this.token1.address, 1, false, true, 8888, web3.utils.toWei("1000"), {from: gateway});
    let addedToken = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(addedToken, 'Token was not added');

    // Adding NiceERC
    await this.bridge1.addToken(this.token2.address, 1, false, true, 8888, web3.utils.toWei("1000"), {from: gateway});
    addedToken = (await this.bridge1.validTokens(8888,this.token1.address)).status;
    assert.ok(addedToken, 'Token was not added');

    // Adding CrushERC
    await this.bridge1.addToken(this.token3.address, 1, false, true, 8888, web3.utils.toWei("1000"), {from: gateway});
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
    await this.bridge1.addToken(this.token1.address, 1, false, true, 2222, web3.utils.toWei("1"),{from: gateway}); //Token that needs mint/burn on this blockchain
    await this.bridge1.addToken(this.token2.address, 1, true, true, 2222, web3.utils.toWei("1"),{from: gateway}); //Token that needs lock/unlock on this blockchain

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
    // console.log('return', returnHash, receipt.logs[0].args) // Manual check that return hash is the same
    expectEvent(receipt, 'RequestBridge',{
      requester: user1,
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

  // sendTransactionSuccess(bytes32 thisChainTxnHash) onlyGateway
  it('Should emit bridge success', async() => {

    // Setting up
    await this.token1.mint(user1, 10, {from: minter});
    await this.token1.approve(this.bridge1.address, 100, {from: user1});
    await this.bridge1.addToken(this.token1.address, 1, false, true, 2222, web3.utils.toWei("2"), {from: gateway}); //Token that needs mint/burn on this blockchain

    const receipt = await this.bridge1.requestBridge(receiver1, 2222, this.token1.address, 4, {from: user1});
    const bridgeHash = receipt.logs[0].args.bridgeHash
    let successHash = web3.utils.asciiToHex("SUCCESS_HASH")
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

    // Request bridge fees fro the tokens
    const token1Fee = 100
    const token2Fee = 100
    const tokenFeeDivisor = 100000

    // Token 1 amounts
    const token1Minted = 6
    const token1Transfered = 4
    const token1MintedWei = web3.utils.toWei(""+token1Minted)
    const token1TransferedWei = web3.utils.toWei(""+token1Transfered)

    // Token 2 amounts
    const token2Minted = 6
    const token2Transfered = 4
    const token2MintedWei = web3.utils.toWei(""+token2Minted)
    const token2TransferedWei = web3.utils.toWei(""+token2Transfered)

    await this.token1.mint(user1, token1MintedWei, {from: minter});

    // Adding tokens to the token map so they're valid tokens
    await this.bridge1.addToken(this.token1.address, token1Fee, false, true, 2222, web3.utils.toWei("1"), {from: gateway}); //Token that needs mint/burn on this blockchain
    await this.bridge1.addToken(this.token2.address, token2Fee, true, true, 2222, web3.utils.toWei("1"), {from: gateway}); //Token that needs lock/unlock on this blockchain

    // user1 approving bridge1 100 wei 
    await this.token1.approve(this.bridge1.address, web3.utils.toWei("100"), {from: user1});

    // SCENARIO1: Bridge on this chain is a MINT/BURN
    // Testing transaction failed in the other chain, gateway uses sendTransactionFailure(thisChainTxnHash) 

      // Requesting bridge for 4 wei. We assume it fails on the other side and gateway handles the exception.
      // 4 wei are burned from user1's wallet by bridge and we check the txnHash
      const receipt = await this.bridge1.requestBridge(receiver1, 2222, this.token1.address, token1TransferedWei, {from: user1});
      const requestHash = receipt.logs[0].args.bridgeHash
      // Checking if onlyGateway. We use 1234 as a txnHash
      await expectRevert(this.bridge1.sendTransactionFailure(requestHash, {from: user1}), 'onlyGateway');

      // Gateway uses sendTransactionFailure. 
      const failedRc1 = await this.bridge1.sendTransactionFailure(requestHash, {from: gateway});
      const logs1 = failedRc1.logs
      // Checking if event is correctly emitted
      assert.ok(Array.isArray(logs1), "logs1 is not an array");
      assert.equal(logs1.length, 1, "Only one event should've been emitted");

      const log1 = logs1[0];
      assert.equal(log1.event, 'BridgeFailed', "Wront event emitted");
      assert.equal(log1.args.requester, user1, "Wrong requester");
      assert.equal(log1.args.bridgeHash, requestHash, "Wrong txn hash");

      //Checking if balance was minted back when refunding. Fee is taken into account.
      const mintedBalance = web3.utils.fromWei(await this.token1.balanceOf(user1));
      assert.equal(mintedBalance, "" + (token1Minted-(token1Transfered*(token1Fee/tokenFeeDivisor))), 'Amount is not minted back');

    // SCENARIO2: Bridge on this chain is LOCK/UNLOCK 
    // Testing transaction failed in the other chain, gateway uses sendTransactionFailure(thisChainTxnHash) 

      // Setting up bridge1 to transfer user2's tokens
      await this.token2.mint(user2, token2MintedWei,{ from: minter});
      await this.token2.approve(this.bridge1.address, web3.utils.toWei("100"), {from: user2});

      // Requesting bridge for 4 wei. We assume it fails on the other side and gateway handles the exception.
      // 4 wei are transferred from user1's wallet and we check the txnHash
      const receipt2 = await this.bridge1.requestBridge(receiver2, 2222, this.token2.address, token2TransferedWei, {from: user2});
      const requestHash2 = receipt2.logs[1].args.bridgeHash

      // Gateway uses sendTransactionFailure. 
      const failRc2 = await this.bridge1.sendTransactionFailure(requestHash2, {from: gateway});
      const logs2 = failRc2.logs
      // Checking if event is correctly emitted
      assert.ok(Array.isArray(logs2));
      assert.equal(logs2.length, 2, "Only one event should've been emitted");

      const log2 = logs2[1];
      assert.equal(log2.event, 'BridgeFailed', "Wront event emitted");
      assert.equal(log2.args.requester, user2, "Wrong requester");
      assert.equal(log2.args.bridgeHash, requestHash2, "Wrong txn hash");

      // Checking if tokens are refunded by being transferred back
      const transferedUserBalance = web3.utils.fromWei(await this.token2.balanceOf(user2));
      const transferedBridgeBalance = web3.utils.fromWei(await this.token2.balanceOf(this.bridge1.address));

      assert.equal(transferedUserBalance, "" + (token2Minted-(token2Transfered*(token2Fee/tokenFeeDivisor) )), 'Amount is not transfered back');
      assert.equal(transferedBridgeBalance, '0', 'Amount is not transfered from bridge');
      
    });

  // fulfillBridge(address _userAddress, uint256 _amount, address, _tokenAddress, uint256 _otherChainID, uint256 _otherChainHash) onlyGateway
  it('Should receive transaction success', async() => {
    const testHash = web3.utils.asciiToHex("TEST_HASH");
    // Checking valid chainId
    await expectRevert(this.bridge1.fulfillBridge(receiver1, 3, this.token1.address, 1234, testHash, {from: gateway}), 'Invalid Token' );

    // Adding valid chain
     await this.bridge1.toggleChain(2222, {from: gateway});

    // Adding token
    await this.bridge1.addToken(this.token1.address, 1, false, true, 2222, web3.utils.toWei("1"), {from: gateway});
    await this.bridge1.addToken(this.token2.address, 1, true, true, 2222, web3.utils.toWei("1"), {from: gateway});

    // Checking if onlyGateway
    await expectRevert(this.bridge1.fulfillBridge(user1, 3, this.token1.address, 2222, testHash, {from: user1}), 'onlyGateway');

    // Recieving from valid chain, bridgeType == false (mint/burn), should mint to user1
    const {logs} = await this.bridge1.fulfillBridge(user1, 3, this.token1.address, 2222, testHash, {from: gateway});
    const userFinalBalance = new BN(await this.token1.balanceOf(user1)).toString();
    assert.equal(userFinalBalance, '3', 'Amount is not being minted');

    // Checking if event is correctly emitted
    assert.ok(Array.isArray(logs));
    assert.equal(logs.length, 1, "Only one event should've been emitted");

    const log = logs[0];
    assert.equal(log.event, 'FulfillBridgeRequest', "Wront event emitted");
    assert.equal(log.args._otherChainId, 2222, "Wrong requester");
    assert.equal(log.args._otherChainHash.replace(/[0]{2}/g,""), testHash, "Wrong txn hash");

    // Recieving from valid chain, bridgeType == true (lock/unlock), should transfer to user1
    const testHash2 = web3.utils.asciiToHex("TEST_HASH2");

    await this.token2.mint(this.bridge1.address, 5,{ from: minter});
    const fulfillRc2 = await this.bridge1.fulfillBridge(user1, 5, this.token2.address, 2222, testHash2,{from: gateway});
    const logs2 = fulfillRc2.logs

    const transferUserBalance = new BN(await this.token2.balanceOf(user1)).toString();
    const transferBridgeBalance = new BN(await this.token2.balanceOf(this.bridge1.address)).toString();
    
    assert.equal(transferUserBalance, '5', 'Amount is not transfered');
    assert.equal(transferBridgeBalance, '0', 'Amount is not transfered from bridge');
    
    // Checking if event is correctly emitted
    assert.ok(Array.isArray(logs2));
    assert.equal(logs2.length, 1, "Only one event should've been emitted");

    const log2 = logs2[0];
    assert.equal(log2.event, 'FulfillBridgeRequest', "Wront event emitted");
    assert.equal(log2.args._otherChainId, 2222, "Wrong requester");
    assert.equal(log2.args._otherChainHash.replace(/[0]{2}/g,""), testHash2, "Wrong txn hash");

  });


  // mirrorBurn(address _tokenAddress, uint256 _amount, uint256 _fromChain, bytes32 _burnHash) external onlyGateway
  // emits event MirrorBurned(address tokenAddress, uint256 otherChain, uint256 amount, bytes32 otherChainHash);
  it('Should mirror burn when it happens in other chain', async() => {
    const testHash = web3.utils.asciiToHex("TEST_HASH");
    // Setting up
    await this.bridge1.addToken(this.token1.address, 1, true, true, 2222, web3.utils.toWei("1"), {from: gateway});
    await this.token1.mint(this.bridge1.address, 10, {from: minter});

    // Checking if validChain
    await expectRevert(this.bridge1.mirrorBurn(this.token1.address, 4, 3333, testHash, {from: gateway}), 'Invalid Token');

    // onlyGateway
    await expectRevert(this.bridge1.mirrorBurn(this.token1.address, 4, 2222, testHash, {from: user1}), 'onlyGateway');

    // Mirror burning
    const {logs} = await this.bridge1.mirrorBurn(this.token1.address, 4, 2222, testHash, {from: gateway});   
    const finalBridgeBalance = await this.token1.balanceOf(this.bridge1.address);
    assert.equal(finalBridgeBalance, '6', 'Amount is not being burned');

    // Checking event
    assert.ok(Array.isArray(logs));
    assert.equal(logs.length, 1, "Only one event should've been emitted");

    const log = logs[0];
    assert.equal(log.event, 'MirrorBurned', "Wrong event emitted");
    assert.equal(log.args.tokenAddress, this.token1.address, "Wrong token address");
    assert.equal(log.args.otherChain, 2222, "Wrong otherChainId");
    assert.equal(log.args.amount, 4, "Wrong amount mirror burned");
    assert.equal(web3.utils.hexToAscii(log.args.otherChainHash.replace(/[0]{2}/g,"")), web3.utils.hexToAscii(testHash), "Hashes do not match");

  });

  it("Must act accordingly with other bridge", async()=>{

    // In this test, user1 will be sending NICE tokens to his wallet in receiver1. In this test we are the gateway.

    // Setting up 
      const token1Fee = 100
      const tokenFeeDivisor = 100000
      const chain1Id = 1111
      const chain2Id = 2222

      // Token 1 amounts
      const token1Minted = 6
      const token1Transfered = 4
      const token1MintedWei = web3.utils.toWei(""+token1Minted)
      const token1TransferedWei = web3.utils.toWei(""+token1Transfered)

      // Minting bep tokens to user1 for it to be able to bridge
      await this.token1.mint(user1, token1MintedWei, {from: minter});

      // user1 approves bridge1
      await this.token1.approve(this.bridge1.address, token1MintedWei, {from: user1});

      // Deployer sets up tokens. Their respective bridges must be added and minters toggled.
      //ASSUMING BRIDGE 1 LIVES IN CHAIN 1 (ID: 1111) AND BRIDGE 2 LIVES IN CHAIN 2 (ID: 2222)
      await this.token1.setBridge(this.bridge1.address, {from: minter});
      await this.token1.toggleMinter(this.bridge1.address, {from: minter});

      await this.token2.setBridge(this.bridge2.address, {from: minter});
      await this.token2.toggleMinter(this.bridge2.address, {from: minter});

      // Deployer sets up bridges by adding the tokens with their props
      // TOKEN 1  ==  TOKEN 2 JUST ON DIFFERENT CHAINS
      await this.bridge1.addToken(this.token1.address, token1Fee, false, true, chain2Id, web3.utils.toWei("1"), {from: gateway}); //Token that needs mint/burn bridge on chain1
      await this.bridge2.addToken(this.token2.address, token1Fee, false, true, chain1Id, web3.utils.toWei("1"), {from: gateway}); //Token that needs mint/burn bridge on chain2

    // Bridging tokens from chain1 to chain2. Tester will be calling functions as gateway.

    // REQUEST BRIDGE BY USER1 OF TOKEN1(NICE BEP20) TO CHAIN 2 OF TOKEN2(NICE ERC20). It will be recieved by reciever1. Note they're the same type of token.
    const {logs} = await this.bridge1.requestBridge(receiver1, chain2Id, this.token1.address, token1TransferedWei, {from: user1});
    bridgeHash = logs[0].args.bridgeHash;

    // GATEWAY RECEIVES BRIDGE EVENT FULFILLS BRIDGE ON CHAIN 2
    await this.bridge2.fulfillBridge(receiver1, token1TransferedWei, this.token2.address, chain1Id, bridgeHash, {from: gateway});

    // CHECKING FINAL BALANCES

    const user1Balance = await this.token1.balanceOf(user1);
    const receiver1Balance = await this.token2.balanceOf(receiver1);

    assert.equal(user1Balance, token1MintedWei-token1TransferedWei-(token1TransferedWei*(token1Fee/tokenFeeDivisor)), 'Incorrect user1 balance');
    assert.equal(receiver1Balance, token1TransferedWei, 'Incorrect receiver1 balance');
     
  });
  
});


