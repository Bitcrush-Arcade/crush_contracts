const CRUSHToken = artifacts.require('CRUSHToken');

module.exports = async function ( deployer ) {
   deployer.deploy(CRUSHToken)
}