// const CRUSHToken = artifacts.require('CRUSHToken');
// const BitcrushStaking = artifacts.require("BitcrushStaking");
// const Timelock = artifacts.require("Timelock");
const Lottery = artifacts.require('BitcrushLottery');
// const BankTest = artifacts.require('BankTest');

module.exports = async function ( deployer ) {
   // await deployer.deploy(CRUSHToken);
   // const token = await CRUSHToken.deployed();
   // await deployer.deploy( BankTest, token.address );
   // const bankInstance = await BankTest.deployed();
   // await deployer.deploy(Lottery, token.address, bankInstance.address );
   deployer.deploy(Lottery, "0xa3ca5df2938126baE7c0Df74D3132b5f72bdA0b6", "0xb40287dA5A314F6AB864498355b1FCDe6703956D" );
   
}