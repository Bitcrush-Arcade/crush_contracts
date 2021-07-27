const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const CrushToken = artifacts.require('CRUSHToken');
const BitcrushStaking = artifacts.require('BitcrushStaking');
const BitcrushBankroll = artifacts.require('BitcrushBankroll');
const BitcrushLiveWallet = artifacts.require('BitcrushLiveWallet');

contract('MasterChef', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.crush = await CrushToken.new({ from: minter });
        this.staking = await BitcrushStaking.new(this.crush.address,10,dev, { from: minter },);
        this.bankroll = await BitcrushBankroll.new(this.crush.address,this.staking.address,dev,carol, { from: minter });
        this.staking.setBankroll(this.bankroll.address);
        this.liveWallet = await BitcrushLiveWallet.new(this.crush.address,this.bankroll.address, { from: minter });
        await this.bankroll.setLiveWallet(this.liveWallet.address);
        await this.crush.mint(minter,10000, {from : minter});
        await this.crush.mint(alice,10000, {from : minter});
        await this.crush.mint(bob,10000, {from : minter});
        await this.crush.mint(carol,10000, {from : minter});
        await this.crush.approve(this.staking.address,1000, {from : minter});
        await this.staking.addRewardToPool(1000, {from : minter});
        
    });
    it("total pool added",async () => {
        let totalPool = await this.staking.totalPool();
        console.log("total Pool is:"+totalPool);
        assert.equal(totalPool,1000);
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


});