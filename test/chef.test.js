const { BN, expectRevert, expectEvent, time } = require("@openzeppelin/test-helpers");
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const Token = artifacts.require("NiceToken");
const Chef = artifacts.require("GalacticChef");

contract("GalacticChefTest", ([minter, user1, user2, user3, tp1, tp2]) =>{
  
  const toWei = (number) => {
    const stringNumber = typeof(number) === "string" ? number : number.toString()
    return web3.utils.toWei(stringNumber)
  }

  beforeEach( async()=>{
    // Setting up emissions
    this.emissions = 10
    this.rewardToken = await Token.new("Reward Token","RW")
    this.chef = await Chef.new(this.rewardToken.address, toWei(this.emissions), 1)
    this.lpToken = await Token.new("Liquidity 1","LP1")
    this.lpTokenReg1 = await Token.new("Liquidity 2","LP2")
    this.lpTokenReg2 = await Token.new("Liquidity 3","LP3")
    // Allows Chef to mint
    await this.rewardToken.toggleMinter(this.chef.address)
    this.divisor = 10000
  })

  // OWNER ONLY
  // TP pools are pools where thirdParty Tokens are added in. Chef only needs to distribute the rewards for these.
  it("Should allow owner to add a regular pool", async () => {
    // First Pool added
    const fee = 600
    const multiplier = 250000; // MAX MULTIPLIER OF 100_0000
    await expectRevert( this.chef.addPool( this.lpToken.address, multiplier, fee, false, [], [], {from: user1} ), "Ownable: caller is not the owner")
    await expectRevert( this.chef.addPool( this.lpToken.address, multiplier, "5001", false, [], [] ), "add: invalid fee")
    await this.chef.addPool( this.lpToken.address, multiplier, fee, false, [], [] );

    const poolData = await this.chef.poolInfo(1)

    assert.ok(!poolData.poolType, "Type not added incorrectly")
    assert.equal( new BN(poolData.mult).toString(), multiplier.toString(), "Multiplier added incorrectly")
    assert.equal( new BN(poolData.fee).toString(), fee.toString(), "Fee not added correctly")
    assert.equal( poolData.token, this.lpToken.address,"Token Addresses dont match")
    assert.equal( new BN(poolData.accRewardPerShare).toString(), "0" ,"Whats up with the shares?")
  })
  it("Should adjust pool multipliers if new pool multiplier exceeds max", async () => {
    const fee = 0
    const m1 = 1000000 //100%
    const m2 = 100000  //10%
    const adjust = 900000 // 90%

    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);
    await expectRevert( this.chef.addPool( this.lpToken.address, m1, fee, false, [], []), "add: token repeated")
    await expectRevert( this.chef.addPool( this.lpTokenReg1.address, m2, fee, false, [], []), "add: wrong multiplier")
    await this.chef.addPool( this.lpTokenReg1.address, m2, fee, false, [1], [adjust])
    
    const pool1 = await this.chef.poolInfo(1)
    const pool2 = await this.chef.poolInfo(2)

    assert.equal( new BN(pool1.mult).toString(), ""+adjust,"Incorrect pool 1 mult adjust value" )
    assert.equal( new BN(pool2.mult).toString(), ""+m2,"Incorrect pool 2 mult value" )

  })
  it("Should allow owner to add TP pools", async () => {
    const fee = 0
    const m1 = 300000 //30X
    const m2 = 100000  //10%

    // Added Regular Pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);
    await this.chef.addPool( tp1, m2, fee, true, [], []);

    const pool1 = await this.chef.poolInfo(1)
    const pool2 = await this.chef.poolInfo(2)

    assert.equal(new BN(pool1.mult).toString(), m1.toString(), "Incorrect multiplier pool 1")
    assert.equal(new BN(pool2.mult).toString(), m2.toString(), "Incorrect multiplier pool 2")
    assert.ok(pool2.poolType, "Pool type incorrect")

  })
  it("Should allow owner to edit fees on pools", async () => {
    const fee = 0
    const m1 = 300000 //30X

    // Added Regular Pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);

    await expectRevert( this.chef.editPoolFee(1,1500, {from: user1}), "Ownable: caller is not the owner" )
    await expectRevert( this.chef.editPoolFee(1,2503,), "edit: high fee" )
    await this.chef.editPoolFee(1,1500)

    const poolData = await this.chef.poolInfo(1)
    assert.equal( new BN(poolData.fee).toString(), (1500).toString(), "Fee not edited")
  })
  it("Should allow owner to edit multiplier on pools", async () => {
    const fee =    0
    const m1 =     300000 //30X
    const m2 =     100000 //10X
    const adjust = 200000// 20X

    // Added Regular Pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);
    await this.chef.addPool( this.lpTokenReg1.address, m1, fee, false, [], []);
    await this.chef.addPool( this.lpTokenReg2.address, m1, fee, false, [], []);
    await this.chef.addPool( this.rewardToken.address, m2, fee, false, [], []);

    await expectRevert( this.chef.editPoolMult([4], [m1]) ,"mult: exceeds max" )
    await expectRevert( this.chef.editPoolMult([5], [adjust]) ,"mult: nonexistent pool" )
    await expectRevert( this.chef.editPoolMult([2,6], [adjust,m2]) ,"mult: nonexistent pool" )

    await this.chef.editPoolMult([4,2], [adjust,adjust])

    const pool2Data = await this.chef.poolInfo(2)
    const pool4Data = await this.chef.poolInfo(4)
    const max = await this.chef.currentMax()

    assert.equal( pool2Data.mult.toString(), ""+adjust, "Invalid Multiplier 2")
    assert.equal( pool4Data.mult.toString(), ""+adjust, "Invalid Multiplier 4")
    assert.equal( max.toString(), "1000000", "Invalid Multiplier 4")
  })
  it("Reward for regular pools should be correctly calculated", async () => {})
  it("Should edit the amount of active chains to correct rewards given", async () => {})
  // USERS
  // Regular POOLs 
  
  //function deposit()
  it("Should allow user to deposit tokens to regular Pool ", async()=>{
    const m1 = 20000 // 100 0000 mul *2
    const fee = 1000  // 100 00 fee 10.00%
    
    // Create token pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);

    // mint tokens for user
    await this.lpToken.mint(user1, toWei(100));

    // approve token spend on contract
    await this.lpToken.approve(this.chef.address, toWei(100), { from: user1} );

    // deposit funds to correct PID
    await this.chef.deposit(toWei("60"), 1, {from: user1});

    // check if fee was collected

    const userBalance = await this.lpToken.balanceOf(user1);
    const userContractBalance = await this.chef.userInfo(1,user1)
    const feeDev = await this.lpToken.balanceOf(minter);
    assert.equal( userBalance.toString(), toWei(40),"Fee was not collected properly");
    assert.equal( userContractBalance.amount.toString(), toWei(60*(1 - (fee/10000))),"Fee was not collected properly");
    // check if correct fee amount is available.
    assert.equal( feeDev.toString(), toWei(60*(fee/10000)),"Fee was not collected properly");

 })

  // function pendingRewards()  
  it("Should calculate calculated reward for user per pool", async()=>{
    const m1 = 20000 // 100 0000 mul *2
    const fee = 0  // 100 00 fee 10.00%
    
    // Create token pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);

    // mint tokens for user
    await this.lpToken.mint(user1, toWei(100));

    // approve token spend on contract
    await this.lpToken.approve(this.chef.address, toWei(100), {from: user1});

    // deposit funds to correct PID
    await this.chef.deposit(toWei(60), 1, {from: user1});
    await time.increase( time.duration.minutes(30) );
    const userReward = await this.chef.pendingRewards(user1, 1); 

    // PENDING: SHOULD CHECK ACTUAL REWARD WITH A DEPOSIT(0) AND SEE IF THEY MATCH
    

    // Calculating reward with pendingReward()
    const userAmount = 60 //Total supply in liquidity pool
    const multiplier = this.emissions * time.duration.minutes(30)*m1
    const maxMultiplier = m1 * 60 
    const updatedPerShare = (multiplier/maxMultiplier)
    const pendingRewards = (updatedPerShare*userAmount)



    assert.equal( web3.utils.fromWei(userReward), pendingRewards.toString() ,"Incorrect reward");

  })

  
  //function withdraw()
 it("Should allow user to withdraw tokens from regular Pool with rewards", async()=>{

  const m1 = 20000 // 100 0000 mul *2
  const fee = 0  // 100 00 fee 10.00%
  
  // Create token pool
  await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);

  // mint tokens for user
  await this.lpToken.mint(user1, toWei(100));

  // approve token spend on contract
  await this.lpToken.approve(this.chef.address, toWei(100), {from: user1});

  // deposit funds to correct PID
  await this.chef.deposit(toWei(60), 1, {from: user1});

  // Waiting half an hour and withdrawing staked lpTokens
  await time.increase( time.duration.minutes(30))
  await this.chef.withdraw(toWei(60), 1, {from: user1}); 
  const userLpBalance = await this.lpToken.balanceOf(user1);
  const userNiceBalance = await this.rewardToken.balanceOf(user1);

  // Calculating reward 
  const userAmount = 60 //Total supply in liquidity pool
  const multiplier = this.emissions * (time.duration.minutes(30))*m1
  const maxMultiplier = m1 * 60
  const updatedPerShare = (multiplier/maxMultiplier)
  const userRewards = (updatedPerShare*userAmount)

  // lp balance should be the total deposited
  assert.equal( web3.utils.fromWei(userLpBalance), ""+100, "Incorrect balance withdrawn");

  // Nice balance should be reward, includes a error margin of 32 due to pc processing limitations
  assert.ok(Math.abs(parseInt(web3.utils.fromWei(userNiceBalance)) - userRewards) < 32,"Incorrect reward");

 })

  //function emergencyWithdraw()
  it("Should allow user to emergency withdraw tokens from regular Pool without rewards", async()=>{

    const m1 = 20000 // 100 0000 mul *2
    const fee = 0  // 100 00 fee 10.00%
    
    // Create token pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);
  
    // mint tokens for user
    await this.lpToken.mint(user1, toWei(100));
  
    // approve token spend on contract
    await this.lpToken.approve(this.chef.address, toWei(100), {from: user1});
  
    // deposit funds to correct PID
    await this.chef.deposit(toWei(60), 1, {from: user1});
  
    // Waiting half an hour and withdrawing staked lpTokens
    await time.increase( time.duration.minutes(30) )
    await this.chef.emergencyWithdraw(1, {from: user1}); 
    const userLpBalance = await this.lpToken.balanceOf(user1);
    const userNiceBalance = await this.rewardToken.balanceOf(user1);
  
    // User reward should be 0 
    const userRewards = 0
  
    // lp balance should be the total deposited
    assert.equal( web3.utils.fromWei(userLpBalance), ""+100, "Incorrect balance withdrawn");
  
    // Nice balance should be reward
    assert.equal( web3.utils.fromWei(userNiceBalance), userRewards.toString() ,"Incorrect reward");

  })
  it("Should allow user to claim reward tokens from regular Pool ", async()=>{

    const m1 = 20000 // 100 0000 mul *2
    const fee = 0  // 100 00 fee 10.00%
    
    // Create token pool
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []);
  
    // mint tokens for user
    await this.lpToken.mint(user1, toWei(100));
  
    // approve token spend on contract
    await this.lpToken.approve(this.chef.address, toWei(100), {from: user1});
  
    // deposit funds to correct PID
    await this.chef.deposit(toWei(60), 1, {from: user1});
  
    // Waiting half an hour and depositing 0 to harvest
    await time.increase( time.duration.minutes(30) );
    await this.chef.deposit(0, 1, {from: user1}); //reward gets transferred to user1 when depositing 0
    const userLpBalance = await this.lpToken.balanceOf(user1);
    const userNiceBalance = await this.rewardToken.balanceOf(user1);
  
    // User reward should be 0 
    const userAmount = 60 //Total supply in liquidity pool
    const multiplier = this.emissions * time.duration.minutes(30)*m1
    const maxMultiplier = m1 * 60
    const updatedPerShare = (multiplier/maxMultiplier)
    const userRewards = (updatedPerShare*userAmount)
  
    // Checking lp balance from user1 after deposit(0)
    assert.equal( web3.utils.fromWei(userLpBalance), ""+40, "Balance should be 40");
  
    // Nice balance should be reward, added 32 error margin due to pc processing limitations
    //assert.equal(web3.utils.fromWei(userNiceBalance) , userRewards.toString(), "Incorrect reward");
    assert.ok(Math.abs(parseFloat(web3.utils.fromWei(userNiceBalance)) - userRewards) < 32, "Incorrect reward");

  })
  //  TP pool
  it("Should not take deposits or make withdraws on TP pool", async()=>{
    //deposits and withdraws should fail
    const m1 = 20000 // mul *2
    const m2 = 30000 // mul *3
    const fee = 0  // 100 00 fee 10.00%
    
    // Creating token pools
    await this.chef.addPool( tp1, m1, fee, true, [], []);

    // Expecting deposit and withdrawals to fail
    await expectRevert(this.chef.deposit(60, 1,{from: user1}), "Deposit: Tp Pool");
    await expectRevert(this.chef.withdraw(60, 1,{from: user1}), "Withdraw: Tp Pool");

  })

  it("Should mint rewards for TP pool", async()=>{

    const m1 = 20000 // mul *2
    const fee = 0  // 100 00 fee 10.00%
    
    // Adding token pool to chef, pid = 1
    await this.chef.addPool( tp1, m1, fee, true, [], []); //chef has his lptoken wallet

    // tp1 mints rewards to its wallet through master chef
    await this.chef.mintRewards(1, {from: tp1});

    // Checking tp1's wallet for the minted amount
    const currentEmissions = await this.chef.getCurrentEmissions(1);
    const mintedAmount = currentEmissions*m1/(m1*1e12)
    const tp1Balance = this.rewardToken.balanceOf(tp1);

    assert.equal(mintedAmount,tp1Balance, "Wrong amount minted");

  })

  it("Should halve emissions yearly", async()=>{

    const m1 = 20000 // mul *2
    const fee = 0  // 100 00 fee 10.00%

    //Timestamps
    const year1 = 1640995200 //00:00 2022
    const year2 = 1672531200 //00:00 2023
    const year3 = 1704067200 //00:00 2024
    const year4 = 1735689600 //00:00 2025
    const year5 = 1767225600 //00:00 2026
    const year6 = 1798761600 //00:00 2027

    // Setting up
    // Adding token pool to chef, pid = 1
    await this.chef.addPool( this.lpToken.address, m1, fee, false, [], []); 

    // Minting tokens to user1
    await this.lpToken.mint(user1, toWei(4000));

    // Approve token spend on contract
    await this.lpToken.approve(this.chef.address, toWei(4000), {from: user1});

    // Setting time to 2022 jan 1 00:00
    await time.increaseTo(year1);

    // y1
    // User1 deposits an amount to chef at 2022 jan 1, 00:00
    await this.chef.deposit(toWei(60), 1, {from: user1});
    // Then withdraws at 2022 jan 1, 00:30
    await time.increase(time.duration.minutes(30));
    await this.chef.withdraw(toWei(60), 1, {from: user1});

    const y1Emissions = await this.chef.currentEmissions(1);
    const y1RewardBalance = this.rewardToken.balanceOf(user1);

    // Calculating rewards for year 1 withdrawal
    const userAmount = 60 //Total supply in liquidity pool before withdrawal
    const multiplier = this.emissions * time.duration.minutes(30)*m1
    const maxMultiplier = m1 * 60
    const updatedPerShare = (multiplier/maxMultiplier)
    const y1UserRewards = (updatedPerShare*userAmount)

    assert.equal(y1Emissions, toWei(this.emissions), "Incorrect y1 emissions");
    assert.equal(y1RewardBalance, y1UserRewards, "Incorrect amount rewarded y1");

    // y2
    await time.increaseTo(year2);
    // User1 deposits an amount to chef at 2023 jan 1, 00:00
    await this.chef.deposit(toWei(60), 1, {from: user1});
    // Then withdraws at 2023 jan 1, 00:30
    await time.increase(time.duration.minutes(30));
    await this.chef.withdraw(toWei(60), 1, {from: user1});

    const y2Emissions = await this.chef.currentEmissions(1);
    const y2RewardBalance = this.rewardToken.balanceOf(user1);

    assert.equal(y2Emissions, toWei(this.emissions)/2, "Incorrect y1 emissions");
    assert.equal(y2RewardBalance, (3/2)*y1UserRewards, "Incorrect amount rewarded y1");

    // y3
    await time.increaseTo(year3);
    // User1 deposits an amount to chef at 2024 jan 1, 00:00
    await this.chef.deposit(toWei(60), 1, {from: user1});
    // Then withdraws at 2024 jan 1, 00:30
    await time.increase(time.duration.minutes(30));
    await this.chef.withdraw(toWei(60), 1, {from: user1});

    const y3Emissions = await this.chef.currentEmissions(1);
    const y3RewardBalance = this.rewardToken.balanceOf(user1);

    assert.equal(y3Emissions, toWei(this.emissions)/4, "Incorrect y1 emissions");
    assert.equal(y3RewardBalance, (7/4)*y1UserRewards, "Incorrect amount rewarded y1");

    // y3 => y4
    // Checking if rewards are calculated correctly when changing year
    // 2024 last day 23:30
    await time.increaseTo(year4-time.duration.minutes(30));
    // User deposits
    await this.chef.deposit(toWei(60), 1, {from: user1});
    // Then withdraws in 2025 at 00:30
    await time.increase(time.duration.hours(1));
    await this.chef.withdraw(toWei(60), 1, {from: user1});

    const y4Emissions = await this.chef.currentEmissions(1);
    const y34RewardBalance = this.rewardToken.balanceOf(user1);

    assert.equal(y4Emissions, toWei(this.emissions)/8, "Incorrect y1 emissions");
    assert.equal(y34RewardBalance, (17/8)*y1UserRewards, "Incorrect amount rewarded y1");

  })
  it("Should split the emissions evenly in different chains", async()=>{})

})