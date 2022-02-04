// const CRUSHToken = artifacts.require('CRUSHToken');
const Presale = artifacts.require("Presale")
const TestNFT = artifacts.require("TestNFT")
module.exports = async function ( deployer ) {
   await deployer.deploy(TestNFT, "Test God", "CG");
   const NFT = await TestNFT.deployed()
   await deployer.deploy(Presale, NFT.address);
}