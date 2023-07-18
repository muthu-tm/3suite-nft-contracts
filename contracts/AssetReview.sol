// contracts/AssetReview.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./IAssetReview.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AssetReview is IAssetReview, Ownable{
    address private _auctionContract;

    // Structs to hold Sale and Review Data
    struct Sale {
        // seller address
        address seller;
        uint256 timeOfSale;
    }

    struct Review {
        address seller;
        // small review text
        string review;
        // overall rating
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
    event ReviewChangedEvent(
        address assetAddress,
        address seller,
        address reviewer
    );
    event ReviewErrorEvent(string action, address reviewer);

    // Set custom events for sale changes
    event SaleChangedEvent(address assetAddress, address seller, address buyer);
    event SaleErrorEvent(string action, address buyer);

    modifier _onlyAuctionContract() {
        require(msg.sender == _auctionContract);
        _;
    }

    // Modifier to check purchase and review status
    modifier _validateAssetDetails(address _assetAddress, address _seller) {
        require(_assetAddress != address(0), "Need valid Asset address!");
        require(_seller != address(0), "Need valid Seller address!");
        _;
    }

    modifier _checkReviewStatus(address _assetAddress, address _seller) {
        require(
            CustomerPurchases[msg.sender][_assetAddress].seller == _seller,
            "You haven't purchased this item, so you can't leave a review!"
        );
        require(
            UserReviews[msg.sender][_assetAddress].seller == _seller,
            "You have already reviewed this item!"
        );
        _;
    }

    /**
     * @dev Returns the address of the Auction.
     */
    function auctionContract() public view virtual returns (address) {
        return _auctionContract;
    }

    function setAuctionContract(address _contractAddress) public onlyOwner() {
        _auctionContract = _contractAddress;
    }

    // Function called from SC to mark an user purchase
    function purchaseItem(
        address _assetAddress,
        address _seller,
        address _customer
    ) public _onlyAuctionContract {
        CustomerPurchases[_customer][_assetAddress] = Sale(
            _seller,
            block.timestamp
        );
        emit SaleChangedEvent(_assetAddress, _seller, _customer);
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
        address _assetAddress,
        address _seller
    )
        public
        _validateAssetDetails(_assetAddress, _seller)
        _checkReviewStatus(_assetAddress, _seller)
    {
        UserReviews[msg.sender][_assetAddress] = Review(
            _seller,
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

        emit ReviewChangedEvent(_assetAddress, _seller, msg.sender);
    }

    // Function for retrieving all reviews for an asset
    function getReviews(
        address nftAddress
    ) public view returns (Review[] memory) {
        return ProductReviews[nftAddress];
    }
}
