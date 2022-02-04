const { expectRevert } = require('@openzeppelin/test-helpers');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup');

const NiceBEP = artifacts.require("NiceTokenFtm");
  // Tests for the main chain token1. 

  // accounts[0] minter
  // accounts[1] user1 
  // accounts[2] gateway
  
contract('NiceTokenFtmTest', ([minter, user1, gateway, user2, bridge1]) => {
  beforeEach( async() => {
  
    this.token1 = await NiceBEP.new("Nice Invaders Crush Everything", "NICE", {from: minter});
    
    });

  // owner()
  it('Should return owner address', async () => {

    const ownerAddress = await this.token1.owner();
    assert.equal(ownerAddress, minter, 'Owner address is not returned correctly');
    
  });

  // name
  it('Should return token1 name correctly', async () => {

    const name = await this.token1.name();
    assert.equal(name,"Nice Invaders Crush Everything", 'Name is not returned correctly');

  });

  // decimals
  it('Should return the right amount of decimals.', async () => {

    const decimals = await this.token1.decimals();
    assert.equal(decimals, 18, 'Incorrect decimal size. Expected 18.');

  });
  
  // symbol
  it('Should return token1 symbol correctly.', async () => {

    const tokenSymbol = await this.token1.symbol();
    assert.equal(tokenSymbol, 'NICE', 'Incorrect token1 name. Expected NICE.');

  });

  // balanceOf is the balance of any address
  it('Should return account balance correctly.', async () => {

    const startingBalance = new BN(await this.token1.balanceOf(user1)).toString();
    assert.equal(startingBalance, '0', 'Starting balance should be 0');
   
    await this.token1.mint(user1, 10, {from: minter});
    const finalBalance = new BN(await this.token1.balanceOf(user1)).toString();
    assert.equal(finalBalance, '10', 'Incorrect balance');

  });

  // transfer 
  it('Should transfer between accounts correctly.', async () => {
    
    // Checking transfer from empty account to other account
    await expectRevert(this.token1.transfer(user1, 5, {from: minter}), "ERC20: transfer amount exceeds balance");
    
    const startingBalance_zero = new BN(await this.token1.balanceOf(minter)).toString();
    const startingBalance_one = new BN(await this.token1.balanceOf(user1)).toString();
    
    assert.equal(startingBalance_zero, '0', 'Balance should not change when transferring from account with balance 0');
    assert.equal(startingBalance_one, '0', 'Account balance should be 0');
    
    // Checking regular account transfer 
    await this.token1.mint(minter, 10,{ from: minter});
    isTransferredBack = await this.token1.transfer(user1, 1, {from: minter});
    
    const finalBalance_zero = new BN(await this.token1.balanceOf(minter)).toString();
    const finalBalance_one = new BN(await this.token1.balanceOf(user1)).toString(); 
    
    assert.ok(isTransferredBack, 'Transfer operation not was not executed');
    assert.equal(finalBalance_zero, '9', 'Incorrect withdrawal from transferring account');
    assert.equal(finalBalance_one, '1', 'Incorrect deposit to recieving acount');

  });

  // allowance, approve
  // Checking that allowance is 0 by default
  it('Should approve and display allowance correctly.', async () => {
    
    // Default allowance should be 0
    const startingAllowance = await this.token1.allowance(user1, user2);
    assert.equal(startingAllowance, 0, 'Function allowance should be zero by default');

    // Approve
    await this.token1.approve(user2, 5, {from: user1});
    const finalAllowance = new BN(await this.token1.allowance(user1, user2)).toString();
    assert.equal(finalAllowance, '5', 'Allowance is not approved correctly'); 
    
  });

  // increaseAllowance
  it("should increase Allowance", async() =>{

    // Default allowance should be 0
    const startingAllowance = await this.token1.allowance(user1, user2);
    assert.equal(startingAllowance, 0, 'Allowance should be 0 by default');

    // increaseAllowance
    await this.token1.approve(user2, 5, {from: user1});
    await this.token1.increaseAllowance(user2, 1,{from: user1});
    const finalAllowance = new BN(await this.token1.allowance(user1, user2)).toString();
    assert.equal(finalAllowance, '6', 'Allowance is not assigned correctly'); 

  });

  // decreaseAllowance 
  it('Should decrease total allowance.', async () => {

    // Default allowance should be 0
    const startingAllowance = await this.token1.allowance(user1, user2);
    assert.equal(startingAllowance, 0, 'Allowance should be 0 by default');

    // decreaseAllowance
    await this.token1.approve(user2, 5, {from: user1});
    await this.token1.decreaseAllowance(user2, 1, {from: user1});
    const finalAllowance = new BN(await this.token1.allowance(user1, user2)).toString();
    assert.equal(finalAllowance, '4', 'Allowance is not assigned correctly'); 

  });

  // mint(address user, uint256 amount) onlyMinter external
  it('Should burn correctly.', async () => {

    // Adding bridge as a valid minter
    await this.token1.toggleMinter(bridge1, {from: minter});
    
    //Testing if mint is onlyMinter
    await expectRevert(this.token1.mint(user2, 5, {from: user1}), 'only minters can execute this function');
    
    //Testing bridgeMint
    await this.token1.mint(user1, 10, {from: bridge1});
    const finalBalance = new BN(await this.token1.balanceOf(user1)).toString();
    assert.equal(finalBalance, '10', 'Incorrect mint amount.');

  });

  // burn
  it('Should burn correctly.', async () => {
    
    // Should not burn when balance is 0
    await expectRevert(this.token1.burn(3, {from: user1}),"ERC20: burn amount exceeds balance");

    // Setting up
    await this.token1.mint(user1, 10, {from: minter});

    // Burn
    const {logs} = await this.token1.burn(3, {from: user1});
    const finalBalance_one = new BN(await this.token1.balanceOf(user1)).toString();
    const totalBurned = new BN(await this.token1.totalBurned()).toString();

    // Checking final balance and totalBurned
    assert.equal(finalBalance_one, '7', 'Incorrect burn amount.');
    assert.equal(totalBurned, '3', 'Incorrect total burned');

  });

  // totalSupply
  it('Should return total token1 supply correctly', async () => {

    await this.token1.mint(minter, 10, {from: minter});
    await this.token1.mint(user1, 5, {from: minter});
    await this.token1.mint(user2, 3, {from: minter});

    // totalSupply
    const totalSupply = new BN(await this.token1.totalSupply()).toString();
    assert.equal(totalSupply, '18', 'Total supply not being calculated properly');

  });

  // transferFrom 
  it('Should transfer from one account to another successfuly.', async () => {
    
    await this.token1.mint(user1, 10, { from: minter});
    await this.token1.approve(user2, 5, {from: user1});
   
    //Testing if transfer exceeds allowance
    await expectRevert(this.token1.transferFrom(user1, user2, 6, {from: user2}), 'ERC20: transfer amount exceeds allowance');
    
    // transferFrom
    await this.token1.transferFrom(user1, user2, 5, {from: user2});
    
    const finalBalance_one = new BN(await this.token1.balanceOf(user1)).toString();
    const finalBalance_two = new BN(await this.token1.balanceOf(user2)).toString(); 
    const finalAllowance = await this.token1.allowance(user1, user2);

    assert.equal(finalAllowance, '0', 'Allowance is not being calculated properly');
    assert.equal(finalBalance_one, '5', 'Incorrect withdrawal from owner account.');
    assert.equal(finalBalance_two, '5', 'Incorrect deposit to recipient account.');

  });

  // BRIDGE FUNCTIONS

  // bridgeBurn onlyBridge
  it('Should bridgeBurn correctly when called by bridge.', async () => {

    // Adding bridge as a valid minter
    await this.token1.toggleMinter(bridge1, {from: minter});
    
    //Burning on empty account   
    await expectRevert(this.token1.bridgeBurn(user2, 5, {from: minter}), "ERC20: burn amount exceeds balance");
        
    //onlyBridge
    await this.token1.mint(user2, 10, {from: bridge1});
    await expectRevert(this.token1.bridgeBurn(user2, 5, {from: user1}), "only bridge can execute this function");
    
    await this.token1.bridgeBurn(user2, 3, {from: minter});
    const finalBalance_one = new BN(await this.token1.balanceOf(user2)).toString();
    const totalBurned = await this.token1.totalBurned.call();

    assert.equal(finalBalance_one, '7', 'Incorrect burn amount.');
    assert.equal(totalBurned, '0', 'Incorrect total burned'); // Burned amount should be 0
    
  });

  //bridgeBurnFrom onlyBridge
  it('Should burn from user account successfuly.', async () => {
    await this.token1.setBridge(bridge1, { from: minter});
    await this.token1.mint(user1, 10, { from: minter});
    await this.token1.approve(bridge1, 5, {from: user1});

    // Adding bridge as a valid minter
    await this.token1.toggleMinter(bridge1, {from: minter});
   
    //Testing if burnFromBridge exceeds allowance
    await expectRevert(this.token1.bridgeBurnFrom(user1, 6, {from: bridge1}), 'ERC20: burn amount exceeds allowance');

    //Testing if onlyBridge
    await expectRevert(this.token1.bridgeBurnFrom(user1, 5, {from: user1}), 'only bridge can execute this function');

    //Burning allowance amount
    await this.token1.bridgeBurnFrom(user1, 5, {from: bridge1});
    
    //Checking balances
    const finalBalance_one = new BN(await this.token1.balanceOf(user1)).toString();
    const finalAllowance = await this.token1.allowance(user1, user2);
    const totalBurned = await this.token1.totalBurned.call();

    assert.equal(finalAllowance, '0', 'Allowance is not being calculated properly');
    assert.equal(finalBalance_one, '5', 'Incorrect amount burned');
    assert.equal(totalBurned, '0', 'Incorrect total burned'); // Burned amount should be 0
    
  });

  // toggleMinter(address newMinter, bool status) onlyOwner adds minter address to validMinters map
  it('Should add minter', async () => {

    // Checking if onlyOwner
    await expectRevert(this.token1.toggleMinter(bridge1, {from: user1}), 'Ownable: caller is not the owner');
    
    // Checking if token was already added
    const isValid = (await this.token1.validMinters(bridge1));
    assert.ok(!isValid, 'Minter was already added');

    // Adding bridge as a valid minter
    await this.token1.toggleMinter(bridge1, {from: minter});
    const addedMinter = (await this.token1.validMinters(bridge1));
    assert.ok(addedMinter, 'Minter was not added');
            
  });

});
