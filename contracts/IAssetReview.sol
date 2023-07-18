// contracts/IAssetReview.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAssetReview {
    function purchaseItem(
        address _assetAddress,
        address _seller,
        uint16 _type,
        address _customer
    ) external;

    function addReview(
        string memory _review,
        uint16 _overall,
        uint16 _assetQuality,
        uint16 _asExpected,
        uint256 _docsQuality,
        uint256 _sellerSupport,
        address _assetAddress,
        address _seller
    ) external;
}