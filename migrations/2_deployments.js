// const CRUSHToken = artifacts.require('CRUSHToken');
const Presale = artifacts.require("Presale")
const TestNFT = artifacts.require("TestNFT")
const StakeTest = artifacts.require("StakingTest")
const TestCoin = artifacts.require("NICEToken")
module.exports = async function ( deployer ) {
   // LOCALHOST DEPLOYMENT
   // await deployer.deploy(TestNFT, "Test God", "CG");
   // const NFT = await TestNFT.deployed()
   // await deployer.deploy( TestCoin,"Nice","NICE")
   // const Token = await TestCoin.deployed()
   // await deployer.deploy(StakeTest,Token.address)
   // const Staking  = await StakeTest.deployed();
   // await deployer.deploy(Presale, NFT.address, Staking.address, Token.address);
   // TESNET DEPLOYMENT
   // await deployer.deploy(TestNFT, "Test God", "CG");
   // const NFT = await TestNFT.deployed()
   // USED TESTNET CRUSH INSTEAD OF BUSD to test
   // await deployer.deploy(Presale, NFT.address, "0x8139cA222D38296daB88d65960Ca400dcd95b246", "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
   // MAINNET DEPLOYMENT
   await deployer.deploy(Presale, "0x712CC8EB5af53bfa063cc059839B6DB200Cc2536", "0x9D1Bc6843130fCAc8A609Bd9cb02Fb8A1E95630e", "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56");
}