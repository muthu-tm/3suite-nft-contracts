// migrations/2_deploy_auction.js

var auctionContract = artifacts.require("ERC1155Auction");

module.exports = async function(deployer){
  // Deploy reviewer contract
  await deployer.deploy(auctionContract);
}