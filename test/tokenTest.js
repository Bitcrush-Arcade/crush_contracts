const { expectRevert } = require('@openzeppelin/test-helpers');
const { BN } = require('@openzeppelin/test-helpers/src/setup');

const CRUSHToken = artifacts.require("CRUSHToken");

contract("CRUSHToken",  async accounts => {

  beforeEach( async ()=>{
    this.token = await CRUSHToken.new()
  })
  
  it("should allocate 30M tokens to first account", async () => {
    const balance = await this.token.balanceOf.call( accounts[0] );
    assert.equal( balance.valueOf(), 30 * 10 ** 24 )
  })

  it("shouldn't allow to mint any more tokens", async () => {
    await expectRevert( this.token.mint(accounts[0], 1000000), "can't mint more than max.")
  })

  it("should send tokens to account 2", async () => {
    const amountTransfered = 10000
    await this.token.transfer(accounts[1], amountTransfered )
    const balance0 = await this.token.balanceOf.call( accounts[0] )
    const balance1 = await this.token.balanceOf.call( accounts[1] )
    assert.equal( balance1, amountTransfered, "transfer to account 1 failed" )
    assert.equal( balance0, (30* 10 ** 24) - amountTransfered, "balance did not deduct")
  })

  it("shouldn't allow to send more tokens than balance", async () => {
    await expectRevert( this.token.transfer(accounts[2], 100000, { from: accounts[1] }), "BEP20: transfer amount exceeds balance" )
  })
  it("shouldn't allow to send more tokens than balance, INIT ACCOUNT", async () => {
    const amountTransfered = 10000
    await this.token.transfer(accounts[1], amountTransfered )
    const balance = await this.token.balanceOf.call( accounts[0] );
    assert.notEqual( balance.toString(), `${30 * 10 ** 24}` )
  })

  
})