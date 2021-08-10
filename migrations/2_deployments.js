const BitcrushStaking = artifacts.require("BitcrushStaking");
const BitcrushBankroll = artifacts.require("BitcrushBankroll");
const BitcrushLiveWallet = artifacts.require("BitcrushLiveWallet");
const CRUSHToken = artifacts.require("CRUSHToken");
const web3 = require("web3");
module.exports = async function (deployer) {
    //for bitcrush
    //deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",500000000000000000n,"0x49B7c429C7B45656580143653C5438862266469f");
    //for local testing
    await deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",10,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let stakingInstance = await BitcrushStaking.deployed();
    console.log(stakingInstance.address);
    await deployer.deploy(BitcrushBankroll, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6", stakingInstance.address, "0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89", "0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89" );
    let bankrollInstance = await BitcrushBankroll.deployed();
    console.log(bankrollInstance.address);
    await deployer.deploy(BitcrushLiveWallet, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6", bankrollInstance.address);
    let liveWalletInstance = await BitcrushLiveWallet.deployed();
    await stakingInstance.setBankroll(bankrollInstance.address);
    await stakingInstance.setLiveWallet(liveWalletInstance.address);
    await bankrollInstance.setLiveWallet(liveWalletInstance.address);
    console.log("byte32 represtnation is: "+web3.utils.asciiToHex("DI"));
    await bankrollInstance.addGame(6000,web3.utils.asciiToHex("DI"),1000,200,2700,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let crush = await CRUSHToken.at("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
    await crush.approve(bankrollInstance.address,500000000000000000n);
    await bankrollInstance.addToBankroll(500000000000000000n);

};
