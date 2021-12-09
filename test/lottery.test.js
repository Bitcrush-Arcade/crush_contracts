const { expectRevert } = require('@openzeppelin/test-helpers');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { BN } = require('@openzeppelin/test-helpers/src/setup');

const CrushToken = artifacts.require('CRUSHToken');
const Lottery = artifacts.require('BitcrushLottery');

contract( "LotteryTests", ([alice, bob, carol, dev, minter]) => {
  const WINNERBASE = 1000000
  const MAXBASE =    2000000

  const standardizeNumber = ( number ) => {
    if( number <= WINNERBASE)
      return number + WINNERBASE
    else if( number >= MAXBASE)
      return (number % WINNERBASE) + WINNERBASE
    else
      return number
  }

  const numberToWei = ( number ) => {
    return web3.utils.toBN(""+number).mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) )
  }

  beforeEach(async () => {
      this.crush = await CrushToken.new({ from: minter });
      this.lottery = await Lottery.new( this.crush.address, { from: minter });
      await this.crush.mint(minter, numberToWei(3000)  , {from : minter});
      await this.crush.mint(alice, numberToWei(3000)   , {from : minter});
      await this.crush.mint(bob, numberToWei(3000)     , {from : minter});
      await this.crush.mint(carol, numberToWei(3000)   , {from : minter});

      // await this.lottery.firstStart({ from: minter });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: minter });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: bob });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: alice });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: carol });
  
      await this.lottery.addToPool( numberToWei(1000), {from: minter}  )
  });

  it("should give the appropriate winner match value", async () => {
    await this.lottery.firstStart({ from: minter });
    const sentWinner = 445568
    // SET WINNER NEEDS TO BE PUBLIC FOR THIS TEST TO PASS
    await this.lottery.setWinner( sentWinner, alice,{ from: minter });
    const { _winner, _match } = await this.lottery.isNumberWinner(1, 123456)
    const { _winner: win1, _match: match1 } = await this.lottery.isNumberWinner(1, 433333)
    const { _winner: win2, _match: match2 } = await this.lottery.isNumberWinner(1, 443333)
    const { _winner: win3, _match: match3 } = await this.lottery.isNumberWinner(1, 445333)
    const { _winner: win4, _match: match4 } = await this.lottery.isNumberWinner(1, 445555)
    const { _winner: win5, _match: match5 } = await this.lottery.isNumberWinner(1, 445565)
    const { _winner: win6, _match: match6 } = await this.lottery.isNumberWinner(1, 2445568)
    assert.equal( _winner, false, "Shouldn't have been a winner")
    assert.equal( win1, true, "1 Should have been a winner")
    assert.equal( win2, true, "2 Should have been a winner")
    assert.equal( win3, true, "3 Should have been a winner")
    assert.equal( win4, true, "4 Should have been a winner")
    assert.equal( win5, true, "5 Should have been a winner")
    assert.equal( win6, true, "6 Should have been a winner")
    assert.equal( _match.toString(), "0", "0 Didn't match same amount")
    assert.equal( match1.toString(), "1", "1 Didn't match same amount")
    assert.equal( match2.toString(), "2", "2 Didn't match same amount")
    assert.equal( match3.toString(), "3", "3 Didn't match same amount")
    assert.equal( match4.toString(), "4", "4 Didn't match same amount")
    assert.equal( match5.toString(), "5", "5 Didn't match same amount")
    assert.equal( match6.toString(), "6", "6 Didn't match same amount")
  })

  it("should calculate the rollover", async () => {
    await this.lottery.firstStart({ from: minter });
    const ticket1 = 112233 //NO WIN 2%
    const ticket2 = 435566 // 1 match win 2%
    const ticket7 = 345567 // NO WIN
    const ticket3 = 345567 // NO WIN
    const ticket4 = 345557 // NO WIN
    const ticket5 = 445457 // 3 match win 5%
    const ticket6 = 441234 // 2 match win 3%
    
    
    await this.lottery.buyTickets([ticket1,ticket2], 0, { from: bob });
    await this.lottery.buyTickets([ticket3,ticket4], 0, { from: alice });
    await this.lottery.buyTickets([ticket5,ticket6,ticket7], 0, { from: carol });
    const bnpool = new BN((await this.lottery.roundPool(1)).toString())
    const initPool = web3.utils.fromWei(bnpool)
    const sentWinner = 445568
    // to test SETWINNER fn needs to be public
    await this.lottery.setWinner( sentWinner, carol,{ from: minter });
    const removedVal = parseInt(initPool)*2000/100000+parseInt(initPool)*2000/100000+parseInt(initPool)*5000/100000+parseInt(initPool)*3000/100000+parseInt(initPool)*18000/100000
    const rolledOver = web3.utils.fromWei((await this.lottery.roundPool(2)))
    assert.equal(rolledOver, "" + (parseFloat(initPool)-removedVal), "different rolledOver value")
    return true
  })

  it("should set the winner", async() => {
    await this.lottery.firstStart({ from: minter });
    const sentWinner = 234567
    const comparedWinner = standardizeNumber(sentWinner)
    console.log( 'initBalance', (await this.crush.balanceOf(alice)).toString())
    await this.lottery.setWinner( sentWinner, alice,{ from: minter });
    console.log( 'endBalance', (await this.crush.balanceOf(alice)).toString())
    assert.equal( (await this.lottery.winnerNumbers(1)).toString(), ""+comparedWinner , "winner number not set" )
  })


  it("first Round should only be called once", async()=>{
    await this.lottery.firstStart({ from: minter });
    // START ROUND
    expectRevert(this.lottery.firstStart({ from: minter }), "First Round only")
  })
  
  it( "should create 2 tickets for user", async () => {
    await this.lottery.firstStart({ from: minter });
    // ALLOW CONTRACT TO SPEND MY CRUSH
    await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });
    const ticket1 = 112233
    const ticket2 = 445566

    await this.lottery.buyTickets([ticket1,ticket2], 0, { from: bob });
    const tickets = await this.lottery.getRoundTickets(1, {from: bob});
    assert.equal( tickets.length, 2, "Different number of tickets" );
    assert.equal( tickets[0].ticketNumber, 1112233, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
    assert.equal( (await this.lottery.holders(1,11)).toString(), "1", "digit 11 holders differ")
    assert.equal( (await this.lottery.holders(1,111)).toString(), "1", "digit 111 holders differ")
    assert.equal( (await this.lottery.holders(1,11122)).toString(), "1", "digit 11122 holders differ")
    assert.equal( (await this.lottery.holders(1,111223)).toString(), "1", "digit 111223 holders differ")
    assert.equal( (await this.lottery.holders(1,14)).toString(), "1", "digit 14 holders differ")
    assert.equal( (await this.lottery.holders(1,144)).toString(), "1", "digit 144 holders differ")
  })

  it("should add another 3 tickets to initial tickets bought", async () => {
    await this.lottery.firstStart({ from: minter });
    // ALLOW CONTRACT TO SPEND MY CRUSH
    await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });

    await this.lottery.buyTickets([112233,445566], 0, { from: bob });
    await this.lottery.buyTickets([456789,987365,578153], 0, { from: bob });
    const tickets = await this.lottery.getRoundTickets(1, {from: bob});
    assert.equal( tickets.length, 5, "Different number of tickets" );
    assert.equal( tickets[4].ticketNumber, 1578153, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
    assert.equal( (await this.lottery.holders(1,14)).toString(), "2", "digit 14 holders differ")
  })

  it("should send 10% of ticket value to DEV", async () =>{
    await this.lottery.firstStart({ from: minter });
    const initDevBalance = await this.crush.balanceOf.call(minter);
    // ALLOW CONTRACT TO SPEND MY CRUSH
    await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });
    await this.lottery.buyTickets([112233,445566], 0, { from: bob });

    assert.equal( 
      web3.utils.fromWei( await this.crush.balanceOf.call(minter) ),
      web3.utils.fromWei( initDevBalance.add( web3.utils.toBN('6000000000000000000') ) ),
      "Different Balances"
    )
  } )
   // PARTNERS
  it("should be able to set the partners", async()=>{
    await this.lottery.editPartner(alice, 20,{from: minter})
    assert.equal( (await this.lottery.getProviderId(alice, {from: alice})).toString(), "1", "Alice wasn't set as first partner")
    await expectRevert( this.lottery.getProviderId(bob, {from: bob}), "Not a partner");
  })
  it("partners should get the split when buy happens on their site", async()=>{
    await this.lottery.editPartner(alice, 50,{from: minter})
    await this.lottery.firstStart({ from: minter });
    const ticket1 = 112233
    const ticket2 = 445566
    const aliceBalInit = parseFloat(web3.utils.fromWei(await this.crush.balanceOf.call(alice)))
    await this.lottery.buyTickets([ticket1,ticket2], 1, { from: bob });
    const aliceBal = parseFloat(web3.utils.fromWei(await this.crush.balanceOf.call(alice)))
    assert.equal(aliceBalInit + 1.5*2, aliceBal, "Wrong distribution");

  })

  it("should set the end hours time", async()=>{
    await this.lottery.setEndHours([10,19,21], {from: minter});
    const endhour0 = (await this.lottery.endHours(0)).toString();
    const endhour1 = (await this.lottery.endHours(1)).toString();
    const endhour2 = (await this.lottery.endHours(2)).toString();
    assert.equal(endhour0, "10", "end at 10 not done");
    assert.equal(endhour1, "19", "end at 19 not done");
    assert.equal(endhour2, "21", "end at 21 not done");

    await expectRevert(this.lottery.setEndHours([1,5,3], {from: minter}),"Help a brother out, sort your times first");
    await expectRevert(this.lottery.setEndHours([26], {from: minter}),"We all wish we had more hours per day");
  })

  //CURRENT TIME FOR THESE TESTS IS 22:24PM UTC
  it("should set the new Hour for same day", async () => {
    await this.lottery.setEndHours([10,19,23],{ from: minter });
    // FIRST START MUST NOT BE CALLED ON BEFOREEACH STATEMENT
    await this.lottery.firstStart({ from: minter });
    const roundEnd = await this.lottery.roundEnd.call();
    console.log( new Date( parseInt(roundEnd.toString())*1000 ) );
    assert.equal( parseInt(roundEnd.toString())*1000, new Date('2021-12-07T23:00:00.000Z').getTime(), "Times mismatch" )
  })
  it("should set the new Hour for next day", async () => {
    await this.lottery.setEndHours([10],{ from: minter });
    // FIRST START MUST NOT BE CALLED ON BEFOREEACH STATEMENT
    await this.lottery.firstStart({ from: minter });
    const roundEnd = await this.lottery.roundEnd.call();
    console.log( new Date( parseInt(roundEnd.toString())*1000 ) );
    assert.equal( parseInt(roundEnd.toString())*1000, new Date('2021-12-08T10:00:00.000Z').getTime(), "Times mismatch" )
  })
})