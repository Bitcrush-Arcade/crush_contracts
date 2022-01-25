const { expectRevert } = require('@openzeppelin/test-helpers');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup');

const MetaCoin = artifacts.require("MetaCoin");
const MetaCoin = artifacts.require("MainBridge");

//accounts[0] contract owner address
//accounts[1] user address
//accounts[2] bridge address
//accounts[3] gateway address

contract('mainBridgeTest', (accounts) => {
  beforeEach( async() => {

    this.token = await MetaCoin.new('Nice Token','NICE');
    this.bridge = await MainBridge.new();
  
  });

  //setFee(uint 256 amount) onlyOwner
  it('Should allow only owner to edit the bridge fee', async() => {

    //Checking if starting fee value is 0
    const initialFee = new BN(await this.bridge.fee()).toString();
    assert.equal(fee, '0', 'fee should be 0'); 

    //Checking if onlyOwner
    await expectRevert(this.bridge.setFee(1, {from: accounts[1]}), 'onlyOwner');
  
    //Setting fee
    await this.bridge.setFee(1, {from: accounts[0]});
    const finalFee = new BN(await this.bridge.fee()).toString();
    assert.equal(fee, '1', 'fee is not assigned correctly'); 

  });

  //addValidChain(uint256 chainId) onlyOwner
  it('Should allow owner only to add valid chainId', async() => {
  
    //Checking if onlyOwner
    await expectRevert(this.bridge.addValidChain(2222, {from: accounts[1]}), 'onlyOwner');
        
    //Checking if chain was already valid
    const isValid = await this.bridge.validChains('2222');
    assert.ok(!isValid, 'Chain was already valid');

    //Adding valid chainId to list and checking if it's added
    await this.bridge.addValidChain(2222, {from: accounts[0]});
    const validChain = await this.bridge.validChains('2222');
    assert.ok(validChain, 'Chain was not valid');

  });

  //addToken(uint256 tokenAddress, uint8 contractType) onlyOwner, 0 if invalid, 1 if mint/burn, 2 if lock/unlock
  //ADD ALL CASES TO TEST
  it('Should allow owner only to add valid chainId', async() => {
  
    //Checking if onlyOwner
    await expectRevert(this.bridge.addToken(2222, {from: accounts[1]}), 'onlyOwner');
        
    //Checking if chain was already valid
    const isValid = await this.bridge.validChains('2222');
    assert.ok(!isValid, 'Chain was already valid');

    //Adding valid chainId to list and checking if it's added
    await this.bridge.addValidChain(2222, {from: accounts[0]});
    const validChain = await this.bridge.validChains('2222');
    assert.ok(validChain, 'Chain was not valid');

  });


  //RequestBridge(address userAddress, uint256 chainId, uint256 tokenContractAddress, uint256 amount) external
  it('Should allow user to request bridge to send tokens to another chain', async () => {

    //Setting fee amount
    await this.bridge.setFee(1, {from: accounts[0]});
    const fee = new BN(await this.bridge.fee).toString();
    assert.equal(fee, '1', 'fee is not assigned correctly'); 

    //Adding valid chain
    await this.bridge.addValidChain(2222, {from: accounts[0]});

    //Minting tokens to user
    await this.token.mint(accounts[1], 5,{ from: accounts[0]});

    //Checking that the bridge only happens to valid chain ID. Valid chain ID is string '2222', checking revert first.
    await expectRevert(this.token.requestBridge(1111, 1234, 3, {from: accounts[3]}), 'requestBridge to invalid chainId' );

    //Checking if onlyGateway
    await expectRevert(this.token.requestBridge(1111, 2222, 3, {from: accounts[1]}), 'requestBridge can only be called by gateway');

    //Executing the function from Gateway address and valid chainId
    await this.bridge.requestBridge(1111, 2222, 3, {from: accounts[3]});
    const finalBalance = new BN(await this.bridge.balanceOf(accounts[1])).toString();
    assert.equal(finalBalance, '2', 'Tokens are not burned from user account correctly');

    //Checking that nonce/hash is created correctly. REVISAR ARGUMENTOS DE genTxnHash
    const txnHash = await this.bridge.genTxnHash()   
    assert.ok(txnHash, 'txn hash not created');
       
  });

  //sendTransactionSuccess(Hash) onlyBridge
  it('Should emit bridge success', async() => {

    //Checking that nonce/hash is created. REVISAR ARGUMENTOS DE GENTXNHASH
    const txnHash = await this.bridge.genTxnHash({from: accounts[2]});   

    //Checking if onlyGateway
    await expectRevert(this.bridge.sendTransactionSuccess(txnHash, {from: accounts[1]}), 'Transaction success event should only be emitted by gateway');

    //Checking if transaction success event is being emitted
    await this.bridge.sendTransactionSuccess(txnHash, {from: accounts[3]});
    assert.ok(txnHash, 'txn success event is not being emitted');

  });

  //sendTransactionFailiure(uint 256 txnHash, address userAddress, amount) onlyBridge
  it('Should emit bridge failiure and refund', async() => {
    //Checking that nonce/hash is created. REVISAR ARGUMENTOS DE GENTXNHASH
    const txnHash = await this.bridge.genTxnHash({from: accounts[2]});   
  
    //Checking if onlyGateway
    await expectRevert(this.bridge.sendTransactionFailiure(txnHash, {from: accounts[1]}), 'Transaction success event should only be emitted by gateway');

    //Checking transaction failiure
    await this.bridge.sendTransactionFailiure(txnHash, accounts[1], 2, {from: accounts[3]});
    const userFinalBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    
    //Checking if function was executed and if it refunded 
    assert.ok(txnHash, 'txn success event is not being emitted');
    assert.equal(userFinalBalance, '3', 'Amount is not being refunded');
    
  });

  //recieveTransactionSuccess(userAddress, amount, fromChainID) onlyGateway
  it('Should recieve transaction success', async() => {

    //Recieving from valid chain, should mint to user
    await this.bridge.recieveTransactionSuccess(accounts[1], 3, '2222', {from: accounts[3]});
    const userFinalBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
      
    //Checking if function was executed and if it minted
    assert.ok(txnHash, 'Recieved txn success event is not being emitted');
    assert.equal(userFinalBalance, '3', 'Amount is not being refunded');

  });
    
});


