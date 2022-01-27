  //Tests for the main chain token. 

  //accounts[0] contract owner address
  //accounts[1] user address
  //accounts[2] bridge address
  //accounts[3] gateway address
  
  //getOwner
  it('Should return owner adress.', async () => {
    const ownerAddress = await this.token.getOwner();

    assert.equal(ownerAddress, accounts[0], 'Owner address is not returned correctly.');
  });

  //name
  it('Should return token name correctly.', async () => {
    const name = await this.token.name();

    assert.equal(name, 'NICE Token', 'Name is not returned correctly.');
  });

  //decimals
  it('Should return the right amount of decimals.', async () => {
    const decimals = await this.token.decimals();

    assert.equal(decimals, 18, 'Incorrect decimal size. Expected 18.');
  });
  
  //symbol
  it('Should return token symbol correctly.', async () => {
    const tokenSymbol = await this.token.symbol();

    assert.equal(tokenSymbol, 'NICE', 'Incorrect token name. Expected CRUSH.');
  });

  //balanceOf es el balance de cualquier address
  it('Should return account balance correctly.', async () => {
    const startingBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(startingBalance, '0', 'Final balance not returned properly. Error may be in getBalance or mint function.');
   
    await this.token.mint(accounts[1], 10,{ from: accounts[0]} );
    const finalBalance = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(finalBalance, '10', 'Final balance not returned properly. Error may be in getBalance or mint function.');
  });


  //transfer 
  it('Should transfer between accounts correctly.', async () => {
    
    //Checking transfer from empty account to other account
    await expectRevert(this.token.transfer(accounts[1], 5, {from: accounts[0]}), "BEP20: transfer amount exceeds balance");
    
    const startingBalance_zero = new BN(await this.token.balanceOf(accounts[0])).toString();
    const startingBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    
    assert.equal(startingBalance_zero, '0', 'Balance should not change when transferring from account with balance 0');
    assert.equal(startingBalance_one, '0', 'Account balance should be 0');
    
    //Checking regular account transfer 
    await this.token.mint(accounts[0], 10,{ from: accounts[0]});
    isTransferredBack = await this.token.transfer(accounts[1], 1, {from: accounts[0]});
    
    const finalBalance_zero = new BN(await this.token.balanceOf(accounts[0])).toString();
    const finalBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString(); 
    
    assert.ok(isTransferredBack, 'Transfer operation not was not executed.');
    assert.equal(finalBalance_zero, '9', 'Incorrect withdrawal from transferring account.');
    assert.equal(finalBalance_one, '1', 'Incorrect deposit to recieving acount.');

  });


  //allowance, approve
  //Checking that allowance is 0 by default
  it('Should approve and display allowance correctly.', async () => {
    const startingAllowance = await this.token.allowance(accounts[1], accounts[2]);

    assert.equal(startingAllowance, 0, 'Function allowance should be zero by default.');

    await this.token.approve(accounts[2], 5, {from: accounts[1]});
    const finalAllowance = new BN(await this.token.allowance(accounts[1], accounts[2])).toString();
    assert.equal(finalAllowance, '5', 'Allowance is not approved correctly.'); 
    
  });
    

  //increaseAllowance
  it("should increase Allowance", async() =>{
    const startingAllowance = await this.token.allowance(accounts[1], accounts[2]);

    assert.equal(startingAllowance, 0, 'Function allowance should be zero by default.');

    await this.token.approve(accounts[2], 5, {from: accounts[1]});
    await this.token.increaseAllowance(accounts[2], 1,{from: accounts[1]});
    const finalAllowance = new BN(await this.token.allowance(accounts[1], accounts[2])).toString();
    assert.equal(finalAllowance, '6', 'Allowance is not assigned correctly.'); 
  });

  //decreaseAllowance 
  it('Should decrease total allowance.', async () => {
    const startingAllowance = await this.token.allowance(accounts[1], accounts[2]);

    assert.equal(startingAllowance, 0, 'Function allowance should be zero by default.');

    await this.token.approve(accounts[2], 5, {from: accounts[1]});
    await this.token.decreaseAllowance(accounts[2], 1, {from: accounts[1]});
    const finalAllowance = new BN(await this.token.allowance(accounts[1], accounts[2])).toString();
    assert.equal(finalAllowance, '4', 'Allowance is not assigned correctly.'); 


  });



  //mint
  it('Should return new minted balance.', async () => {
   
    await this.token.mint(accounts[1], 10,{ from: accounts[0]});
    const finalBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    

    assert.equal(finalBalance_one, '10', 'Incorrect mint amount.');

  });

  //burn
  it('Should burn correctly.', async () => {
    await this.token.mint(accounts[1], 10, {from: accounts[0]});
    const startingBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(startingBalance_one, '10', 'Incorrect mint amount.');

    await this.token.burn(accounts[1], 3, {from: accounts[1]});
    const finalBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    const totalBurned = new BN(await this.token.totalBurned).toString();

    //Checking final balance and totalBurned
    assert.equal(finalBalance_one, '7', 'Incorrect burn amount.');
    assert.equal(totalBurned, '3', 'Incorrect total burned');
  });


  //totalSupply
  it('Should return total token supply correctly', async () => {
    await this.token.mint(accounts[1], 10, {from: accounts[0]});
    const totalSupply = new BN(await this.token.totalSupply()).toString();
    
    assert.equal(totalSupply, '10', 'Total supply not being calculated properly');
  });

  //transferFrom 
  it('Should transfer from one account to another successfuly.', async () => {
    
    await this.token.mint(accounts[1], 10, { from: accounts[0]});
    await this.token.approve(accounts[2], 5, {from: accounts[1]});
   
    //Testing if transfer exceeds allowance
    await expectRevert(this.token.transferFrom(accounts[1], accounts[3], 6, {from: accounts[2]}), 'BEP20: transfer amount exceeds allowance');
    
    await this.token.transferFrom(accounts[1], accounts[3], 5, {from: accounts[2]});
    
    const finalBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    const finalBalance_three = new BN(await this.token.balanceOf(accounts[3])).toString(); 
    const finalAllowance = await this.token.allowance(accounts[1], accounts[2]);

    assert.equal(finalAllowance, '0', 'Allowance is not being calculated properly');
    assert.equal(finalBalance_one, '5', 'Incorrect withdrawal from owner account.');
    assert.equal(finalBalance_three, '5', 'Incorrect deposit to recipient account.');

  });

  //bridgeMint onlyBridge
  it('Should burn correctly.', async () => {
    
    //Testing if bridgeMint is onlyBridge
    await this.token.bridgeMint(accounts[2], 10, {from: accounts[0]});
    const startingBalance_one = new BN(await this.token.balanceOf(accounts[2])).toString();
    await expectRevert(this.token.bridgeMint(accounts[2], 5, {from: accounts[0]}), "Only bridge should be able to mint");
    
    //Testing bridgeMint
    await this.token.bridgeMint(accounts[1], 10, {from: accounts[2]});
    const startingBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    assert.equal(startingBalance_one, '10', 'Incorrect mint amount.');

  });

  //bridgeBurn onlyBridge
  it('Should burn correctly when called by bridge.', async () => {
    
    //Burning on empty account   
    await expectRevert(this.token.bridgeBurn(accounts[2], 5, {from: accounts[2]}), "Can't burn from empty account");
        
    //Testing if burn is onlyBridge
    await this.token.bridgeMint(accounts[2], 10, {from: accounts[2]});
    await expectRevert(this.token.bridgeBurn(accounts[2], 5, {from: accounts[0]}), "Only bridge should be able to burn");
        
    await this.token.bridgeBurn(accounts[2], 3, {from: accounts[2]});
    const finalBalance_one = new BN(await this.token.balanceOf(accounts[2])).toString();
    assert.equal(finalBalance_one, '7', 'Incorrect burn amount.');
    
  });

  //bridgeBurnFrom onlyBridge
  it('Should burn from user account successfuly.', async () => {
    
    await this.token.mint(accounts[1], 10, { from: accounts[0]});
    await this.token.approve(accounts[2], 5, {from: accounts[1]});
   
    //Testing if burnFrom exceeds allowance
    await expectRevert(this.token.bridgeBurnFrom(accounts[1], 6, {from: accounts[2]}), 'BEP20: transfer amount exceeds allowance');
    
    //Burning allowance amount
    await this.token.bridgeBurnFrom(accounts[1], 5, {from: accounts[2]});
    
    //Checking balances
    const finalBalance_one = new BN(await this.token.balanceOf(accounts[1])).toString();
    const finalAllowance = await this.token.allowance(accounts[1], accounts[2]);
    assert.equal(finalAllowance, '0', 'Allowance is not being calculated properly');
    assert.equal(finalBalance_one, '5', 'Incorrect withdrawal from owner account.');
    
  });


