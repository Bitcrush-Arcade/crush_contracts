const { expectRevert } = require('@openzeppelin/test-helpers');
const { assertion } = require('@openzeppelin/test-helpers/src/expectRevert');
const { BN } = require('@openzeppelin/test-helpers/src/setup');

const Coin = artifacts.require('Coin');
const Lottery = artifacts.require('BitcrushLottery');

contract( "LotteryTests", ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {
      this.crush = await Coin.new({ from: minter });
      this.lottery = await Lottery.new( this.crush.address, { from: minter });
      await this.crush.mint(minter, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) )  , {from : minter});
      await this.crush.mint(alice, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) ) , {from : minter});
      await this.crush.mint(bob, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) ) , {from : minter});
      await this.crush.mint(carol, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18') ) ) , {from : minter});
  });

  it("should start the next Round", async()=>{
    // START ROUND
    await this.lottery.startRound({ from: minter });
    assert.equal( await this.lottery.currentIsActive(), true, "Round didn't start");
  })
  
  it( "should create 2 tickets for user", async () => {
    // START ROUND
    await this.lottery.startRound({ from: minter });
    // ALLOW CONTRACT TO SPEND MY CRUSH
    await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });

    await this.lottery.buyTickets([112233,445566], { from: bob });
    const tickets = await this.lottery.getRoundTickets(1, {from: bob});
    assert.equal( tickets.length, 2, "Different number of tickets" );
    assert.equal( tickets[0].ticketNumber, 1112233, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
  })

  it("should add another 3 tickets to initial tickets bought", async () => {
    // START ROUND
    await this.lottery.startRound({ from: minter });
    // ALLOW CONTRACT TO SPEND MY CRUSH
    await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });

    await this.lottery.buyTickets([112233,445566], { from: bob });
    await this.lottery.buyTickets([456789,987365,578153], { from: bob });
    const tickets = await this.lottery.getRoundTickets(1, {from: bob});
    assert.equal( tickets.length, 5, "Different number of tickets" );
    assert.equal( tickets[4].ticketNumber, 1578153, "Ticket Number Mismatch"); //"NOTE THAT TICKET NUMBER HAS AN EXTRA 1 at the start"
  })

  it("should send 10% of ticket value to DEV", async () =>{
    // START ROUND
    await this.lottery.startRound({ from: minter });
    const initDevBalance = await this.crush.balanceOf.call(minter);
    // ALLOW CONTRACT TO SPEND MY CRUSH
    await this.crush.approve( this.lottery.address, web3.utils.toBN('3000').mul( web3.utils.toBN('10').pow( web3.utils.toBN('18'))) ,{ from: bob });
    await this.lottery.buyTickets([112233,445566], { from: bob });

    assert.equal( 
      web3.utils.fromWei( await this.crush.balanceOf.call(minter) ),
      web3.utils.fromWei( initDevBalance.add( web3.utils.toBN('6000000000000000000') ) ),
      "Different Balances"
    )
  } )
})