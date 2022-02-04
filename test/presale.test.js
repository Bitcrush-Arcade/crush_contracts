const { BN, expectRevert, expectEvent, time } = require('@openzeppelin/test-helpers')
const { web3 } = require('@openzeppelin/test-helpers/src/setup')

const Presale = artifacts.require("Presale");
const TestNFT = artifacts.require("TestNFT");

contract( "PresaleTest", ([minter, buyer1, buyer2, buyer3, dev])=>{
  beforeEach(async()=>{
    this.nft = await TestNFT.new("Crush God", "CG", {from: minter});
    this.presale = await Presale.new(this.nft.address,{from: minter});

    await this.nft.mint(buyer1, 1,{from: minter})
  })

  it("Should update the start sale for X amount", async ()=>{
    const saleDuration = new BN(await this.presale.saleDuration.call())
    
    const start = await this.presale.toggleSaleStart({from: minter});
    expectEvent( start, "UpdateSaleStatus", {
      status: true
    })
    const currentBlock = new BN((await web3.eth.getBlock("latest")).number);
    
    const saleStarted = await this.presale.saleStart.call();
    const saleEnd = new BN(await this.presale.saleEnd.call()).toString();
    
    assert.ok(saleStarted, "Sale did not start");
    assert.equal(saleEnd, saleDuration.add(currentBlock).toString(), "Sale did not start");
  })

  it("Should close sale after x amount of blocks", async ()=>{
    // FOR THIS TEST TO SUCCEED PLEASE CHANGE SALE DURATION TO 100 otherwise it'll be too slow
    const saleDuration = new BN(await this.presale.saleDuration.call())
    await this.presale.toggleSaleStart({from: minter})

    const currentBlock = new BN((await web3.eth.getBlock("latest")).number);
    await expectRevert(this.presale.toggleSaleStart({from: minter}), "Sale running");
    await time.advanceBlockTo( currentBlock.add( saleDuration ))
    const receipt = await this.presale.toggleSaleStart({from:minter})

    expectEvent( receipt, "UpdateSaleStatus", {
      status: false
    })

    await time.advanceBlockTo( currentBlock.add( saleDuration ).add( new BN("5")))
    await expectRevert( this.presale.toggleSaleStart({from:minter}), "No restart")
  })
  it("Should check if user has NFT and Staked Amount", async ()=>{
    const isQualified = await this.presale.qualify(1, {from: buyer1});
    assert.ok( isQualified, "Not reading NFT correctly")
    const notOwner = await this.presale.qualify(1, {from:buyer2});
    assert.ok(!notOwner, "Check for owner failed")
    await expectRevert( this.presale.qualify(3,{from:buyer3}))
  })
  it("Should only allow to buy if whitelisted and presale has started", async ()=>{})
  it("Should not allow to buy more after sale ends", async ()=>{})
  it("Should lock bought funds", async ()=>{})
  it("Should allow to claim after sale ends", async ()=>{})
  it("Should allow to withdraw more after X amount of time", async ()=>{})
})