// const CRUSHToken = artifacts.require('CRUSHToken');
const Presale = artifacts.require("Presale")
const TestNFT = artifacts.require("TestNFT")
const StakeTest = artifacts.require("StakingTest")
const TestCoin = artifacts.require("NICEToken")
module.exports = async function ( deployer ) {
   await deployer.deploy(TestNFT, "Test God", "CG");
   const NFT = await TestNFT.deployed()
   await deployer.deploy( TestCoin,"Nice","NICE")
   const Token = await TestCoin.deployed()
   await deployer.deploy(StakeTest,Token.address)
   const Staking  = await StakeTest.deployed();
   await deployer.deploy(Presale, NFT.address, Staking.address, Token.address);
}