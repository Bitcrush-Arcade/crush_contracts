const BitcrushNiceStaking = artifacts.require("BitcrushNiceStaking");



module.exports = async function (deployer) {
    //for bitcrush
    
    await deployer.deploy(BitcrushNiceStaking, "0xAD026d8ae28bafa81030a76548efdE1EA796CB2C");
    let stakingInstance = await BitcrushNiceStaking.deployed();
    await stakingInstance.setStakingPool("0x8139cA222D38296daB88d65960Ca400dcd95b246");
    await stakingInstance.setGalacticChef("0x5867979Fe76E9604c0AEe4AE134cC0b55F65f975");
    
    
    
    //await stakingInstance.setBankroll(bankrollInstance.address);
    //await stakingInstance.setLiveWallet(liveWalletInstance.address);

    //await bankrollInstance.setLiveWallet(liveWalletInstance.address);
    //await bankrollInstance.setBitcrushStaking (stakingInstance.address);

    //await liveWalletInstance.setBitcrushBankroll(bankrollInstance.address);
   
   
   // await liveWalletInstance.setStakingPool(stakingInstance.address);

    
    
    
    /* let crush = await CRUSHToken.at("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6");
    await crush.approve(bankrollInstance.address,150000000000000000000n);
    await bankrollInstance.addToBankroll(150000000000000000000n);
    await crush.approve(stakingInstance.address,10000000000000000000000n);
    await stakingInstance.addRewardToPool(10000000000000000000000n); 
     await stakingInstance.setAutoCompoundLimit(1);
    await bankrollInstance.setProfitThreshold(100000000000000000000n); 
    await liveWalletInstance.setLockPeriod(259200);
    
    await bankrollInstance.authorizeAddress(liveWalletInstance.address); 
    */
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
