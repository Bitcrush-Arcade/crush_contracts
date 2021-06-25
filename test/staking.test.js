const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const CrushToken = artifacts.require('CRUSHToken');
const BitcrushStaking = artifacts.require('BitcrushStaking');

contract('MasterChef', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.crush = await CrushToken.new({ from: minter });
        this.staking = await BitcrushStaking.new(this.crush.address,10,dev, { from: minter });
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
    it("add staking/withdraw with early fee", async () =>{
        console.log("total Pool is:"+(await this.staking.totalPool()));
        await this.crush.approve(this.staking.address,500,{from : alice});
        await this.staking.enterStaking(500, {from : alice});
        console.log("staked amount after staking is:"+await this.staking.totalStaked());
        assert.equal((await this.staking.totalStaked()).toString(),'500');
        assert.equal((await this.crush.balanceOf(alice)).toString(),'9500');
        await this.staking.leaveStaking(500, {from : alice});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        //because compound is added and called before leave staking so total staked has base crush per block added
        assert.equal((await this.staking.totalStaked()).toString(),'10');
        //2.5 calculated but since cast to uint hence rounded down to 2
        assert.equal((await this.crush.balanceOf(dev)).toString(),'2');
    })
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
        await this.staking.leaveStaking(500, {from : alice});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        //because compound is added and called before leave staking so total staked has base crush per block added
        //advancing 10 blocks at 10 per block and accounting for blocks by previous executions
        assert.equal((await this.staking.totalStaked()).toString(),'120');
        //balance should remain unchanged since no fee was deducted 
        assert.equal((await this.crush.balanceOf(dev)).toString(),'0');
    })

    it("stake compound then harvest without early fee", async () =>{
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
        await this.staking.singleCompound({from : bob});
        await this.staking.claim({from : bob});
        await this.staking.leaveStaking(500, {from : bob});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        console.log("staking mapping:"+ JSON.stringify(await this.staking.stakings(bob)));
        
        //because compound is added and called before leave staking so total staked has base crush per block added
        //advancing 10 blocks at 10 per block and accounting for blocks by previous executions
        assert.equal((await this.staking.totalStaked()).toString(),'10');
        //balance should remain unchanged since no fee was deducted 
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
        await this.staking.claim({from : carol});
        await this.staking.leaveStaking(500, {from : carol});
        console.log("staked amount after withdrawal is:"+await this.staking.totalStaked());
        console.log("staking mapping:"+ JSON.stringify(await this.staking.stakings(carol)));
        
        //because compound is added and called before leave staking so total staked has base crush per block added
        //advancing 10 blocks at 10 per block and accounting for blocks by previous executions
        assert.equal((await this.staking.totalStaked()).toString(),'10');
        //balance should remain unchanged since no fee was deducted 
        assert.equal((await this.crush.balanceOf(dev)).toString(),'2');
        console.log("burned tokens are:"+(await this.crush.tokensBurned()));
    })
    it("test only owner", async () =>{
        await expectRevert(this.staking.setEarlyWithdrawFeeTime(5,{from : alice}),'Ownable: caller is not the owner');
    })

});