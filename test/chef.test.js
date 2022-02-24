const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const Token = artifacts.require("NiceToken");
const Chef = artifacts.require("GalacticChef");

contract("GalacticChefTest", ([minter, user1, user2, user3, tp1, tp2]) =>{

  beforeEach( async()=>{
    this.rewardToken = await Token.new("Reward Token","RW")
    this.chef = await Chef.new(this.rewardToken.address)
    this.lpToken = await Token.new("Liquidity 1","LP1")
    this.lpTokenReg1 = await Token.new("Liquidity 2","LP2")
    this.lpTokenReg2 = await Token.new("Liquidity 3","LP3")
    this.lpTokenFixed1 = await Token.new("Liquidity 4","LP4")
    this.lpTokenFixed2 = await Token.new("Liquidity 5","LP5")
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
    await expectRevert( this.chef.addPool( this.lpToken.address, multiplier, fee, false, [], [] ), "Ownable: caller is not the owner")
    await expectRevert( this.chef.addPool( this.lpToken.address, multiplier, "", false, [], [] ), "add: invalid fee")
    await this.chef.addPool( this.lpToken.address, multiplier, fee, false, [], [] );

    const poolData = await this.chef.poolInfo(1)

    assert.ok(!poolData.poolType, "Type not added incorrectly")
    assert.equal( new BN(poolData.mult).toString(), multiplier.toString(), "Multiplier added incorrectly")
    assert.equal( new BN(poolData.fee).toString(), fee.toString(), "Fee not added correctly")
    assert.equal( poolData.token, this.lpToken.address,"Token Addresses dont match")
    assert.equal( new BN(poolData.accRewardPerShare).toString(), "0" ,"Whats up with the shares?")
  })
  it("Should force adjustment of pool if multiplier exceeds max", async () => {})
  it("Should allow owner to add TP pools", async () => {})
  it("Should allow owner to edit fees on pools", async () => {})
  it("Should allow owner to edit multiplier on pools", async () => {})
  it("Reward for regular pools should be correctly calculated", async () => {})
  it("Should edit the amount of active chefs to correct rewards given", async () => {})
  it("Should change rewards calculated as time passes by", async () => {})
  // USERS
  // Regular POOLs
  it("Should allow user to deposit tokens to regular Pool ", async()=>{})
  it("Should calculate calculated reward for user per pool", async()=>{})
  it("Should allow user to withdraw tokens from regular Pool with rewards", async()=>{})
  it("Should allow user to emergency withdraw tokens from regular Pool without rewards", async()=>{})
  it("Should allow user to claim reward tokens from regular Pool ", async()=>{})
  //  TP pool
  it("Should calculate rewards for TP pool", async()=>{})
  it("Should mint rewards for TP pool", async()=>{})
})