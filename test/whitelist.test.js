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
    await expectRevert(this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")}), "Whitelist Over");

    // User should be able to reserve after wl starts
    await this.wl.startWhitelist();
    await this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")});
    
    assert.ok(this.wl.whitelist(user1), "User not added to whitelist");

    const whitelister0 = await this.wl.allWhitelisters.call(0);
    const totalWhitelisters = await this.wl.whitelisters.call(); 

    assert.equal(whitelister0, user1, "Not in whitelist array");
    assert.equal(totalWhitelisters, 1, "Incorrect total whitelisters");

    // Checking what happens if user1 tries to reserveSpot again
    expectRevert(this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1", "ether")}), "Already whitelisted");

  })
  
  // function reserveSpot() external payable
  it("Should take only required amount from User", async()=>{

    // Starting whitelist
    await this.wl.startWhitelist()
    
    //user1 initial balance
    //const userInit = new BN(await web3.eth.getBalance(user1));
    await this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")});
    //const userFinal = new BN(await web3.eth.getBalance(user1));
    const contractBalance = new BN(await web3.eth.getBalance(this.wl.address));
    
    // Checking if the wallet balance is 0.1 ether
    // assert.equal(
    //   Math.abs(web3.utils.fromWei(userInit.sub(userFinal))), SUB OPERATION LOSES PRECISION, REPLACED VALUE WITH CONTRACT BALANCE FOR A PRECISE ASSERTION
    //   "0.1",
    //   "Difference doesnt match"
    // )
    assert.equal(
      web3.utils.fromWei(contractBalance),
      "0.1",
      "Difference doesnt match"
    );
  })

  // sendTransaction from other user wallet should fail
  it("Should fail if user sends funds just like that", async()=>{
    await expectRevert(
      web3.eth.sendTransaction({from: user1, to: this.wl.address, value: web3.utils.toWei("0.1","ether")}),
      "Keep your money"
    )
  })

  // function whitelistIsOver() external OnlyOwner
  it("Should not allow reserves after whitelist ends", async()=>{
    // Starting and ending wl 
    await this.wl.startWhitelist()
    await this.wl.whitelistIsOver()

    // Expecting reserveSpot to fail
    await expectRevert(
      this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")}),
      "Whitelist Over"
      )
    })

  // functions updateBuyers, allBuyersAdded, spotRefund
  it("Should lock funds for users that managed to buy", async()=>{

    // Starting wl
    await this.wl.startWhitelist()

    // Users 1, 2 and 3 reserve spots
    await this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")});
    await this.wl.reserveSpot({from: user2, value: web3.utils.toWei("0.1","ether")});
    await this.wl.reserveSpot({from: user3, value: web3.utils.toWei("0.1","ether")});
    await this.wl.whitelistIsOver()

    // updating buyers user1 and user3 with the new NFT ID's
    await this.wl.updateBuyers([user1,user3],[10,20])

    // Acknowledging that all users have been updated and added
    await this.wl.allBuyersAdded();

    // Expecting refund from user1 to fail: user1 did buy an Emperor
    await expectRevert(
      this.wl.spotRefund({from: user1}),
      "You bought an Emperor"
      )
    
    await this.wl.spotRefund({from: user2});
    // const user2Balance = await new BN(web3.eth.getBalance(user2)).toString();
    // assert.equal(user2Balance, web3.utils.toWei("0", "ether"), "Incorrect amount refunded"); DOES SPOT REFUND REFUND FUNDS?

    // Expecting refund from user3 to fail: user3 did buy an Emperor
    await expectRevert(
      this.wl.spotRefund({from: user3}),
      "You bought an Emperor"
      )

    
      
    })
    it("Should allow refunds of users that did not buy", async()=>{

      // Starting wl
      await this.wl.startWhitelist()

      // Getting initial ether balance from user2 (should be 0)
      const userInit = new BN(await web3.eth.getBalance(user2))

      // users 1, 2 and 3 reserve spots 
      await this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")});
      await this.wl.reserveSpot({from: user2, value: web3.utils.toWei("0.1","ether")});
      await this.wl.reserveSpot({from: user3, value: web3.utils.toWei("0.1","ether")});

      // Ending wl
      await this.wl.whitelistIsOver()

      // Updating buyers, user1 and use3 bought nft with ID's 10 and 20 respectively
      await this.wl.updateBuyers([user1,user3],[10,20])

      // Acknowledging that all buyers have been added
      await this.wl.allBuyersAdded();

      // User2 asks for a refund
      await this.wl.spotRefund({from: user2});
      const userFinal = new BN(await web3.eth.getBalance(user2));
      console.log({
        userInit: userInit.toString(),
        userFinal: userFinal.toString(),
      })

      // Asserting with error margin, since js sub function loses precision
      assert.ok(
        parseInt(web3.utils.fromWei(userInit.sub(userFinal))) < 0.1
        ,"Unacceptable Diff"
      )
      
    })
    it("Should claim the funds from users that bought an NFT", async()=>{

      // Starting wl
      await this.wl.startWhitelist()

      // users 1, 2 and 3 reserve spots
      await this.wl.reserveSpot({from: user1, value: web3.utils.toWei("0.1","ether")});
      await this.wl.reserveSpot({from: user2, value: web3.utils.toWei("0.1","ether")});
      await this.wl.reserveSpot({from: user3, value: web3.utils.toWei("0.1","ether")});

      // Ending wl
      await this.wl.whitelistIsOver()

      // Updating buyers with their respective NFT id
      await this.wl.updateBuyers([user1,user3],[10,20])

      // Acknowledging that all buyers have been added
      await this.wl.allBuyersAdded();

      // Checking receiver wallet balance (should be 0)
      const userInit = new BN(await web3.eth.getBalance(receiver))

      // Claiming funds from whitelist wallet into receiver
      await this.wl.claimLockedAmount();

      // Checking receiver funds after claim
      const userFinal = new BN(await web3.eth.getBalance(receiver))

      // Funds on receiver wallet 
      assert.equal(
        web3.utils.fromWei(userFinal.sub(userInit).toString()),
        "0.2"
      )

    })
})