const { expectRevert } = require('@openzeppelin/test-helpers');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { BN, web3 } = require('@openzeppelin/test-helpers/src/setup');

const CrushToken = artifacts.require('CRUSHToken');
const Lottery = artifacts.require('BitcrushLottery');
const TestBank = artifacts.require('BankTest');

const BGN = require('bignumber.js')

BGN.BigNumber.config({ DECIMAL_PLACES: 18, ROUNDING_MODE: 1 })

contract( "LotteryTests", ([alice, bob, carol, dev, minter, partner, monkey, bull, bear, claimer]) => {
  const BgN = BGN.BigNumber
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

  const getTicketDigits = (number) => {
    const digits = standardizeNumber(number).toString().split('')
    const allDigits = []
    for( i = 1 ; i <= digits.length; i++){
      allDigits.push( digits.slice(0,i).join(''))
    }
    allDigits.shift()
    return allDigits
  }

  const numberToWei = ( number ) => {
    return web3.utils.toBN(""+number).mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) ).toString()
  }

  beforeEach(async () => {
      this.crush = await CrushToken.new({ from: minter });
      this.bonusToken = await CrushToken.new({ from: partner });
      this.bank = await TestBank.new(this.crush.address, {from: minter});
      this.lottery = await Lottery.new( this.crush.address, this.bank.address, { from: minter });
      await this.bonusToken.mint(minter, numberToWei(100000), { from: partner });
      await this.crush.mint(minter, numberToWei(3000)  , {from : minter});
      await this.crush.mint(alice, numberToWei(3000)   , {from : minter});
      await this.crush.mint(bob, numberToWei(3000)     , {from : minter});
      await this.crush.mint(carol, numberToWei(3000)   , {from : minter});
      await this.crush.mint(monkey, numberToWei(3000)   , {from : minter});
      await this.crush.mint(bull, numberToWei(3000)   , {from : minter});
      await this.crush.mint(bear, numberToWei(3000)   , {from : minter});
      await this.crush.mint(dev, numberToWei(3000)   , {from : minter});

      // await this.lottery.firstStart({ from: minter });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: minter });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: bob });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: alice });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: carol });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: monkey });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: bull });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: bear });
      await this.crush.approve( this.lottery.address, numberToWei(3000) ,{ from: dev });
      await this.lottery.addToPool( numberToWei(1000), {from: minter}  )
      
      await this.bonusToken.approve( this.lottery.address, numberToWei(1000), { from: minter})
      await this.lottery.setBonusCoin( this.bonusToken.address, numberToWei(1000), 1, 8, {from: minter})

      this.matches = {
        noMatch: new BgN(await this.lottery.noMatch.call()),
        match1: new BgN(await this.lottery.match1.call()),
        match2: new BgN(await this.lottery.match2.call()),
        match3: new BgN(await this.lottery.match3.call()),
        match4: new BgN(await this.lottery.match4.call()),
        match5: new BgN(await this.lottery.match5.call()),
        jackpot: new BgN(await this.lottery.match6.call()),
        burn: new BgN(await this.lottery.burn.call()),
        claimfee: new BgN(await this.lottery.claimFee.call()),
      }
  });

  // it("test buying tickets", async() => {
    
  //   await this.lottery.firstStart({from: minter});

  //   const ticket1 = 112233
  //   const ticketArray = new Array(100).fill(ticket1)
  //   const monkeyEthBalance = new BgN(await web3.eth.getBalance(monkey))
  //   await this.lottery.buyTickets(ticketArray.slice(0,1),0,{from: monkey});
  //   const monkeyEthAfter = new BgN(await web3.eth.getBalance(monkey))
  //   const aliceEthBalance = new BgN(await web3.eth.getBalance(alice))
  //   await this.lottery.buyTickets(ticketArray.slice(0,41),0,{from: alice});
  //   const aliceEthAfter = new BgN(await web3.eth.getBalance(alice))
  //   const bobEthBalance = new BgN(await web3.eth.getBalance(bob))
  //   await this.lottery.buyTickets(ticketArray,0,{from: bob});
  //   const bobEthAfter = new BgN(await web3.eth.getBalance(bob))
    
  //   console.log(`monkeys gas fee ${monkeyEthBalance.minus(monkeyEthAfter).div(10**18).times(600).toString()} USD`)
  //   console.log(`monkeys gas fee ${monkeyEthBalance.minus(monkeyEthAfter).div(10**18).toString()} BNB`)
  //   console.log(`alices  gas fee ${aliceEthBalance.minus(aliceEthAfter).div(10**18).times(600).toString()} USD`)
  //   console.log(`alices  gas fee ${aliceEthBalance.minus(aliceEthAfter).div(10**18).toString()} BNB`)
  //   console.log(`bobs    gas fee ${bobEthBalance.minus(bobEthAfter).div(10**18).times(600).toString()} USD`)
  //   console.log(`bobs    gas fee ${bobEthBalance.minus(bobEthAfter).div(10**18).toString()} BNB`)
  //   return true
  // })


  // it("should create a ticket", async() => {
  //   await this.lottery.firstStart({from: minter});
  //   // Standard Number requires an extra 1 in front to account for 0 values on the left
  //   const ticket1 = 112233 //NO WIN 2%
  //   const allDigits = getTicketDigits(ticket1)
  //   await this.lottery.buyTickets([ticket1],0,{from: bob});
  //   const holders = []
  //   for( i = 0; i < allDigits.length; i++){
  //     holders.push({digit: allDigits[i], holders: new BgN(await this.lottery.holders(1,allDigits[i])).toString() })
  //   }
  //   assert.equal( 6 , holders.reduce( (acc, holder) => acc + parseInt(holder.holders), 0 ), "Holders don't match")
  //   assert.equal( 1, new BgN( await this.lottery.userTotalTickets(bob)).toNumber(), "user tickets dont match")
  //   const bobRoundTickets = await this.lottery.userRoundTickets(bob,1)
  //   assert.equal( 1, new BgN( bobRoundTickets.totalTickets).toNumber(), "user ticket rounds dont match")
  //   assert.equal( new BgN( bobRoundTickets.firstTicketId).toNumber(),1, "user ticket rounds dont match")
  //   assert.equal( standardizeNumber(ticket1), new BgN( (await this.lottery.userNewTickets(bob,1)).ticketNumber).toNumber(), "user ticket rounds dont match")
  // })

  // it("should calculate the rollover", async () => {
  //   await this.lottery.firstStart({ from: minter });
  //   const ticket1 = 112233 //NO WIN 2%
  //   const ticket2 = 435566 // 1 match win 2%
  //   const ticket7 = 345567 // NO WIN
  //   const ticket3 = 345567 // NO WIN
  //   const ticket4 = 345557 // NO WIN
  //   const ticket5 = 445457 // 3 match win 5%
  //   const ticket6 = 441234 // 2 match win 3%
    
    
  //   await this.lottery.buyTickets([ticket1,ticket2], 0, { from: bob });
  //   await this.lottery.buyTickets([ticket3,ticket4], 0, { from: alice });
  //   await this.lottery.buyTickets([ticket5,ticket6,ticket7], 0, { from: carol });
  //   const bnpool = new BgN((await this.lottery.roundInfo(1)).pool)
  //   const initPool = bnpool.div(10**18)
  //   const sentWinner = 123445568
  //   // to test SETWINNER fn needs to be public
  //   await this.lottery.setWinner( sentWinner, carol,{ from: minter });
  //   const winNumber = getTicketDigits(new BgN((await this.lottery.roundInfo(1)).winnerNumber).toNumber())
  //   let winners = 0
  //   for( i = 0; i < winNumber.length; i++){
  //     const matchTest = winNumber[i]
  //     winners += new BgN(await this.lottery.holders(1,matchTest)).toNumber()
  //   }
  //   assert.equal(winners, 3, "Winners didn't match")
  //   let removedVal = new BgN(0)
  //   removedVal = removedVal.plus(initPool.times(2000).div(100000)) //2% of no match
  //   removedVal = removedVal.plus(initPool.times(2000).div(100000)) //2% of 1 match
  //   removedVal = removedVal.plus(initPool.times(3000).div(100000)) //3% of 2 match
  //   removedVal = removedVal.plus(initPool.times(5000).div(100000)) //5% of 3 match
  //   removedVal = removedVal.plus(initPool.times(18000).div(100000)) //18% of burn

  //   const rolledOver = web3.utils.fromWei((await this.lottery.roundInfo(2)).pool)
  //   const baseRollover = initPool.minus(removedVal)
  //   const distributedRollOver = baseRollover.times(10000).div(100000)
  //   // console.log( new BgN(rolledOver).toFixed(18,1), baseRollover.minus(distributedRollOver).toFixed(18,1), baseRollover.toFixed(18,1))
  //   assert.equal( new BgN(rolledOver).toString(), baseRollover.minus(distributedRollOver).toString(), "Rollover mismatch")
  //   return true
  // })

  // it("should set the winner", async() => {
  //   await this.lottery.firstStart({ from: minter });
  //   await this.lottery.buyTickets([123456,123457], 0, { from: bob });

  //   const sentWinner = 234567
  //   const comparedWinner = standardizeNumber(sentWinner)
  //   console.log( 'initBalance', (await this.crush.balanceOf(alice)).toString())
  //   await this.lottery.setWinner( sentWinner, alice,{ from: minter });
  //   console.log( 'endBalance', (await this.crush.balanceOf(alice)).toString())
  //   assert.equal( (await this.lottery.roundInfo(1)).winnerNumber.toString(), ""+comparedWinner , "winner number not set" )
  // })

  // it("first Round should only be called once", async()=>{
  //   await this.lottery.firstStart({ from: minter });
  //   // START ROUND
  //   expectRevert(this.lottery.firstStart({ from: minter }), "First Round only")
  // })
  
  // it( "should create 2 tickets for user", async () => {
  //   await this.lottery.firstStart({ from: minter });
  //   // ALLOW CONTRACT TO SPEND MY CRUSH
  //   await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });
  //   const ticket1 = 112233
  //   const ticket2 = 445566

  //   await this.lottery.buyTickets([ticket1,ticket2], 0, { from: bob });
  //   const tickets = await this.lottery.getRoundTickets(1, {from: bob});
  //   assert.equal( tickets.length, 2, "Different number of tickets" );
  //   assert.equal( tickets[0].ticketNumber, 1112233, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
  //   assert.equal( (await this.lottery.holders(1,11)).toString(), "1", "digit 11 holders differ")
  //   assert.equal( (await this.lottery.holders(1,111)).toString(), "1", "digit 111 holders differ")
  //   assert.equal( (await this.lottery.holders(1,11122)).toString(), "1", "digit 11122 holders differ")
  //   assert.equal( (await this.lottery.holders(1,111223)).toString(), "1", "digit 111223 holders differ")
  //   assert.equal( (await this.lottery.holders(1,14)).toString(), "1", "digit 14 holders differ")
  //   assert.equal( (await this.lottery.holders(1,144)).toString(), "1", "digit 144 holders differ")
  // })

  // it("should add another 3 tickets to initial tickets bought", async () => {
  //   await this.lottery.firstStart({ from: minter });
  //   // ALLOW CONTRACT TO SPEND MY CRUSH
  //   await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });

  //   await this.lottery.buyTickets([112233,445566], 0, { from: bob });
  //   await this.lottery.buyTickets([456789,987365,578153], 0, { from: bob });
  //   const tickets = await this.lottery.getRoundTickets(1, {from: bob});
  //   assert.equal( tickets.length, 5, "Different number of tickets" );
  //   assert.equal( tickets[4].ticketNumber, 1578153, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
  //   assert.equal( (await this.lottery.holders(1,14)).toString(), "2", "digit 14 holders differ")
  // })

  // it("should send 10% of ticket value to DEV", async () =>{
  //   await this.lottery.firstStart({ from: minter });
  //   const initDevBalance = new BgN(await this.crush.balanceOf(minter));
  //   // ALLOW CONTRACT TO SPEND MY CRUSH
  //   await this.lottery.buyTickets([112233,445566], 0, { from: bob });

  //   assert.equal( 
  //     new BgN( await this.crush.balanceOf(minter) ).div(10**18).toString(),
  //     initDevBalance.div(10**18).plus( 6 ).toString(),
  //     "Different Balances"
  //   )
  // } )
  // //  // PARTNERS
  // it("should be able to set the partners", async()=>{
  //   await this.lottery.editPartner(alice, 20,{from: minter})
  //   assert.equal( (await this.lottery.getProviderId(alice, {from: alice})).toString(), "1", "Alice wasn't set as first partner")
  //   await expectRevert( this.lottery.getProviderId(bob, {from: bob}), "Not a partner");
  // })
  // it("partners should get the split when buy happens on their site", async()=>{
  //   await this.lottery.editPartner(alice, 50,{from: minter})
  //   await this.lottery.firstStart({ from: minter });
  //   const ticket1 = 112233
  //   const ticket2 = 445566
  //   const aliceBalInit = parseFloat(web3.utils.fromWei(await this.crush.balanceOf.call(alice)))
  //   await this.lottery.buyTickets([ticket1,ticket2], 1, { from: bob });
  //   const aliceBal = parseFloat(web3.utils.fromWei(await this.crush.balanceOf.call(alice)))
  //   assert.equal(aliceBalInit + 1.5*2, aliceBal, "Wrong distribution");

  // })

  // it("should set the end hours time", async()=>{
  //   await this.lottery.setEndHours([10,19,21], {from: minter});
  //   const endhour0 = (await this.lottery.endHours(0)).toString();
  //   const endhour1 = (await this.lottery.endHours(1)).toString();
  //   const endhour2 = (await this.lottery.endHours(2)).toString();
  //   assert.equal(endhour0, "10", "end at 10 not done");
  //   assert.equal(endhour1, "19", "end at 19 not done");
  //   assert.equal(endhour2, "21", "end at 21 not done");

  //   await expectRevert(this.lottery.setEndHours([1,5,3], {from: minter}),"Help a brother out, sort your times first");
  //   await expectRevert(this.lottery.setEndHours([26], {from: minter}),"We all wish we had more hours per day");
  // })

  // CURRENT TIME FOR THESE TESTS IS 2021-12-07T22:24:00.000Z
  // TO TEST NEED TO COMMENT OUT THE REQUIRE STATEMENTs and requestID also edit a bit the roundEnd call
  it("should set the new Hour for same day", async () => {
    await this.lottery.setEndHours([10,19,23],{ from: minter });
    // FIRST START MUST NOT BE CALLED ON BEFOREEACH STATEMENT
    await this.lottery.firstStart({ from: minter });
    let roundEnd = await this.lottery.roundEnd.call();
    console.log( new Date( parseInt(roundEnd.toString())*1000 ) );
    assert.equal( parseInt(roundEnd.toString())*1000, new Date('2022-01-29T19:00:00.000Z').getTime(), "Times mismatch1" )
    await this.lottery.endRound();
    roundEnd = await this.lottery.roundEnd.call();
    console.log( new Date( parseInt(roundEnd.toString())*1000 ) );
    assert.equal( parseInt(roundEnd.toString())*1000, new Date('2022-01-29T23:00:00.000Z').getTime(), "Times mismatch2" )
    await this.lottery.endRound();
    roundEnd = await this.lottery.roundEnd.call();
    console.log( new Date( parseInt(roundEnd.toString())*1000 ) );
    assert.equal( parseInt(roundEnd.toString())*1000, new Date('2022-01-29T10:00:00.000Z').getTime(), "Times mismatch3" )
  })
  // it("should set the new Hour for next day", async () => {
  //   await this.lottery.setEndHours([10],{ from: minter });
  //   // FIRST START MUST NOT BE CALLED ON BEFOREEACH STATEMENT
  //   await this.lottery.firstStart({ from: minter });
  //   const roundEnd = await this.lottery.roundEnd.call();
  //   console.log( new Date( parseInt(roundEnd.toString())*1000 ) );
  //   assert.equal( parseInt(roundEnd.toString())*1000, new Date('2022-01-29T10:00:00.000Z').getTime(), "Times mismatch" )
  // })

  // it("should send the correct funds to winners", async()=>{

  //   const walletLogs = async() => {
  //     console.log([
  //       { user: 'totalTickets',
  //         balance: new BgN((await this.lottery.roundInfo(1)).totalTickets).toString(),
  //       },
  //       { user: 'claimer',
  //         balance: new BgN(await this.crush.balanceOf(claimer)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(claimer)).div(10**18).toString() 
  //       },
  //       { user: 'alice',
  //         balance: new BgN(await this.crush.balanceOf(alice)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(alice)).div(10**18).toString() 
  //       },
  //       { user: 'bob',
  //         balance: new BgN(await this.crush.balanceOf(bob)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(bob)).div(10**18).toString() 
  //       },
  //       { user: 'monkey',
  //         balance: new BgN(await this.crush.balanceOf(monkey)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(monkey)).div(10**18).toString() 
  //       },
  //       { user: 'bull',
  //         balance: new BgN(await this.crush.balanceOf(bull)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(bull)).div(10**18).toString() 
  //       },
  //       { user: 'bull',
  //         balance: new BgN(await this.crush.balanceOf(bull)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(bull)).div(10**18).toString() 
  //       },
  //       { user: 'bear',
  //         balance: new BgN(await this.crush.balanceOf(bear)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(bear)).div(10**18).toString() 
  //       },
  //       { user: 'carol',
  //         balance: new BgN(await this.crush.balanceOf(carol)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(carol)).div(10**18).toString() 
  //       },
  //       { user: 'dev',
  //         balance: new BgN(await this.crush.balanceOf(dev)).div(10**18).toString(),
  //         bonusBalance: new BgN(await this.bonusToken.balanceOf(dev)).div(10**18).toString() 
  //       },
  //     ])
  //   }

  //   // START ROUNDS
  //   await this.lottery.firstStart({ from: minter });
  //   const win0 = new Array(100).fill( standardizeNumber(0))
  //   const win1 = new Array(100).fill( standardizeNumber(112233) )
  //   const win2 = new Array(100).fill( standardizeNumber(102233) )
  //   const win3 = new Array(100).fill( standardizeNumber(100233) )
  //   const win4 = new Array(100).fill( standardizeNumber(100033) )
  //   const win5 = new Array(100).fill( standardizeNumber(100003) )
  //   const winJackpot = new Array(100).fill( standardizeNumber(100000) )

  //   await this.lottery.buyTickets( win0.slice(0,50), 0, { from: bob })
  //   await this.lottery.buyTickets( win1.slice(0,25), 0, { from: monkey })
  //   // await this.lottery.buyTickets( win1.slice(0,1), 0, { from: monkey })
  //   await this.lottery.buyTickets( win2.slice(0,25), 0, { from: bull })
  //   // await this.lottery.buyTickets( win3.slice(0,50), 0, { from: bear })
  //   // await this.lottery.buyTickets( win4.slice(0,50), 0, { from: alice })
  //   // await this.lottery.buyTickets( win5.slice(0,1), 0, { from: carol })
  //   // await this.lottery.buyTickets( winJackpot.slice(0,1), 0, { from: dev })

  //   // await walletLogs()
    
  //   const sentWinner = 100000
  //   //   // to test SETWINNER fn needs to be public
  //   const claimerInitBalance = new BgN(await this.crush.balanceOf(claimer)).div(10**18)
  //   const bobInitBalance = new BgN(await this.crush.balanceOf(bob)).div(10**18)
  //   const aliceInitBalance = new BgN(await this.crush.balanceOf(alice)).div(10**18)
  //   const monkeyInitBalance = new BgN(await this.crush.balanceOf(monkey)).div(10**18)
  //   const bullInitBalance = new BgN(await this.crush.balanceOf(bull)).div(10**18)
  //   const bearInitBalance = new BgN(await this.crush.balanceOf(bear)).div(10**18)
  //   const carolInitBalance = new BgN(await this.crush.balanceOf(carol)).div(10**18)
  //   const devInitBalance = new BgN(await this.crush.balanceOf(dev)).div(10**18)
  //   await this.lottery.setWinner( sentWinner, claimer,{ from: minter });
  //   console.log("ROUND 1",[
  //     { name: 'prevPool', value: new BgN((await this.lottery.roundInfo(1)).pool).div(10**18).toString() },
  //     { name: 'sales', value: new BgN((await this.lottery.roundInfo(1)).totalTickets).times(await this.lottery.ticketValue()).div(10**18).toString() },
  //     { name: 'bank', value: new BgN(await this.crush.balanceOf(this.bank.address)).div(10**18).toString() },
  //     { name: 'rollOver', value: new BgN((await this.lottery.roundInfo(2)).pool).div(10**18).toString() },
  //   ])
    
  //   // claimers is private for the privacy of claimers.
  //   const claimerPercent = new BgN( 600) // (await this.lottery.claimers(1)).percent)
  //   const roundTotal = new BgN((await this.lottery.roundInfo(1)).pool).div(10**18)
    
  //   // assert.equal(
  //   //   claimerPercent.times(roundTotal).div(100000).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(claimer)).div(10**18).minus(claimerInitBalance).toNumber(),
  //   //   "issue with claimer fee"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times(18).div(100).toNumber(),
  //   //   new BgN(await this.crush.tokensBurned.call()).div(10**18).toNumber(),
  //   //   "burn amount wrong"
  //   //   )
  //     // console.log([
  //     //   ['round pool', roundTotal.toString()],
  //     //   ['bob amount', new BgN(await this.crush.balanceOf(bob)).div(10**18).toString()]
  //     // ])
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 1, winners: 0}],[],[],{from: bob})
  //   // await expectRevert(this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 1, winners: 0}],[],[],{from: bob}), "Can't claim past rounds")
    
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 3}],[1,2,3],[1,1,1],{from: monkey})
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[2],{from: bull})
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[3],{from: bear})
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[4],{from: alice})
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[5],{from: carol})
  //   // await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[6],{from: dev})
  //   // // await walletLogs()
  //   // assert.equal(
  //   //   new BgN(await this.crush.balanceOf(bob)).div(10**18).minus(bobInitBalance).toNumber(),
  //   //   roundTotal.times( new BgN(2000).minus(claimerPercent).div(100000)).toNumber(),
  //   //   "issue with no Winner claim"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times( new BgN(2000).div(100000)).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(monkey)).div(10**18).minus(monkeyInitBalance).toNumber(),
  //   //   "issue with 1 match Winner claim"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times( new BgN(3000).div(100000)).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(bull)).div(10**18).minus(bullInitBalance).toNumber(),
  //   //   "issue with 2 match Winner claim"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times( new BgN(5000).div(100000)).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(bear)).div(10**18).minus(bearInitBalance).toNumber(),
  //   //   "issue with 3 match Winner claim"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times( new BgN(10000).div(100000)).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(alice)).div(10**18).minus(aliceInitBalance).toNumber(),
  //   //   "issue with 4 match Winner claim"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times( new BgN(20000).div(100000)).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(carol)).div(10**18).minus(carolInitBalance).toNumber(),
  //   //   "issue with 5 match Winner claim"
  //   // )
  //   // assert.equal(
  //   //   roundTotal.times( new BgN(40000).div(100000)).toNumber(),
  //   //   new BgN(await this.crush.balanceOf(dev)).div(10**18).minus(devInitBalance).toNumber(),
  //   //   "issue with jackpot match Winner claim"
  //   // )

  //   return true
  // })

  // it("should send the correct bonus to winners", async()=>{

  //   const walletLogs = async() => {
  //     console.log([
  //       { user: 'totalBonus', balance: new BgN(await this.bonusToken.balanceOf( this.lottery.address )).div(10**18).toString() },
  //       { user: 'claimer', balance: new BgN(await this.bonusToken.balanceOf(claimer)).div(10**18).toString() },
  //       { user: 'bob', balance: new BgN(await this.bonusToken.balanceOf(bob)).div(10**18).toString() },
  //       { user: 'monkey', balance: new BgN(await this.bonusToken.balanceOf(monkey)).div(10**18).toString() },
  //       { user: 'bull', balance: new BgN(await this.bonusToken.balanceOf(bull)).div(10**18).toString() },
  //       { user: 'bear', balance: new BgN(await this.bonusToken.balanceOf(bear)).div(10**18).toString() },
  //       { user: 'alice', balance: new BgN(await this.bonusToken.balanceOf(alice)).div(10**18).toString() },
  //       { user: 'carol', balance: new BgN(await this.bonusToken.balanceOf(carol)).div(10**18).toString() },
  //       { user: 'dev', balance: new BgN(await this.bonusToken.balanceOf(dev)).div(10**18).toString() },
  //     ])
  //   }

  //   // START ROUNDS
  //   await this.lottery.firstStart({ from: minter });
  //   const win0 = new Array(10).fill( standardizeNumber(0))
  //   const win1 = new Array(10).fill( standardizeNumber(112233) )
  //   const win2 = new Array(10).fill( standardizeNumber(102233) )
  //   const win3 = new Array(10).fill( standardizeNumber(100233) )
  //   const win4 = new Array(10).fill( standardizeNumber(100033) )
  //   const win5 = new Array(10).fill( standardizeNumber(100003) )
  //   const winJackpot = new Array(10).fill( standardizeNumber(100000) )

  //   await this.lottery.buyTickets( win0.slice(0,10), 0, { from: bob })
  //   await this.lottery.buyTickets( win1.slice(0,10), 0, { from: monkey })
  //   await this.lottery.buyTickets( win2.slice(0,5), 0, { from: bull })
  //   await this.lottery.buyTickets( win3.slice(0,4), 0, { from: bear })
  //   await this.lottery.buyTickets( win4.slice(0,2), 0, { from: alice })
  //   await this.lottery.buyTickets( win5.slice(0,1), 0, { from: carol })
  //   await this.lottery.buyTickets( winJackpot.slice(0,1), 0, { from: dev })

  //   await walletLogs()
    
  //   const sentWinner = 100000
  //   //   // to test SETWINNER fn needs to be public
  //   const claimerInitBalance = new BgN(await this.bonusToken.balanceOf(claimer)).div(10**18)
  //   await this.lottery.setWinner( sentWinner, claimer,{ from: minter });
  //   // claimers is private for the privacy of claimers.
  //   const claimerPercent = new BgN(6).times(10**8) // (await this.lottery.claimers(1)).percent)
  //   const bonusTokenInfo = await this.lottery.bonusCoins(1)
  //   const bonusTokenMax = new BgN(bonusTokenInfo.bonusMaxPercent)
  //   const roundTotal = new BgN(bonusTokenInfo.bonusAmount).div(10**18)
  //   console.log(roundTotal.toString())
  //   assert.equal(
  //     new BgN(await this.bonusToken.balanceOf(claimer)).div(10**18).minus(claimerInitBalance).toFixed(18,1), // actual
  //     claimerPercent.times(roundTotal).div(bonusTokenMax).toFixed(18,1), // expected
  //     "issue with claimer fee"
  //   )
  //   const bobEthBalance = new BgN(await web3.eth.getBalance(bob))
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 10, winners: 0}],[],[],{from: bob})
  //   const bobEthAfter = new BgN(await web3.eth.getBalance(bob))
  //   console.log('eth cost', bobEthBalance.minus(bobEthAfter).div(10**18).toString())
  //   // await expectRevert(this.lottery.claimAllPendingTickets({from: bob}), "Not owner or Ticket already claimed")
  //   const monkeyEthBalance = new BgN(await web3.eth.getBalance(monkey))
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 10}],[1,2,3,4,5,6,7,8,9,10],[1,1,1,1,1,1,1,1,1,1],{from: monkey})
  //   const monkeyEthAfter = new BgN(await web3.eth.getBalance(monkey))
  //   console.log('Monkey eth cost', monkeyEthBalance.minus(monkeyEthAfter).div(10**18).toString())
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 5}],[1,2,3,4,5],[2,2,2,2,2],{from: bull})
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 4}],[1,2,3,4],[3,3,3,3],{from: bear})
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 2}],[1,2],[4,4],{from: alice})
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[5],{from: carol})
  //   await this.lottery.claimAllPendingTickets([{roundId: 1, nonWinners: 0, winners: 1}],[1],[6],{from: dev})
  //   const roundInfo = await this.lottery.roundInfo(1)
  //   console.log(
  //     'expected',
  //     [
  //       { endPool: new BgN(await this.bonusToken.balanceOf(this.lottery.address)).div(10**18).toString()},
  //       { maxPercent: bonusTokenMax.toString()},
  //       { totalTickets: new BgN( roundInfo.totalTickets ).toString()},
  //       { claimedTickets: new BgN( roundInfo.ticketsClaimed ).toString()},
  //       { match: 0, amount:roundTotal.times( this.matches.noMatch.minus(claimerPercent).div(bonusTokenMax)).toFixed(18,1) },
  //       { match: 1, amount:roundTotal.times( this.matches.match1.div(bonusTokenMax)).toFixed(18,1) },
  //       { match: 2, amount:roundTotal.times( this.matches.match2.div(bonusTokenMax)).toFixed(18,1) },
  //       { match: 3, amount:roundTotal.times( this.matches.match3.div(bonusTokenMax)).toFixed(18,1) },
  //       { match: 4, amount:roundTotal.times( this.matches.match4.div(bonusTokenMax)).toFixed(18,1) },
  //       { match: 5, amount:roundTotal.times( this.matches.match5.div(bonusTokenMax)).toFixed(18,1) },
  //       { match: 6, amount:roundTotal.times( this.matches.jackpot.div(bonusTokenMax)).toFixed(18,1) },
  //     ]
  //   )
  //   await walletLogs()
  //   return true
  // })
  // it("should proceed with next rounds", async() => {
  //   await this.lottery.firstStart({from: minter})
  //   console.log( new Date(new BgN(await this.lottery.roundEnd.call()).toNumber()*1000) )
  //   await this.lottery.setWinner(123456, alice, {from: minter})
  //   console.log( new Date(new BgN(await this.lottery.roundEnd.call()).toNumber()*1000) )
  //   await this.lottery.setWinner(456789, alice, {from: minter})
  //   console.log( new Date(new BgN(await this.lottery.roundEnd.call()).toNumber()*1000) )
  //   const round1 = await this.lottery.roundInfo(1)
  //   const round2 = await this.lottery.roundInfo(2)
  //   const round3 = await this.lottery.roundInfo(3)
  //   const round4 = await this.lottery.roundInfo(4)
  //   console.log( web3.utils.fromWei(round1.pool), web3.utils.fromWei(round2.pool), web3.utils.fromWei(round3.pool), web3.utils.fromWei(round4.pool) )
  //   assert.equal( new BgN(await this.lottery.currentRound.call()).toNumber() , 3, "Rounds not advancing")
  // })

  // it("should set new match Values", async()=>{
  //   await this.lottery.firstStart({from: minter})
  //   const matches = {
  //     match6: new BgN(await this.lottery.match6.call()).div(1000000000).toString(),
  //     match5: new BgN(await this.lottery.match5.call()).div(1000000000).toString(),
  //     match4: new BgN(await this.lottery.match4.call()).div(1000000000).toString(),
  //     match3: new BgN(await this.lottery.match3.call()).div(1000000000).toString(),
  //     match2: new BgN(await this.lottery.match2.call()).div(1000000000).toString(),
  //     match1: new BgN(await this.lottery.match1.call()).div(1000000000).toString(),
  //     noMatch: new BgN(await this.lottery.noMatch.call()).div(1000000000).toString(),
  //     burn: new BgN(await this.lottery.burn.call()).div(1000000000).toString(),
  //   }
  //   await this.lottery.setDistributionPercentages(
  //     [4100,1800, 1100,500,300,200,200,1800],
  //     {from: minter}
  //   )
  //   await this.lottery.setWinner(456789, alice, {from: minter})
  //   const matches2 = {
  //     match6: new BgN(await this.lottery.match6.call()).div(1000000000).toString(),
  //     match5: new BgN(await this.lottery.match5.call()).div(1000000000).toString(),
  //     match4: new BgN(await this.lottery.match4.call()).div(1000000000).toString(),
  //     match3: new BgN(await this.lottery.match3.call()).div(1000000000).toString(),
  //     match2: new BgN(await this.lottery.match2.call()).div(1000000000).toString(),
  //     match1: new BgN(await this.lottery.match1.call()).div(1000000000).toString(),
  //     noMatch: new BgN(await this.lottery.noMatch.call()).div(1000000000).toString(),
  //     burn: new BgN(await this.lottery.burn.call()).div(1000000000).toString(),
  //   }
  //   const roundInfo = await this.lottery.roundInfo(2)
  //   const roundMatches = {
  //     match6: new BgN(roundInfo.match6).div(1000000000).toString(),
  //     match5: new BgN(roundInfo.match5).div(1000000000).toString(),
  //     match4: new BgN(roundInfo.match4).div(1000000000).toString(),
  //     match3: new BgN(roundInfo.match3).div(1000000000).toString(),
  //     match2: new BgN(roundInfo.match2).div(1000000000).toString(),
  //     match1: new BgN(roundInfo.match1).div(1000000000).toString(),
  //     noMatch: new BgN(roundInfo.noMatch).div(1000000000).toString(),
  //     burn: new BgN(roundInfo.burn).div(1000000000).toString(),
  //   }
  //   console.log({
  //     matches,
  //     matches2,
  //     roundMatches
  //   })
  //   return true
  // })
})
