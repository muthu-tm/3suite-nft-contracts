// migrations/1_deploy_factory.js

var factoryContract = artifacts.require("FactoryERC1155");

module.exports = function(deployer){
  deployer.deploy(factoryContract);
}