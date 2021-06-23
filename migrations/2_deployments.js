const CRUSHToken = artifacts.require('CRUSHToken');
const BitcrushStaking = artifacts.require("BitcrushStaking");
module.exports = async function ( deployer ) {
   //deployer.deploy(CRUSHToken)
   deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",10,"0x49B7c429C7B45656580143653C5438862266469f");
   
}