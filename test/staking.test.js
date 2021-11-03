const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup')
const helper = require("./helpers/truffleTestHelper");
const CrushToken = artifacts.require('CRUSHToken');
const BitcrushStaking = artifacts.require('BitcrushStaking');
const BitcrushBankroll = artifacts.require('BitcrushBankroll');
const BitcrushLiveWallet = artifacts.require('BitcrushLiveWallet');

contract('Bitcrush', ([alice, bob, carol, dev ,minter]) => {
    
    const toWei = ( number ) => {
        return web3.utils.toBN(""+number).mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) )
    }
    const fromWei = ( input ) => {
        return web3.utils.fromWei( input )
    }

    const waitForBlocks = async blocksToWait => {
        for( i = 0; i< blocksToWait; i++)
            await helper.advanceTimeAndBlock(60)
    }

    beforeEach(async () => {
        this.crush = await CrushToken.new({ from: minter });
        this.staking = await BitcrushStaking.new(this.crush.address, toWei(1) ,dev, { from: minter },);
        this.bankroll = await BitcrushBankroll.new(this.crush.address,this.staking.address,dev,carol,6000,1000,200,2700, { from: minter });
        
        await this.staking.setBankroll(this.bankroll.address,{from : minter});
        this.liveWallet = await BitcrushLiveWallet.new(this.crush.address,this.bankroll.address,minter ,{ from: minter });
        await this.staking.setLiveWallet(this.liveWallet.address, {from : minter});


        await this.bankroll.setLiveWallet(this.liveWallet.address, {from : minter});
        await this.bankroll.setBitcrushStaking(this.staking.address, {from : minter});
        //await this.bankroll.addGame(6000,web3.utils.asciiToHex("DI"),1000,200,2600,100,dev, {from : minter});
        
        await this.staking.setBankroll(this.bankroll.address, {from : minter});

        await this.liveWallet.setBitcrushBankroll(this.bankroll.address, {from : minter});
        await this.liveWallet.setStakingPool(this.staking.address, {from : minter});

        await this.crush.mint(minter,10000000000000000000000n, {from : minter});
        await this.crush.mint(alice,10000000000000000000000n, {from : minter});
        await this.crush.mint(bob,10000000000000000000000n, {from : minter});
        await this.crush.mint(carol,10000000000000000000000n, {from : minter});
        await this.crush.approve(this.bankroll.address,1000000000000000000000n, {from : minter});
        await this.bankroll.addToBankroll(1000000000000000000000n, {from : minter});
        
        await this.crush.approve(this.staking.address,1000000000000000000000n, {from : minter});
        await this.staking.addRewardToPool(1000000000000000000000n, {from : minter});

        await this.staking.setAutoCompoundLimit(1, {from : minter});
        await this.bankroll.setProfitThreshold(100000000000000000000n, {from : minter});
        
        await this.crush.approve( this.staking.address, toWei(30000000), {from: alice})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: bob})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: carol})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: dev})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: minter})
    });
    it("should show correct reward amount", async()=>{
        const staked = toWei(100)
        await this.staking.enterStaking( staked ,{ from: alice})
        let aliceStakings = await this.staking.stakings(alice)
        assert.equal( staked.toString(), aliceStakings.stakedAmount.toString(), "Didn't stake correctly")
        console.log('startBlock', (await web3.eth.getBlock('latest')).number)
        await waitForBlocks(20)

        await this.staking.enterStaking( staked, {from: bob})
        let bobStakings = await this.staking.stakings(bob)
        assert.equal( bobStakings.stakedAmount.toString(), aliceStakings.stakedAmount.toString(), "Didn't stake equal amounts")
        assert.equal( fromWei(bobStakings.shares.toString()), '50', "Shares aren't calculating as supposed to" )

        await waitForBlocks(20)
        let currentBlock = (await web3.eth.getBlock('latest')).number
        let aliceReward = await this.staking.pendingReward(alice)
        let bobReward = await this.staking.pendingReward(bob)
        console.log( { 
            a: {
                reward: fromWei(aliceReward.toString()),
                last: aliceStakings.lastBlockCompounded.toString(),
                shares: fromWei(aliceStakings.shares.toString()),
                staked: fromWei(aliceStakings.stakedAmount.toString())
            },
            b: {
                reward: fromWei(bobReward.toString()),
                last: bobStakings.lastBlockCompounded.toString(),
                shares: fromWei(bobStakings.shares.toString()),
                staked: fromWei(bobStakings.stakedAmount.toString())
            },
            currentBlock,
            totalReward: fromWei(await this.staking.totalPool()),
            totalStaked: fromWei(await this.staking.totalStaked()),
        })
        await this.staking.compoundAll({from: carol})
        await waitForBlocks(1)
        currentBlock = (await web3.eth.getBlock('latest')).number
        aliceReward = await this.staking.pendingReward(alice)
        bobReward = await this.staking.pendingReward(bob)
        aliceStakings = await this.staking.stakings(alice)
        bobStakings = await this.staking.stakings(bob)
        console.log( { 
            a: {
                reward: fromWei(aliceReward.toString()),
                last: aliceStakings.lastBlockCompounded.toString(),
                shares: fromWei(aliceStakings.shares.toString()),
                staked: fromWei(aliceStakings.stakedAmount.toString())
            },
            b: {
                reward: fromWei(bobReward.toString()),
                last: bobStakings.lastBlockCompounded.toString(),
                shares: fromWei(bobStakings.shares.toString()),
                staked: fromWei(bobStakings.stakedAmount.toString())
            },
            currentBlock,
            totalReward: fromWei(await this.staking.totalPool()),
            totalStaked: fromWei(await this.staking.totalStaked()),
        })
    })
    /* it("total pool added",async () => {
        let totalPool = await this.staking.totalPool();
        console.log("total Pool is:"+totalPool);
        assert.equal(totalPool,1000000000000000000000n);
    })
    it("staking batches", async ()=>{
        await this.crush.approve(this.staking.address,100000000000000000000n,{from : alice});
        await this.staking.enterStaking(100000000000000000000n, {from : alice});
        await this.crush.approve(this.staking.address,100000000000000000000n,{from : bob});
        await this.staking.enterStaking(100000000000000000000n, {from : bob});
        await this.crush.approve(this.staking.address,100000000000000000000n,{from : carol});
        await this.staking.enterStaking(100000000000000000000n, {from : carol});
        await this.crush.approve(this.liveWallet.address,1000000000000000000000n,{from : alice});
        await this.liveWallet.addbet(1000000000000000000000n, {from : alice});
        await this.liveWallet.registerLoss([200000000000000000000n],[alice],{from : minter});
        //await time.advanceBlockTo((await web3.eth.getBlock("latest")).number+10);

        console.log("bounty after compound:"+(await this.crush.balanceOf(minter)).toString());
        console.log("Batch starting index is:"+(await this.staking.batchStartingIndex()).toString());
        console.log("Alice staked amount is:" + (await this.staking.stakings(alice)).stakedAmount.toString());
        await this.staking.compoundAll({from : minter});
        console.log("Alice staked amount is:" + (await this.staking.stakings(alice)).stakedAmount.toString());
        console.log("profit to be distributed is:"+(await this.staking.profits(0)).total.toString())
        console.log("bounty after compound:"+(await this.crush.balanceOf(minter)).toString());

        console.log("Batch starting index is:"+(await this.staking.batchStartingIndex()).toString());
        console.log("Bob staked amount is:" + (await this.staking.stakings(bob)).stakedAmount.toString());
        await this.staking.compoundAll({from : minter});
        console.log("Bob staked amount is:" + (await this.staking.stakings(bob)).stakedAmount.toString());
        console.log("bounty after compound:"+(await this.crush.balanceOf(minter)).toString());

        console.log("Batch starting index is:"+(await this.staking.batchStartingIndex()).toString());
        console.log("Carol staked amount is:" + (await this.staking.stakings(carol)).stakedAmount.toString());
        await this.staking.compoundAll({from : minter});
        console.log("Carol staked amount is:" + (await this.staking.stakings(carol)).stakedAmount.toString());
        console.log("bounty after compound:"+(await this.crush.balanceOf(minter)).toString());
        console.log("Batch starting index is:"+(await this.staking.batchStartingIndex()).toString());

        console.log("profit remaining is:"+(await this.staking.profits(0)).remaining.toString());
        
        //await this.staking.setEarlyWithdrawFeeTime(5,{from : alice})
    }) */
    // it("Black list test",async () => {
    //     await this.liveWallet.blacklistSelf({from : carol});
    //     await this.liveWallet.whitelistUser(carol,{from : minter});
    //     await this.crush.approve(this.liveWallet.address,1000000000000000000000n,{from : carol});
    //     await this.liveWallet.addbet(1000000000000000000000n, {from : carol});

    // })
   /*  it("register win",async () => {
        await this.crush.approve(this.liveWallet.address,100,{from : bob});
        await this.liveWallet.addbet(100,1,{from : bob});
        await this.liveWallet.registerLoss([1],[20],[bob],{from : minter});
        let balance = await this.liveWallet.balanceOf(1,bob);
        console.log("balance on win is:"+balance);

    })

    it("emergency withdraw", async()=>{
        await this.crush.approve(this.staking.address,500,{from : alice});
        await this.staking.enterStaking(500, {from : alice});
        assert((await this.crush.balanceOf(alice)).toString(),"9500");
        await time.advanceBlockTo((await web3.eth.getBlock("latest")).number+10);
        await this.staking.emergencyWithdraw();
        assert((await this.crush.balanceOf(alice)).toString(),"10000");
    });

    it("auto compound reward calculation", async()=>{
        console.log("current block is:"+(await web3.eth.getBlock("latest")).number);
        console.log("crush per block is:"+(await this.staking.crushPerBlock()).toString());
        await this.crush.approve(this.staking.address,500,{from : alice});
        await this.staking.enterStaking(500, {from : alice});
        await time.advanceBlockTo((await web3.eth.getBlock("latest")).number+10);
        assert.equal((parseInt(await this.staking.crushPerBlock()).toString())* (10),((parseInt(await this.staking.totalPendingRewards()).toString())));
        console.log("Test 1 Total Pending reward:"+ (await this.staking.totalPendingRewards()).toString());
        console.log("Batch starting index is:"+(await this.staking.batchStartingIndex()).toString());
        //testing fee calculation
        await this.staking.compoundAll({from : bob});
        //balance should be 10000 + 0.1% of 100 so 10000.1
        console.log("Balance of bob is: "+(await this.crush.balanceOf(bob)).toString());
        //burn should be 1
        //reserve should be 1.9
        assert((await this.crush.balanceOf(bob)).toString(),'10000.1');
        assert((await this.crush.balanceOf(dev)).toString(),'1.9');
        console.log("crush burned is:"+(await this.crush.tokensBurned()).toString());
        console.log((await this.crush.balanceOf(dev)).toString());
        


    });

    it("add staking/withdraw without early fee", async () =>{
        console.log("total Pool is:"+(await this.staking.totalPool()));
        console.log("total staked in without:"+(await this.staking.totalStaked()).toString());
        await this.crush.approve(this.staking.address,500,{from : alice});
        await this.staking.enterStaking(500, {from : alice});
        console.log("staked amount after staking is:"+await this.staking.totalStaked());
        assert.equal((await this.staking.totalStaked()).toString(),'500');
        assert.equal((await this.crush.balanceOf(alice)).toString(),'9500');
        await this.staking.setEarlyWithdrawFeeTime(10,{from : minter});
        console.log("current block is:"+(await web3.eth.getBlock("latest")).number);
        await time.advanceBlockTo((await web3.eth.getBlock("latest")).number+10);
        console.log("staked amount is:"+(await this.staking.stakings(alice)).stakedAmount);
        console.log("pending amount is:"+(await this.staking.pendingReward(alice,{from : alice})), {from : alice});

        console.log("users last block compounded is:"+ (await this.staking.stakings(alice)).lastBlockCompounded);
        
        console.log("cake per block is:"+ (await this.staking.crushPerBlock()).toString());
        console.log("amount being withdrawn is"+ (await this.staking.stakings(alice)).stakedAmount + (await this.staking.pendingReward(alice,{from : alice})));
        console.log("pending amount is:"+(await this.staking.pendingReward(alice,{from : alice})), {from : alice});
        console.log("current block is:"+(await web3.eth.getBlock("latest")).number);
        await this.staking.leaveStaking(parseInt((await this.staking.stakings(alice)).stakedAmount) , {from : alice});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        console.log("current block is:"+(await web3.eth.getBlock("latest")).number);
        
        
        assert.equal((await this.staking.totalStaked()).toString(),'0');
        
        assert.equal((await this.crush.balanceOf(dev)).toString(),'0');
    })

    it("add staking/withdraw with early fee", async () =>{
        console.log("total Pool is:"+(await this.staking.totalPool()));
        await this.crush.approve(this.staking.address,500,{from : alice});
        await this.staking.enterStaking(500, {from : alice});
        console.log("staked amount after staking is:"+await this.staking.totalStaked());
        assert.equal((await this.staking.totalStaked()).toString(),'500');
        assert.equal((await this.crush.balanceOf(alice)).toString(),'9500');
        await this.staking.leaveStaking((await this.staking.stakings(alice)).stakedAmount, {from : alice});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        
        assert.equal((await this.staking.totalStaked()).toString(),'0');
        
        assert.equal((await this.crush.balanceOf(dev)).toString(),'2');
    })
   
    it("stake then harvest and withdraw without early fee", async () =>{
        console.log("total Pool is:"+(await this.staking.totalPool()));
        console.log("total staked in compound without fee:"+(await this.staking.totalStaked()).toString());
        await this.crush.approve(this.staking.address,500,{from : bob});
        await this.staking.enterStaking(500, {from : bob});
        console.log("staked amount after staking is:"+await this.staking.totalStaked());
        assert.equal((await this.staking.totalStaked()).toString(),'500');
        assert.equal((await this.crush.balanceOf(bob)).toString(),'9500');
        await this.staking.setEarlyWithdrawFeeTime(10,{from : minter});
        console.log("current block is:"+(await web3.eth.getBlock("latest")).number);
        await time.advanceBlockTo((await web3.eth.getBlock("latest")).number+10);
        
        await this.staking.claim({from : bob});
        await this.staking.leaveStaking(500, {from : bob});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        console.log("staking mapping:"+ JSON.stringify(await this.staking.stakings(bob)));
        console.log("balance of bob:"+(await this.crush.balanceOf(bob)));
        
        assert.equal((await this.staking.totalStaked()).toString(),'0');
        
        assert.equal((await this.crush.balanceOf(dev)).toString(),'0');
    })

    it("stake compoundall then harvest without early fee", async () =>{
        console.log("total Pool is:"+(await this.staking.totalPool()));
        console.log("total staked in compound all without fee:"+(await this.staking.totalStaked()).toString());
        await this.crush.approve(this.staking.address,500,{from : carol});
        await this.staking.enterStaking(500, {from : carol});
        console.log("staked amount after staking is:"+await this.staking.totalStaked());
        assert.equal((await this.staking.totalStaked()).toString(),'500');
        assert.equal((await this.crush.balanceOf(carol)).toString(),'9500');
        await this.staking.setEarlyWithdrawFeeTime(10,{from : minter});
        console.log("current block is:"+(await web3.eth.getBlock("latest")).number);
        await time.advanceBlockTo((await web3.eth.getBlock("latest")).number+10);
        await this.staking.compoundAll({from : carol});
        
        await this.staking.leaveStaking(500, {from : carol});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        console.log("staking mapping:"+ JSON.stringify(await this.staking.stakings(carol)));
        
        
        assert.equal((await this.staking.totalStaked()).toString(),((await this.staking.stakings(carol)).stakedAmount));
        
        assert.equal((await this.crush.balanceOf(dev)).toString(),'2');
        console.log("burned tokens are:"+(await this.crush.tokensBurned()));
        await this.staking.emergencyTotalPoolWithdraw({from : minter});
        assert.equal((await this.staking.totalPool()).toString(),'0');
        console.log("total staked :"+(await this.staking.totalStaked()).toString());
        console.log("total staked :"+(await this.staking.totalPool()).toString());
    })

   

    it("test only owner", async () =>{
        await expectRevert(this.staking.setEarlyWithdrawFeeTime(5,{from : alice}),'Ownable: caller is not the owner');
    })

    it("emergency withdraw owner", async () =>{
        await this.staking.emergencyTotalPoolWithdraw({from : minter});
        assert.equal((await this.staking.totalPool()).toString(),'0');
    })

 */
});