const NiceBEP20 = artifacts.require('NICEToken');
const NiceERC20 = artifacts.require('NiceTokenFtm');
const WrappedCrush = artifacts.require('CrushErc20');
//const InvaderverseBridge = artifacts.require('InvaderverseBridge');

module.exports = async function ( deployer ) {
  //await deployer.deploy(InvaderverseBridge);
  //await deployer.deploy(NiceBEP20,"Nice Invaders Crush Everything", "NICE");
  await deployer.deploy(NiceERC20,"Nice Invaders Crush Everything", "NICE");
  await deployer.deploy(WrappedCrush, "Crush", "CRUSH");
}
