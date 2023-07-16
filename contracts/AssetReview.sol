// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

pragma solidity 0.8.19;

contract AssetReview is Context, Ownable {
    
    // Structs to hold Sale and Review Data
    struct Sale {
        uint16 saletype;
        uint256 timeOfSale;
    }

    struct Review {
        string review;
        uint16 overall;
        uint16 assetQuality;
        uint16 asExpected;
        uint256 docsQuality;
        uint256 sellerSupport;
        uint256 timeOfReview;
    }

    // Tie each Sale and Review to customer mapping
    mapping(address => mapping(address => Sale)) internal CustomerPurchases;
    mapping(address => mapping(address => Review)) internal UserReviews;

    // Store all reviews in array against asset address for easy retrieval
    mapping(address => Review[]) internal ProductReviews;

    // Set custom events for review changes
    event ReviewChangedEvent(address assetAddress, address reviewer);
    event ReviewErrorEvent(string action, address reviewer);

    // Set custom events for sale changes
    event SaleChangedEvent(address assetAddress, address buyer);
    event SaleErrorEvent(string action, address buyer);

    // Modifier to check purchase and review status
    modifier checkPurchaseAndReviewStatus(address _assetAddress) {
        require(
            CustomerPurchases[msg.sender][_assetAddress].timeOfSale != 0,
            "You haven't purchased this item, so you can't leave a review!"
        );
        require(
            UserReviews[msg.sender][_assetAddress].timeOfReview != 0,
            "You have already reviewed this item!"
        );
        _;
    }

    // Function called from SC to mark an user purchase
    function purchaseItem(
        address _assetAddress,
        uint16 _type,
        address _customer
    ) public onlyOwner {
        CustomerPurchases[_customer][_assetAddress] = Sale(
            _type,
            block.timestamp
        );
        emit SaleChangedEvent(_assetAddress, _customer);
    }

    // Function called from SC to undo an user purchase
    function undoPurchase(
        address _assetAddress,
        address _customer
    ) public onlyOwner {
        require(
            CustomerPurchases[_customer][_assetAddress].timeOfSale != 0,
            "You haven't purchased this item so you can't leave a review: "
        );

        CustomerPurchases[msg.sender][_assetAddress] = Sale(0, 0);
    }

    // Function to get user purchase details
    function getCustomerPurchase(
        address _assetAddress
    ) public view returns (Sale memory) {
        return CustomerPurchases[msg.sender][_assetAddress];
    }

    // Function to get user reviews
    function getUserReview(
        address _assetAddress
    ) public view returns (Review memory) {
        return UserReviews[msg.sender][_assetAddress];
    }

    // Function that allows user to add review only if they have purchased the item
    function addReview(
        string calldata _review,
        uint16 _overall,
        uint16 _assetQuality,
        uint16 _asExpected,
        uint256 _docsQuality,
        uint256 _sellerSupport,
        address _assetAddress
    ) public checkPurchaseAndReviewStatus(_assetAddress) {
        UserReviews[msg.sender][_assetAddress] = Review(
            _review,
            _overall,
            _assetQuality,
            _asExpected,
            _docsQuality,
            _sellerSupport,
            block.timestamp
        );
        ProductReviews[_assetAddress].push(
            UserReviews[msg.sender][_assetAddress]
        );

        emit ReviewChangedEvent(_assetAddress, msg.sender);
    }

    // Function for retrieving all reviews for an asset
    function getReviews(
        address nftAddress
    ) public view returns (Review[] memory) {
        return ProductReviews[nftAddress];
    }
}
