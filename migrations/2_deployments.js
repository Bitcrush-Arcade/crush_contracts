const CRUSHToken = artifacts.require('CRUSHToken');
// const BitcrushStaking = artifacts.require("BitcrushStaking");
// const Timelock = artifacts.require("Timelock");
const Lottery = artifacts.require('BitcrushLottery');

module.exports = async function ( deployer ) {
   await deployer.deploy(CRUSHToken)
   const token = await CRUSHToken.deployed()
   deployer.deploy(Lottery, token.address );
   
}