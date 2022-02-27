const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup')
const helper = require("./helpers/truffleTestHelper");
const CrushToken = artifacts.require('CRUSHToken');
const BitcrushStaking = artifacts.require('BitcrushStaking');
const BitcrushBankroll = artifacts.require('BitcrushBankroll');
const BitcrushLiveWallet = artifacts.require('BitcrushLiveWallet');
const BitcrushNiceStaking = artifacts.require("BitcrushNiceStaking");
contract('Bitcrush', ([alice, bob, carol, robert, dev ,minter, tom, terry, jerry]) => {
    
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

    const logSection = text => {
        console.log('-------------------------')
        console.log(text)
        console.log('-------------------------')
    }

    beforeEach(async () => {
        this.crush = await CrushToken.new({ from: minter });
        this.staking = await BitcrushStaking.new(this.crush.address, toWei(1) ,dev, { from: minter },);
        this.bankroll = await BitcrushBankroll.new(this.crush.address,this.staking.address,dev,carol,6000,1000,200,2700,minter, { from: minter });
        this.niceStaking = await BitcrushNiceStaking.new(this.crush.address, { from: minter });
        await this.niceStaking.setStakingPool(this.staking.address, { from: minter });
        await this.staking.setBankroll(this.bankroll.address,{from : minter});
        this.liveWallet = await BitcrushLiveWallet.new(this.crush.address,this.bankroll.address,minter ,{ from: minter });
        await this.staking.setLiveWallet(this.liveWallet.address, {from : minter});



        // await this.bankroll.setLiveWallet(this.liveWallet.address, {from : minter});
        // await this.bankroll.setBitcrushStaking(this.staking.address, {from : minter});
        await this.bankroll.authorizeAddress(this.liveWallet.address,{from: minter})
        //await this.bankroll.addGame(6000,web3.utils.asciiToHex("DI"),1000,200,2600,100,dev, {from : minter});
        
        // await this.staking.setBankroll(this.bankroll.address, {from : minter});

        // await this.liveWallet.setBitcrushBankroll(this.bankroll.address, {from : minter});
        await this.liveWallet.setStakingPool(this.staking.address, {from : minter});

        await this.crush.mint(minter, toWei(1000000), {from : minter});
        await this.crush.mint(alice, toWei(10000), {from : minter});
        await this.crush.mint(bob, toWei(10000), {from : minter});
        await this.crush.mint(robert, toWei(10000), {from : minter});
        await this.crush.mint(carol, toWei(10000), {from : minter});
        await this.crush.mint(tom, toWei(10000), {from : minter});
        await this.crush.mint(terry, toWei(10000), {from : minter});
        await this.crush.mint(jerry, toWei(10000), {from : minter});
        await this.crush.approve(this.bankroll.address, toWei(30000000), {from : minter});
        await this.bankroll.addToBankroll( toWei(150), {from : minter});

        // APPROVE LIVE WALLET AND ADD FUNDS FROM CAROL
        await this.crush.approve( this.liveWallet.address, toWei(30000000), {from: carol});
        await this.liveWallet.addbet( toWei(500),{ from: carol} );
        
        await this.crush.approve(this.staking.address, toWei(30000000), {from : minter});
        await this.staking.addRewardToPool( toWei(20), {from : minter});

        await this.staking.setAutoCompoundLimit(3, {from : minter});
        await this.bankroll.setProfitThreshold( toWei(100), {from : minter});
        
        await this.crush.approve( this.staking.address, toWei(30000000), {from: alice})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: bob})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: carol})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: dev})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: robert})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: minter})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: tom})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: terry})
        await this.crush.approve( this.staking.address, toWei(30000000), {from: jerry})

        this.logStakes = async() => {
            let aliceStakings = await this.staking.stakings(alice)
            let bobStakings = await this.staking.stakings(bob)
            let carolStakings = await this.staking.stakings(carol)
            let tomStakings = await this.staking.stakings(tom)
            let terryStakings = await this.staking.stakings(terry)
            let jerryStakings = await this.staking.stakings(jerry)
            let currentBlock = (await web3.eth.getBlock('latest')).number
            
            let aliceReward = await this.staking.pendingReward(alice)
            let bobReward = await this.staking.pendingReward(bob)
            let tomReward = await this.staking.pendingReward(tom)
            let carolReward = await this.staking.pendingReward(carol)
            let terryReward = await this.staking.pendingReward(terry)
            let jerryReward = await this.staking.pendingReward(jerry)

            let aliceNiceReward = await this.niceStaking.niceRewards(alice)
            let bobNiceReward = await this.niceStaking.niceRewards(bob)
            let tomNiceReward = await this.niceStaking.niceRewards(tom)
            let carolNiceReward = await this.niceStaking.niceRewards(carol)
            let terryNiceReward = await this.niceStaking.niceRewards(terry)
            let jerryNiceReward = await this.niceStaking.niceRewards(jerry)


            let pool = fromWei(await this.staking.totalPool())
            let indexes = []
            try{ indexes.push(await this.staking.addressIndexes(0))}catch { indexes.push("-")}
            try{ indexes.push(await this.staking.addressIndexes(1))}catch { indexes.push("-")}
            try{ indexes.push(await this.staking.addressIndexes(2))}catch { indexes.push("-")}
            let profits = fromWei( await this.staking.accProfitPerShare() )
            console.log( { 
                currentBlock,
                // bankProfit : fromWei( await this.bankroll.brSinceCompound() ),
                // bankThreshold : fromWei( await this.bankroll.profitThreshold() ),
                compoundIndex: (await this.staking.batchStartingIndex()).toString(),
                pool,
                a: {
                    reward: fromWei(aliceReward.toString()),
                    staked: fromWei(aliceStakings.stakedAmount.toString()),
                    niceReward : fromWei(aliceNiceReward.toString()),
                },
                b: {
                    reward: fromWei(bobReward.toString()),
                    staked: fromWei(bobStakings.stakedAmount.toString()),
                    niceReward : fromWei(bobNiceReward.toString()),
                },
                c: {
                    reward: fromWei(tomReward.toString()),
                    staked: fromWei(tomStakings.stakedAmount.toString()),
                    niceReward : fromWei(tomNiceReward.toString()),
                },
                d: {
                    reward: fromWei(terryReward.toString()),
                    staked: fromWei(terryStakings.stakedAmount.toString()),
                    niceReward : fromWei(terryNiceReward.toString()),
                },
                e: {
                    reward: fromWei(jerryReward.toString()),
                    staked: fromWei(jerryStakings.stakedAmount.toString()),
                    niceReward : fromWei(jerryNiceReward.toString()),
                },
                f: {
                    reward: fromWei(carolReward.toString()),
                    staked: fromWei(carolStakings.stakedAmount.toString()),
                    niceReward : fromWei(carolNiceReward.toString()),
                },
                // // totalBankroll: fromWei( await this.bankroll.totalBankroll()),
                // stakingProfits: profits,
                // totalStaked: fromWei(await this.staking.totalStaked()),
                // frozen: fromWei( await this.staking.totalFrozen()),
            })
        }
    });
    // it("should show correct reward amount", async()=>{
    //     const staked = toWei(100)
    //     await this.staking.enterStaking( staked ,{ from: alice})
    //     // assert.equal( staked.toString(), aliceStakings.stakedAmount.toString(), "Didn't stake correctly")
    //     logSection('start')
    //     console.log('startBlock', (await web3.eth.getBlock('latest')).number)
    //     await waitForBlocks(20)
    //     await this.logStakes()

    //     // add profits and compound for ALICE
    //     await this.liveWallet.registerLoss([toWei(150)],[carol],{ from: minter })
    //     logSection("CAROL LOST")
    //     await waitForBlocks(40)
    //     await this.logStakes()
        
    //     await this.staking.compoundAll({from: carol})
    //     logSection("COMPOUNDED")
    //     await waitForBlocks(2)
    //     await this.logStakes()

    //     await this.staking.enterStaking( staked, {from: bob})
    //     logSection("BOB entered")
    //     await waitForBlocks(20)
    //     await this.logStakes()

    //     await this.staking.compoundAll({from: carol})
    //     logSection("COMPOUNDED")
    //     await waitForBlocks(2)
    //     await this.logStakes()

    //     /**
    //      * @DEV CAROL LOSES 100
    //      * BEFORE COMPOUND BOB WITHDRAWS 50% OF HIS BALANCE
    //      * COMPOUND ALL
    //      * 
    //      */

    //     await this.liveWallet.registerLoss([toWei(100)],[carol],{ from: minter })
    //     logSection("CAROL Loses")
    //     await waitForBlocks(5)
    //     await this.logStakes()
        
    //     const bobStakes1 = fromWei((await this.staking.stakings(bob)).stakedAmount)
    //     await this.staking.leaveStaking( toWei( parseFloat(bobStakes1)/2 ), false, {from: bob})
    //     logSection("BOB withdraws 50%")
    //     await waitForBlocks(10)
    //     await this.logStakes()

    //     await this.staking.compoundAll({from: carol})
    //     logSection("COMPOUNDED")
    //     await waitForBlocks(10)
    //     await this.logStakes()
    // })

    /**
     * @DEV CAROL WINS 250
     * BOB DEPOSITS
     * ALICE WITHDRAWS
     * COMPOUND ALL
     * ROBERT JOINS POOL
     * CAROL LOSES 300
     * wait X blocks
     * COMPOUND ALL
     * WAIT BLOCKS
     * ALICE COMPLETELY WITHDRAWS
     * WAIT BLOCKS
     */

    it("Check of multiple scenarios", async()=>{
        const staked = toWei(200)
        await this.staking.enterStaking( staked ,{ from: alice})
        await this.staking.enterStaking( staked ,{ from: bob })
        await this.staking.enterStaking( staked ,{ from: tom })
        await this.staking.enterStaking( staked ,{ from: terry })
        await this.staking.enterStaking( staked ,{ from: jerry })
        await this.staking.enterStaking( staked ,{ from: carol })
        logSection('start')
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()
        logSection('compound1')
        await this.niceStaking.compoundAll({from: carol})
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()
        logSection('compound2')
        await this.niceStaking.compoundAll({from: carol})
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()
        logSection('compound3')
        await this.niceStaking.compoundAll({from: carol})
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()
        logSection('compound4')
        await this.niceStaking.compoundAll({from: carol})
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()
        logSection('compound5')
        await this.niceStaking.compoundAll({from: carol})
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()
        logSection('compound6')
        await this.niceStaking.compoundAll({from: carol})
        await this.logStakes()
        await waitForBlocks(10)
        await this.logStakes()


        // await this.liveWallet.registerWin( [toWei(250)], [carol], {from: minter})
        // logSection('Carol won 250')

        // await this.staking.leaveStaking( toWei(100), false,{from: alice} )
        // logSection('Alice will Withdraw')
        // await this.logStakes()

        // await this.staking.compoundAll({from: carol})
        // logSection("COMPOUNDED")
        // await this.logStakes()

        // await this.staking.enterStaking( staked ,{ from: robert})
        // logSection('Robert gets added')
        // await this.logStakes()

        // await this.liveWallet.registerLoss( [toWei(500)], [carol], {from: minter})
        // logSection('Carol lost 500')
        // await this.logStakes()

        // await waitForBlocks(100)
        // logSection('wait for 100 blocks')
        // await this.logStakes()

        // await this.staking.compoundAll({from: carol})
        // logSection("COMPOUNDED")
        // await this.logStakes()

        // await waitForBlocks(100)
        // logSection('wait for 100 blocks')
        // await this.logStakes()

        // const aliceStaked1 = await this.staking.stakings(alice)
        // await this.staking.leaveStaking( aliceStaked1.stakedAmount, false,{from: alice})
        // logSection('Alice completely left pool')
        // await this.logStakes()

        // await this.staking.compoundAll({from: carol})
        // logSection("COMPOUNDED")
        // await this.logStakes()

        // await this.liveWallet.registerLoss( [toWei(100)], [carol], {from: minter})
        // logSection('Carol lost 500')
        // await this.logStakes()

        // await this.staking.compoundAll({from: carol})
        // logSection("COMPOUNDED")
        // await this.logStakes()

        // await waitForBlocks(100)
        // logSection('wait for 100 blocks')
        // await this.logStakes()

    })

    /**
     * MAKE FUNDS FROZEN
     * SOMEONE DEPOSITS
     * WAIT 2 BLOCKS
     * THAT SOMEONE WITHDRAWS EVERYTHING
     * EXPECTED TO FAIL
     */
    // it("Should not allow a full withdraw with things frozen", async() =>{
    //     const staked = toWei(200)

    //     await this.staking.enterStaking( staked ,{ from: alice})
    //     await this.staking.enterStaking( staked ,{ from: bob })
    //     logSection('start')
    //     await this.logStakes()

    //     await this.liveWallet.registerWin( [toWei(250)], [carol], {from: minter})
    //     logSection('Carol won 250')
    //     await this.logStakes()

    //     await this.staking.enterStaking( staked, {from: robert})
    //     logSection('Robert Entered Staking')
    //     await this.logStakes()

    //     await waitForBlocks(2)
    //     logSection('Robert wants to Leave')
    //     await this.logStakes()

    //     const weiAlice = (await this.staking.stakings(alice)).stakedAmount
    //     const aliceStaked = fromWei(weiAlice)
    //     const aliceFrozen = parseFloat( aliceStaked )*parseFloat(fromWei(await this.staking.totalFrozen()))/ parseFloat( fromWei(await this.staking.totalStaked()) )
    //     const availableStaked = parseFloat(aliceStaked) - aliceFrozen
    //     console.log(aliceFrozen, aliceStaked, availableStaked, availableStaked > 200)
    //     assert.equal( aliceFrozen, 200*100/600, "Frozen amounts don't match" );
        
    //     const weirobert = (await this.staking.stakings(robert)).stakedAmount
    //     const robertStaked = fromWei(weirobert)
    //     const robertFrozen = parseFloat( robertStaked )*parseFloat(fromWei(await this.staking.totalFrozen()))/ parseFloat( fromWei(await this.staking.totalStaked()) )
    //     const robAvail = parseFloat(robertStaked) - robertFrozen
    //     console.log(robertFrozen, robertStaked, robAvail, robAvail > 200)
    //     assert.equal( robertFrozen, 200*100/600, "Frozen amounts don't match" );
    //     await this.staking.leaveStaking(weirobert,false,{from: robert})
    //     await this.staking.leaveStaking(weiAlice,false,{from: alice})
    // })
    
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