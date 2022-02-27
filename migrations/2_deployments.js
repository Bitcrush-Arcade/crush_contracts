const BitcrushStaking = artifacts.require("BitcrushStaking");
const BitcrushBankroll = artifacts.require("BitcrushBankroll");
const BitcrushLiveWallet = artifacts.require("BitcrushLiveWallet");
const CRUSHToken = artifacts.require("CRUSHToken");
const BitcrushLiquidityBankroll = artifacts.require("BitcrushLiquidityBankroll");
const BitcrushTokenLiveWallet = artifacts.require("BitcrushTokenLiveWallet");
const BitcrushTestingBankroll = artifacts.require("BitcrushTestingBankroll");
module.exports = async function (deployer) {
    //for bitcrush
    let stakingInstance = await BitcrushStaking.at("0x8139cA222D38296daB88d65960Ca400dcd95b246");
    
    await deployer.deploy(BitcrushTestingBankroll, "0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89","0x8babbb98678facc7342735486c851abd7a0d17ca");
    let testingBankroll = await BitcrushTestingBankroll.deployed();
    
    await deployer.deploy(BitcrushLiquidityBankroll, "0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let bankrollInstance = await BitcrushLiquidityBankroll.deployed();
    
    await deployer.deploy(BitcrushTokenLiveWallet,"0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7" ,"0x8babbb98678facc7342735486c851abd7a0d17ca", testingBankroll.address,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89","0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3", bankrollInstance.address);
    let liveWalletInstance = await BitcrushLiveWallet.deployed();
    
    await bankrollInstance.authorizeAddress(liveWalletInstance.address);
    
    
    
    //await liveWalletInstance.setStakingPool(stakingInstance.address);

    
    
    
   /*  let crush = await CRUSHToken.at("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
    await crush.approve(bankrollInstance.address,150000000000000000000n);
    await bankrollInstance.addToBankroll(150000000000000000000n);
    await crush.approve(stakingInstance.address,10000000000000000000000n);
    await stakingInstance.addRewardToPool(10000000000000000000000n); 
    await stakingInstance.setAutoCompoundLimit(1);
    await bankrollInstance.setProfitThreshold(100000000000000000000n); 
    await liveWalletInstance.setLockPeriod(259200);
    
    await bankrollInstance.authorizeAddress(liveWalletInstance.address);  */
    //---------------------
    //for live wallet update
   /*  let stakingInstance = await BitcrushStaking.at("0x83f47386e243461AAcE9Fd60cCbdF64D8c96731E");
    let bankrollInstance = await BitcrushBankroll.at("0x88C01b6b25156727CDcDef016656b7Fd472C51Bd");

    await deployer.deploy(BitcrushLiveWallet, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6", bankrollInstance.address,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let liveWalletInstance = await BitcrushLiveWallet.deployed();
    await stakingInstance.setLiveWallet(liveWalletInstance.address);
    await bankrollInstance.setLiveWallet(liveWalletInstance.address); */
    
    //staking pool update
    /* await deployer.deploy(BitcrushStaking, "0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6",1000000000000000000n,"0x0E5De84bFC1A9799a0FdA4eF0Bd13b6A20e97d89");
    let stakingInstance = await BitcrushStaking.deployed();
    let bankrollInstance = await BitcrushBankroll.at("0x22aD94BDbBB783Ab14b6AbB220693629C1B3cA95");
    bankrollInstance.setBitcrushStaking(stakingInstance.address);
    let liveWalletInstance = await BitcrushLiveWallet.at("0xea2DdD23b80540bAE757a7a45286FF862851B178");
    await liveWalletInstance.setStakingPool(stakingInstance.address);


    stakingInstance.setBankroll("0x22aD94BDbBB783Ab14b6AbB220693629C1B3cA95");
    stakingInstance.setLiveWallet("0xea2DdD23b80540bAE757a7a45286FF862851B178");
    let crush = await CRUSHToken.at("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
    await crush.approve(stakingInstance.address,1000000000000000000000n);
    await stakingInstance.addRewardToPool(1000000000000000000000n);
    await stakingInstance.setAutoCompoundLimit(1); */
    //await stakingInstance.setCrushPerBlock(1000000000000000000n); 
};
