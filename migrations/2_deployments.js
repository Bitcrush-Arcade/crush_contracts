const NiceToken = artifacts.require('NiceTokenBep20');
const InvaderverseBridge = artifacts.require('InvaderverseBridge');

module.exports = async function ( deployer ) {
   await deployer.deploy(NiceToken, deployer.address);
   await deployer.deploy(InvaderverseBridge, deployer.address, deployer.address);
}