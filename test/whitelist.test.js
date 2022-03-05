const { BN, expectRevert, expectEvent, time } = require("@openzeppelin/test-helpers");
const ether = require("@openzeppelin/test-helpers/src/ether");
const { assertion } = require("@openzeppelin/test-helpers/src/expectRevert");
const { web3 } = require('@openzeppelin/test-helpers/src/setup');


const NftWhitelist = artifacts.require('NftWhitelist')

contract("NFTWhitelist",([minter, user1, user2,user3, user4, receiver]) => {
  beforeEach(async() =>{
    this.wl = await NftWhitelist.new(receiver);
  })

  // function startWhitelist() external OnlyOwner
  it("Should start the whitelist", async()=>{
    // Checking if wlStarted is false by default
    const started = await this.wl.wlStart.call();
    assert.ok(!started, "Whitelist should not start yet");

    // Starting wl 
    await this.wl.startWhitelist();
    assert.ok(this.wl.wlStart.call(), "Whitelist not started properly");

    // Checking what happens if it has started already
    await expectRevert(this.wl.startWhitelist(), "Whitelist started")

  })

  // function setRequiredAmount(uint _newRequired) external OnlyOwner
  it("Should set Required Amount only before wlStarts", async()=>{
    // Checking initial value of requiredAmount
    const initialRequired = new BN(await this.wl.requiredAmount.call()).toString();
    assert.equal(initialRequired, web3.utils.toWei("0.1", 'ether'), "Initial required amount");

    // Checking that the required amount can be changed before wl starts
    await this.wl.setRequiredAmount(web3.utils.toBN(web3.utils.toWei("0.2", 'ether')));
    const editedRequired = new BN(await this.wl.requiredAmount.call()).toString();
    assert.equal(editedRequired, web3.utils.toWei("0.2", 'ether'), "Initial required amount");

    // Checking if setRequiredAmount fails after wl starts
    await this.wl.startWhitelist();
    await expectRevert(this.wl.setRequiredAmount(web3.utils.toBN(web3.utils.toWei("0.2", 'ether'))), "not a giveaway");

    // Checking if the required amount was not changed after wl starts
    await assert.equal(initialRequired, web3.utils.toWei("0.1", 'ether'), "Initial required amount");

  })

  // function reserveSpot() external payable
  it("Should not allow reserve before wlStarts", async()=>{

    // reserveSpot() should fail before wl starts
    await expectRevert(this.wl.reserveSpot({from: user1}), "Whitelist Over");

    // User should be able to reserve after wl starts
    await this.wl.startWhitelist();
    await this.wl.reserveSpot({from: user1});

    assert.ok(this.wl.whitelist[user1].call(), "User not added to whitelist");
    assert.equal(this.wl.allWhitelisters[0].call(), user1, "Not in list");
    assert.equal(this.wl.whitelisters, 1, "Incorrect total whitelisters");

  })
  
  it("Should take only required amount from User", async()=>{})
  it("Should fail if user sends funds just like that", async()=>{})
  it("Should not allow reserves after whitelist ends", async()=>{})
  it("Should lock funds for users that managed to buy", async()=>{})
  it("Should allow refunds of users that did not buy", async()=>{})
  it("Should claim the funds from users that bought an NFT", async()=>{})
})