// migrations/2_deploy_auction.js

var auctionContract = artifacts.require("ERC1155Auction");

module.exports = function(deployer){
  deployer.deploy(auctionContract);
}