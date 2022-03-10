//const CRUSHToken = artifacts.require('CRUSHToken');
//const BitcrushStaking = artifacts.require("BitcrushStaking");
//const Timelock = artifacts.require("Timelock");
const NftWhitelist = artifacts.require("NftWhitelist")
module.exports = async function (deployer)
{
   //deployer.deploy(CRUSHToken)
   //deployer.deploy(BitcrushStaking, "0x0Ef0626736c2d484A792508e99949736D0AF807e",570000000000000000n,"0xADdb2B59d1B782e8392Ee03d7E2cEaA240e7f1c0", "0x6dc3dB7a7adCE1EdBE58778E9595990bf0FC3913");
   deployer.deploy(NftWhitelist, "0xADdb2B59d1B782e8392Ee03d7E2cEaA240e7f1c0")
}