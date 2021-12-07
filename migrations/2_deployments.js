const CRUSHToken = artifacts.require('CRUSHToken');
// const BitcrushStaking = artifacts.require("BitcrushStaking");
// const Timelock = artifacts.require("Timelock");
const Lottery = artifacts.require('BitcrushLottery');

module.exports = async function ( deployer ) {
   await deployer.deploy(CRUSHToken)
   const token = await CRUSHToken.deployed()
   deployer.deploy(Lottery, token.address );
   // deployer.deploy(Lottery, "0xa3ca5df2938126baE7c0Df74D3132b5f72bdA0b6" );
   
}