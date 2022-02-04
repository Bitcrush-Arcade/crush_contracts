const { BN, expectRevert, expectEvent, time } = require('@openzeppelin/test-helpers')
const { web3 } = require('@openzeppelin/test-helpers/src/setup')

const Presale = artifacts.require("Presale");
const TestNFT = artifacts.require("TestNFT");
const TestStaking = artifacts.require("StakingTest");
const TestCoin = artifacts.require("NICEToken");

contract( "PresaleTest", ([minter, buyer1, buyer2, buyer3, buyer4, dev])=>{
  beforeEach(async()=>{
    this.nft = await TestNFT.new("Crush God", "CG", {from: minter});
    this.token = await TestCoin.new("Nice", "NICE", {from: minter})
    this.staking = await TestStaking.new(this.token.address,{from: minter})
    this.presale = await Presale.new(this.nft.address, this.staking.address,{from: minter});

    await this.nft.mint(buyer1, 1,{from: minter})
    await this.nft.mint(buyer3, 2,{from: minter})
    await this.token.mint(buyer1, web3.utils.toWei("20000"),{from: minter})
    await this.token.mint(buyer2, web3.utils.toWei("20000"),{from: minter})
    await this.token.mint(buyer3, web3.utils.toWei("20000"),{from: minter})
    await this.token.mint(buyer4, web3.utils.toWei("20000"),{from: minter})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer1})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer2})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer3})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer4})
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
    await this.staking.addFunds(web3.utils.toWei("10000"),{from: buyer1})
    await this.staking.addFunds(web3.utils.toWei("10000"),{from: buyer2})
    await this.staking.addFunds(web3.utils.toWei("5000"),{from: buyer3})

    const buyer1Qualified = await this.presale.qualify(1, {from: buyer1});
    // unqualified 
    const buyer2Qualified = await this.presale.qualify(2, {from: buyer2});
    const buyer3Qualified = await this.presale.qualify(2, {from: buyer3});
    await expectRevert(  this.presale.qualify(3, {from: buyer4}), "ERC721: owner query for nonexistent token");
    assert.ok( buyer1Qualified, "Not reading NFT correctly")
    assert.ok(!buyer2Qualified, "Check for owner failed")
    assert.ok(!buyer3Qualified, "ok NFT, not ok StakeAmount")
    
  })
  it("Should only allow to buy if whitelisted and presale has started", async ()=>{})
  it("Should not allow to buy more after sale ends", async ()=>{})
  it("Should lock bought funds", async ()=>{})
  it("Should allow to claim after sale ends", async ()=>{})
  it("Should allow to withdraw more after X amount of time", async ()=>{})
})