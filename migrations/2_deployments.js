const NiceBEP20 = artifacts.require('NICEToken');
const NiceERC20 = artifacts.require('NiceToken');
const WrappedCrush = artifacts.require('CrushErc20');
const InvaderverseBridge = artifacts.require('InvaderverseBridge');

module.exports = async function ( deployer ) {
  await deployer.deploy(InvaderverseBridge);
  await deployer.deploy(WrappedCrush, "Crush Fantom", "CRUSH");
  await deployer.deploy(NiceTokenBEP20,"Nice Invaders Crush Everything", "NICE");
  await deployer.deploy(NiceTokenERC20,"Nice Invaders Crush Everything", "NICE");
}