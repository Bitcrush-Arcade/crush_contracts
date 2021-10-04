const BitcrushStaking = artifacts.require("BitcrushStaking");
const BitcrushBankroll = artifacts.require("BitcrushBankroll");
const BitcrushLiveWallet = artifacts.require("BitcrushLiveWallet");
const CRUSHToken = artifacts.require("CRUSHToken");


module.exports = async function (deployer) {
    //for bitcrush
    //deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",500000000000000000n,"0x49B7c429C7B45656580143653C5438862266469f");
    await deployer.deploy(CRUSHToken);
    let crushInstance = await CRUSHToken.deployed();

     await deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",10,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let stakingInstance = await BitcrushStaking.deployed();
    
    await deployer.deploy(BitcrushBankroll, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6", stakingInstance.address, "0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89", "0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89", 6000,1000,200,2700 );
    let bankrollInstance = await BitcrushBankroll.deployed();
    
    await deployer.deploy(BitcrushLiveWallet, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6", bankrollInstance.address,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let liveWalletInstance = await BitcrushLiveWallet.deployed();
    
    await stakingInstance.setBankroll(bankrollInstance.address);
    await stakingInstance.setLiveWallet(liveWalletInstance.address);

    await bankrollInstance.setLiveWallet(liveWalletInstance.address);
    await bankrollInstance.setBitcrushStaking (stakingInstance.address);

    await liveWalletInstance.setBitcrushBankroll(bankrollInstance.address);
    await liveWalletInstance.setStakingPool(stakingInstance.address);

    
    //await bankrollInstance.addGame(6000,web3.utils.asciiToHex("DI"),1000,200,2600,100,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    
     /* let crush = await CRUSHToken.at("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
    await crush.approve(bankrollInstance.address,150000000000000000000n);
    await bankrollInstance.addToBankroll(150000000000000000000n);
    await crush.approve(stakingInstance.address,100000000000000000000n);
    await stakingInstance.addRewardToPool(100000000000000000000n); 
    await staking.setAutoCompoundLimit(1);
    await bankrollInstance.setProfitThreshold(100); */

    //---------------------
    //for live wallet update
   /*  let stakingInstance = await BitcrushStaking.at("0x83f47386e243461AAcE9Fd60cCbdF64D8c96731E");
    let bankrollInstance = await BitcrushBankroll.at("0x88C01b6b25156727CDcDef016656b7Fd472C51Bd");

    await deployer.deploy(BitcrushLiveWallet, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6", bankrollInstance.address,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let liveWalletInstance = await BitcrushLiveWallet.deployed();
    await stakingInstance.setLiveWallet(liveWalletInstance.address);
    await bankrollInstance.setLiveWallet(liveWalletInstance.address); */
    
    //staking pool update
/*await deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",10,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let stakingInstance = await BitcrushStaking.deployed();
    let bankrollInstance = await BitcrushBankroll.at("0xAB9de4ca854952213B577912BF798595EB018c23");
    bankrollInstance.setBitcrushStaking(stakingInstance.address);
    stakingInstance.setBankroll("0xAB9de4ca854952213B577912BF798595EB018c23");
    stakingInstance.setLiveWallet("0x7a1636a10017e1d8bC89dcFaf4c187295723E812");
    let crush = await CRUSHToken.at("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
    await crush.approve(stakingInstance.address,1000000000000000000000n);
    await stakingInstance.addRewardToPool(1000000000000000000000n);
    */
};
