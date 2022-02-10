const { BN, expectRevert, expectEvent, time } = require('@openzeppelin/test-helpers')
const { web3 } = require('@openzeppelin/test-helpers/src/setup')

const Presale = artifacts.require("Presale");
const TestNFT = artifacts.require("TestNFT");
const TestStaking = artifacts.require("StakingTest");
const TestCoin = artifacts.require("NICEToken");

contract( "PresaleTest", ([minter, buyer1, buyer2, buyer3, buyer4, dev])=>{
  beforeEach(async()=>{
    this.nft = await TestNFT.new("Crush God", "CG", {from: minter});
    this.token = await TestCoin.new("CrushCoin", "CRUSH", {from: minter})
    this.niceToken = await TestCoin.new("Nice", "NICE", {from: minter})
    this.busd = await TestCoin.new("Binance Pegged USD", "BUSD", {from: minter})
    this.staking = await TestStaking.new(this.token.address,{from: minter})
    this.presale = await Presale.new(this.nft.address, this.staking.address, this.busd.address,{from: minter});

    await this.nft.mint(buyer1, 1,{from: minter})
    await this.nft.mint(buyer3, 2,{from: minter})
    await this.token.mint(buyer1, web3.utils.toWei("20000"),{from: minter})
    await this.token.mint(buyer2, web3.utils.toWei("20000"),{from: minter})
    await this.token.mint(buyer3, web3.utils.toWei("20000"),{from: minter})
    await this.token.mint(buyer4, web3.utils.toWei("20000"),{from: minter})
    await this.busd.mint(buyer1, web3.utils.toWei("3000"),{from: minter})
    await this.busd.mint(buyer2, web3.utils.toWei("3000"),{from: minter})
    await this.busd.mint(buyer3, web3.utils.toWei("3000"),{from: minter})
    await this.busd.mint(buyer4, web3.utils.toWei("3000"),{from: minter})

    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer1})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer2})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer3})
    await this.token.approve(this.staking.address, web3.utils.toWei("100000"),{from: buyer4})

    await this.busd.approve(this.presale.address, web3.utils.toWei("100000"),{from: buyer1})
    await this.busd.approve(this.presale.address, web3.utils.toWei("100000"),{from: buyer2})
    await this.busd.approve(this.presale.address, web3.utils.toWei("100000"),{from: buyer3})
    await this.busd.approve(this.presale.address, web3.utils.toWei("100000"),{from: buyer4})

    await this.presale.setNiceToken( this.niceToken.address, {from: minter})
    await this.niceToken.toggleMinter(this.presale.address, {from: minter})

    await this.staking.addFunds(web3.utils.toWei("10000"),{from: buyer1})

  })
  // Sale start opens up whitelist first and set the timestamp for sale start
  it("Should update the start sale for 12 hours and 30 min of whitelist time", async ()=>{
    const saleDuration = new BN(await this.presale.saleDuration.call())
    
    const start = await this.presale.startSale({from: minter});
    const currentBlock = new BN((await web3.eth.getBlock("latest")).timestamp);
    expectEvent( start, "SaleStarts", {
      startBlock: currentBlock.add( web3.utils.toBN("1800"))
    })
    const saleEnd = new BN(await this.presale.saleEnd.call()).toString();
    
    assert.equal(saleEnd, saleDuration.add(currentBlock.add( web3.utils.toBN("1800"))).toString(), "Sale end time not calculated");
  })

  it("Should check if user has NFT and valid Staked Amount", async ()=>{
    await this.staking.addFunds(web3.utils.toWei("10000"),{from: buyer2})
    await this.staking.addFunds(web3.utils.toWei("5000"),{from: buyer3})

    const buyer1Qualified = await this.presale.qualify({from: buyer1});
    // unqualified 
    const buyer2Qualified = await this.presale.qualify.call({from: buyer2});
    const buyer3Qualified = await this.presale.qualify.call({from: buyer3});
    const buyer4Qualified = await this.presale.qualify.call({from: buyer4});
    assert.ok( buyer1Qualified, "Not reading NFT or crush amount correctly")
    assert.ok(!buyer2Qualified, "Check for owner failed")
    assert.ok(!buyer3Qualified, "ok NFT, not ok StakeAmount")
    assert.ok(!buyer4Qualified, "no NFT, no StakeAmount")
    
  })
  it("Should only allow whitelists to buy", async() => {
    await expectRevert( this.presale.whitelistSelf(1, {from: buyer1}), "Whitelist not started")
    await this.presale.startSale({from: minter});
    await this.presale.whitelistSelf(1, {from: buyer1})
    await this.presale.buyNice(web3.utils.toWei("100"), {from: buyer1});
    await expectRevert( this.presale.buyNice(web3.utils.toWei("300"), {from: buyer2}), "Whitelist only")
  })
  it("Should not allow to buy after sale End 12 hours and 30 min", async ()=>{
    await this.presale.startSale({from: minter})
    await this.presale.whitelistSelf(1, {from: buyer1})
    const currentBlock = new BN((await web3.eth.getBlock("latest")).timestamp);
    await time.increase(time.duration.hours(12) + time.duration.minutes(30)); //30 min increase + 100secs of sale duration
    await expectRevert( this.presale.buyNice(web3.utils.toWei("150"), {from: buyer1}), "SaleEnded")
  })
  it("Should only allow to buy with exact BUSD", async ()=>{
    await this.presale.startSale({from: minter})
    await this.presale.whitelistSelf(1, {from: buyer1})
    await time.increase(time.duration.minutes(30)) //increase whitelist time
    
    // SHOULD ALLOW A MINIMUM BUY OF 100$
    await expectRevert( this.presale.buyNice(web3.utils.toWei("50"),{from: buyer1}), "Minimum not met")
    await expectRevert( this.presale.buyNice(web3.utils.toWei("100.50"),{from: buyer1}), "Exact amounts only")
    await this.presale.buyNice(web3.utils.toWei("100"), {from: buyer1})
    // MAXIMUM AMOUNT TBD
    const presaleBalance = web3.utils.fromWei(await this.busd.balanceOf(this.presale.address))
    const userFinalBalance = web3.utils.fromWei(await this.busd.balanceOf(buyer1))
    assert.equal(presaleBalance, "100", "BUSD funds don't match")
    assert.equal(userFinalBalance, "2900", "BUSD was not removed correctly for user" )
  })
  it("Should show bought funds amount", async ()=>{
    await this.presale.startSale({from: minter})
    await this.presale.whitelistSelf(1,{from:buyer1})
    await time.increase(time.duration.minutes(30)) //increase whitelist time
    await this.presale.buyNice(web3.utils.toWei("100"), {from: buyer1})

    const user1Info = await this.presale.userBought(buyer1)
    assert.equal(user1Info.amountOwed.toString(), new BN(web3.utils.toWei("100")).mul( new BN("10000")).div( new BN("47")).toString(), "Not the right amount owed")
  })
  it("Should allow to claim after sale ends", async ()=>{
    await this.presale.startSale({from: minter})
    await this.presale.whitelistSelf(1, {from: buyer1})
    await time.increase(time.duration.minutes(30)); //30 minute increase for whitelist end
    await this.presale.buyNice(web3.utils.toWei("100"), {from: buyer1})
    await expectRevert( this.presale.claimTokens({from: buyer1}), "Claim Unavailable")
    await time.increase(time.duration.hours(13));  //12 hours of sale duration
    await expectRevert( this.presale.claimTokens({from: buyer1}), "Claim Unavailable")
    await time.increase(time.duration.weeks(2));  //12 hours of sale duration
    await this.presale.claimTokens({from: buyer1})
    const user1Nice = await this.niceToken.balanceOf(buyer1)
    // ONLY CLAIM OF 25%
    assert.equal(user1Nice.toString(), new BN(web3.utils.toWei("100")).mul( new BN("10000")).div( new BN("47")).mul(new BN("25")).div( new BN("100")).toString(), "Incorrect amount of NICE minted")
  })
  it("Should allow to withdraw more after X amount of time", async ()=>{

    await this.presale.startSale({from: minter})
    await this.presale.whitelistSelf(1, {from: buyer1})
    await time.increase(time.duration.minutes(30)); //30 minute increase for whitelist end
    await this.presale.buyNice(web3.utils.toWei("100"), {from: buyer1})
    await expectRevert( this.presale.claimTokens({from: buyer1}), "Claim Unavailable")
    
    await time.increase(time.duration.hours(13));  //12 hours of sale duration
    await expectRevert(this.presale.claimTokens({from: buyer1}),"Claim Unavailable")
    // ONLY CLAIM OF 25% AFTER END
    await time.increase(time.duration.weeks(2));  //12 hours of sale duration
    await this.presale.claimTokens({from: buyer1})
    let user1Nice = await this.niceToken.balanceOf(buyer1)
    assert.equal(user1Nice.toString(), new BN(web3.utils.toWei("100")).mul( new BN("10000")).div( new BN("47")).mul(new BN("25")).div( new BN("100")).toString(), "Incorrect amount of NICE minted")
    // ONLY CLAIM OF 50% AFTER END + X WEEKS
    await time.increase(time.duration.weeks(2));  //2 weeks of sale duration
    await this.presale.claimTokens({from: buyer1})
    await expectRevert(this.presale.claimTokens({from: buyer1}), "Already claimed")
    user1Nice = await this.niceToken.balanceOf(buyer1)
    assert.equal(user1Nice.toString(), new BN(web3.utils.toWei("100")).mul( new BN("10000")).div( new BN("47")).mul(new BN("50")).div( new BN("100")).toString(), "Incorrect amount of NICE minted")
    // ONLY CLAIM OF 75% AFTER END + 2X WEEKS
    await time.increase(time.duration.weeks(2));  //2 weeks of sale duration
    await this.presale.claimTokens({from: buyer1})
    user1Nice = await this.niceToken.balanceOf(buyer1)
    assert.equal(user1Nice.toString(), new BN(web3.utils.toWei("100")).mul( new BN("10000")).div( new BN("47")).mul(new BN("75")).div( new BN("100")).toString(), "Incorrect amount of NICE minted")
    // TOTAL CLAIM OF 100% AFTER END + 3X WEEKS
    await time.increase(time.duration.weeks(2));  //2 weeks of sale duration
    await this.presale.claimTokens({from: buyer1})
    user1Nice = await this.niceToken.balanceOf(buyer1)
    assert.ok(user1Nice.sub( new BN(web3.utils.toWei("100")).mul( new BN("10000")).div( new BN("47")).mul(new BN("100")).div( new BN("100"))) < new BN("10"), "Incorrect amount of NICE minted")
  })
  it("Should allow the owner to claim the raised funds", async () => {
    await this.presale.startSale({from: minter})
    await this.presale.whitelistSelf(1, {from: buyer1})
    await time.increase(time.duration.minutes(30)); //30 minute increase for whitelist end
    await this.presale.buyNice(web3.utils.toWei("100"), {from: buyer1})
    await expectRevert( this.presale.claimRaised({from: minter}), "Sale running")
    await time.increase(time.duration.hours(13));  //12 hours of sale duration
    await this.presale.claimRaised({from: minter});
    const minterBalance = await this.busd.balanceOf(minter);
    assert.equal( web3.utils.fromWei(minterBalance), "100", "Dev didn't get correct funds")

  })
})