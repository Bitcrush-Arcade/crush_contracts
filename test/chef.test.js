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
  it("Should allow owner to add regular pools", async () => {
    const fee = 600
    const allocation = 1000
    await expectRevert( this.chef.addRegular( this.lpToken.address, ""+fee, allocation ), "Ownable: caller is not the owner")
    await expectRevert( this.chef.addRegular( this.lpToken.address, "25000", allocation ), "add: invalid fee")
    await this.chef.addRegular( this.lpToken.address, ""+fee, allocation );

    const poolData = await this.chef.poolInfo(1)

    assert.equal(poolData.poolType.toString(), new BN(0).toString(), "Wrong pool type")
    assert.equal(poolData.alloc.toString(), new BN(0).toString(), "Wrong pool allocation")
    assert.equal(poolData.fee.toString(), new BN(0).toString(), "Wrong pool fee")
    assert.equal(poolData.token, this.lpToken.address, "Wrong pool token")

    assert.equal( new BN(await this.chef.regularAlloc()).toString(), "1000", "Total allocation not updating")

  })
  it("Should allow owner to add fixed pools", async () => {})
  it("Should allow owner to add TP pools", async () => {})
  it("Should allow owner to edit fees on pools", async () => {})
  it("Should allow owner to edit allocations on pools", async () => {})
  it("Reward for fixed pools should be correctly calculated", async () => {})
  it("Reward for regular pools should be correctly calculated", async () => {})
  it("Reward for TP pools should be correctly calculated", async () => {})
  // USERS
  // Regular POOLs
  it("Should allow user to deposit tokens to regular Pool ", async()=>{})
  it("Should calculate correct shares for user per pool", async()=>{})
  it("Should calculate calculated reward for user per pool", async()=>{})
  it("Should allow user to withdraw tokens from regular Pool with rewards", async()=>{})
  it("Should allow user to emergency withdraw tokens from regular Pool without rewards", async()=>{})
  it("Should allow user to claim reward tokens from regular Pool ", async()=>{})
  // Fixed POOLS
  it("Should allow user to deposit tokens to fixed Pool ", async()=>{})
  it("Should allow user to deposit tokens to fixed Pool ", async()=>{})
  it("Should allow user to withdraw tokens from fixed Pool with rewards", async()=>{})
  it("Should allow user to claim reward tokens from fixed Pool ", async()=>{})
  //  TP pool
  it("Should calculate rewards for TP pool", async()=>{})
  it("Should only mint rewards for TP pool", async()=>{})
})