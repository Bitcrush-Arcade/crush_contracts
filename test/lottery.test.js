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

      await this.lottery.startRound({ from: minter });
      await this.lottery.addToPool( numberToWei(1000), from  )
  });


  

  // it("should set the winner", async() => {
  //   const sentWinner = 234567
  //   const comparedWinner = standardizeNumber(sentWinner)
  //   await this.lottery.setWinner( sentWinner,{ from: minter });
  //   assert.equal( (await this.lottery.winnerNumbers(1)).toString(), ""+comparedWinner , "winner number not set" )
  // })


  // it("should start the next Round", async()=>{
  //   // START ROUND
  //   await this.lottery.startRound({ from: minter });
  //   assert.equal( await this.lottery.currentIsActive(), true, "Round didn't start");
  // })
  
  // it( "should create 2 tickets for user", async () => {
  //   // ALLOW CONTRACT TO SPEND MY CRUSH
  //   await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });
  //   const ticket1 = 112233
  //   const ticket2 = 445566
  //   const standard1 = standardizeNumber(ticket1)
  //   const standard2 = standardizeNumber(ticket2)

  //   await this.lottery.buyTickets([ticket1,ticket2], { from: bob });
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
  //   // ALLOW CONTRACT TO SPEND MY CRUSH
  //   await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });

  //   await this.lottery.buyTickets([112233,445566], { from: bob });
  //   await this.lottery.buyTickets([456789,987365,578153], { from: bob });
  //   const tickets = await this.lottery.getRoundTickets(1, {from: bob});
  //   assert.equal( tickets.length, 5, "Different number of tickets" );
  //   assert.equal( tickets[4].ticketNumber, 1578153, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
  //   assert.equal( (await this.lottery.holders(1,14)).toString(), "2", "digit 14 holders differ")
  // })

  // it("should send 10% of ticket value to DEV", async () =>{
  //   const initDevBalance = await this.crush.balanceOf.call(minter);
  //   // ALLOW CONTRACT TO SPEND MY CRUSH
  //   await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });
  //   await this.lottery.buyTickets([112233,445566], { from: bob });

  //   assert.equal( 
  //     web3.utils.fromWei( await this.crush.balanceOf.call(minter) ),
  //     web3.utils.fromWei( initDevBalance.add( web3.utils.toBN('6000000000000000000') ) ),
  //     "Different Balances"
  //   )
  // } )


})