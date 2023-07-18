// migrations/2_deploy_auction.js

var auctionContract = artifacts.require("ERC1155Auction");
var reviewContract = artifacts.require("AssetReview");

module.exports = async function(deployer){
  // Deploy reviewer contract
  await deployer.deploy(reviewContract);
  const review_instance = await reviewContract.deployed();

  // Deploy auction contract
  await deployer.deploy(auctionContract, review_instance.address);
  const auction_instance = await auctionContract.deployed();
  
  // set auction contract address in reviewer contract
  reviewContract.setAuctionContract(auction_instance.address)
}