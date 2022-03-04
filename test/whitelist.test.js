const { BN, expectRevert, expectEvent, time } = require("@openzeppelin/test-helpers");
const { assertion } = require("@openzeppelin/test-helpers/src/expectRevert");
const { web3 } = require('@openzeppelin/test-helpers/src/setup');


const NftWhitelist = artifacts.require('NftWhitelist')

contract("NFTWhitelist",([minter, user1, user2,user3, user4, receiver]) => {
  beforeEach(async() =>{
    const wl = await NftWhitelist.new();
  })

  // function startWhitelist() external OnlyOwner
  it("Should start the whitelist", async()=>{
    // Checking if wlStarted is 0 by default
    assert.ok(!this.wl.wlStart(), "Whitelist should not start yet");

    // Starting wl 
    await this.wl.startWhitelist({from: minter});
    assert.ok(this.wl.wlStart(), "Whitelist not started properly");

  })

  // function setRequiredAmount(uint _newRequired) external OnlyOwner
  it("Should set Required Amount only before wlStarts", async()=>{})

  // function reserveSpot() external payable
  it("Should not allow reserve before wlStarts", async()=>{})

  // 
  it("Should take only required amount from User", async()=>{})
  it("Should fail if user sends funds just like that", async()=>{})
  it("Should not allow reserves after whitelist ends", async()=>{})
  it("Should lock funds for users that managed to buy", async()=>{})
  it("Should allow refunds of users that did not buy", async()=>{})
  it("Should claim the funds from users that bought an NFT", async()=>{})
})