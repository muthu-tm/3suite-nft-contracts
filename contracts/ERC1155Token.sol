// contracts/ERC1155Token.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ERC1155Token is ERC1155, Ownable {
    string[] public names; //string array of names
    uint[] public ids; //uint array of ids
    string public baseMetadataURI; //the token metadata URI
    string public name; //the token mame
    uint public mintFee = 0 wei; //mintfee, 0 by default. only used in mint function, not batch.

    // mapping(string => uint) public nameToId; //name to id mapping
    // mapping(uint => string) public idToName; //id to name mapping

    mapping(uint => SellList) public sales;
    uint256 public salesId;

    mapping(uint => mapping(uint => OfferData)) public offerInfo;
    mapping(uint => uint) public offerCount;

    mapping(address => uint) public escrowAmount;

    mapping(uint => AuctionData) public auction;
    uint256 public auctionId;

    /// @notice This is the Sell struct, the basic structures contain the owner of the selling tokens.
    struct SellList {
        address seller;
        address token;
        uint256 tokenId;
        uint256 amountOfToken;
        uint256 deadline;
        uint256 price;
        SaleStatus state;
    }

    struct OfferData {
        address offerAddress;
        uint256 offerPrice;
        bool isAccepted;
    }

    struct AuctionData {
        address creator;
        address token;
        address highestBidder;
        uint256 tokenId;
        uint256 amountOfToken;
        uint256 highestBid;
        uint256 startPrice;
        uint256 minIncrement;
        uint256 startDate;
        uint256 duration;
        Auction auction;
    }

    enum SaleStatus {
        STARTED,
        SOLD,
        CANCELED
    }
    enum Auction {
        RESERVED,
        STARTED,
        COMPLETED
    }

    /// @notice This is the emitted event, when a offer for a certain amount of tokens.
    event SellEvent(
        address _seller,
        address _token,
        uint256 _offerId,
        uint256 _tokenId,
        uint256 _amount
    );

    /// @notice This is the emitted event, when a sell is canceled.
    event CanceledSell(
        address _seller,
        address _token,
        uint256 _tokenId,
        uint256 _amountOfToken
    );

    /// @notice This is the emitted event, when a buy is made.
    event BuyEvent(
        address _buyer,
        address _token,
        uint256 _tokenId,
        uint256 _amountOfToken,
        uint256 _price
    );

    /*
    constructor is executed when the factory contract calls its own deployERC1155 method
    */
    constructor(
        string memory _contractName,
        string memory _uri,
        string[] memory _names,
        uint[] memory _ids
    ) ERC1155(_uri) {
        names = _names;
        ids = _ids;
        // createMapping();
        setURI(_uri);
        baseMetadataURI = _uri;
        name = _contractName;
        transferOwnership(tx.origin);
    }

     /** 
        @param _token This is the address of the ERC1155 token.
        @param _tokenId This is the ID of the token that's inside of the ERC1155 token.
        @param _amountOfToken This is the amount of tokens that are going to be sold in the offer.
        @param _deadline This is the final date in (seconds) so the offer ends.
        @param _price This is the full price for the amountOfToken that user passed as the param.
        @dev We are making some require for the parameters that needs to be required.
        @return Return true if the sell is created successfully.
    **/
    function createList(
        address _token,
        uint256 _tokenId,
        uint256 _amountOfToken,
        uint256 _deadline,
        uint256 _price
    ) external returns (bool) {
        /*
            Check if amount of token is greater than 0
                full price for token  is greater than 0
                the deadline is longer than 1 hr
        */
        require(_amountOfToken > 0, "The amount of tokens to sell, needs to be greater than 0");
        require(_price > 0, "The full price for the tokens need to be greater than 0");
        require(_deadline > 3600, "The deadline needs to be greater than 1 hour");

        /*
            Add variables to the SellList struct with tokenAddress, seller, tokenId, amountOfToken, deadline, price
        */
        sales[salesId] = SellList (
            msg.sender,
            _token,
            _tokenId,
            _amountOfToken,
            block.timestamp + _deadline,
            _price,
            false
        );
        
        /*
            Add the salesId as increment 1
        */
        salesId ++;

        /*
            Emit the event when a sell is created.
        */
        emit SellEvent(
            msg.sender,
            _token,
            salesId,
            _tokenId,
            _amountOfToken
        );

        return true;
    }

    /**
        @param _sellId This is the ID of the SellList that's stored in mapping function.
    **/
    function buyListToken(
        uint256 _sellId
    ) external payable returns (bool) {
        /*
            Check if the msg.sender is not zero address
            of this sell, and if is sold
            msg.value needs to be greater than the price
        */
        require(msg.sender != address(0), "buyToken: Needs to be a address.");
        require(sales[_sellId].isSold != true, "buyToken: The tokends were bought.");
        require(msg.value >= sales[_sellId].price, "buyToken: Needs to be greater or equal to the price.");

        /*
            Get salePrice from the marketplaceFee
        */
        uint256 salePrice = sales[_sellId].price;

        /*
            Transfer salePrice to the seller's wallet
        */
        payable(sales[_sellId].seller).transfer(salePrice);
              
        /* 
            After we send the Matic to the user, we send
            the amountOfToken to the msg.sender.
        */
        IERC1155(sales[_sellId].token).safeTransferFrom(
            sales[_sellId].seller, 
            msg.sender, 
            sales[_sellId].tokenId, 
            sales[_sellId].amountOfToken, 
            "0x0"
        );

        sales[_sellId].isSold = true;
        return true;
    }

    /** 
        @param _sellId The ID of the sell that you want to cancel.
    **/
    function cancelList(
        uint256 _sellId
    ) external returns (bool) {
        /*
            Check if the msg.sender is really the owner
            of this sell, and if is not sold yet.
        */
        require(sales[_sellId].seller == msg.sender, "Cancel: should be the owner of the sell.");
        require(sales[_sellId].isSold != true, "Cancel: already sold.");
        /*
            After that checking we can safely delete the sell
            in our marketplace.
        */
        delete sales[_sellId];

        /*
            Emit the event when a sell is cancelled.
        */
        emit CanceledSell(
            sales[_sellId].seller, 
            sales[_sellId].token, 
            sales[_sellId].tokenId,
            sales[_sellId].amountOfToken
        );

        return true;
    }

    /**
        @param _sellId The ID of the sell that you want to make an offer.
        @param _price The offer price for _sellId.
    **/
    function makeOffer(
        uint256 _sellId,
        uint256 _price
    ) external payable returns (bool) {
        /*
            Check if the msg.value is the same as the _price value of this sell, 
             if the seller is msg.sender
             if it is not sold yet.
        */
        require(
            msg.value == _price,
            "makeOffer: msg.value should be the _price"
        );
        require(
            sales[_sellId].seller != msg.sender,
            "makeOffer: seller shouldn't offer"
        );
        require(sales[_sellId].isSold != true, "makeOffer: already sold.");

        /*
            Get the offerCount of this _sellId
        */
        uint256 counter = offerCount[_sellId];

        /*
            Add variables to the OfferData struct with offerAddress, offerPrice, offerAcceptable bool value
        */
        offerInfo[_sellId][counter] = OfferData(msg.sender, msg.value, false);

        /*
            The offerCount[_sellId] value add +1
        */
        offerCount[_sellId]++;

        /*
            Add the value to the `escrowAmount[address]`
        */
        escrowAmount[msg.sender] += msg.value;

        return true;
    }

    /**
        @param _sellId The ID of the sell that you want to make an offer.
        @param _offerCount The offer count to be accepted from the seller.
    **/
    function acceptOffer(
        uint256 _sellId,
        uint256 _offerCount
    ) external returns (bool) {
        /*
            Get the offer data from _sellId and _offerCount
        */
        OfferData memory offer = offerInfo[_sellId][_offerCount];

        /*
            Check if the sale NFTs are not sold
             if the seller is msg.sender
             if it is already accepted
             if offerPrice is larger than escrowAmount
        */
        require(sales[_sellId].isSold != true, "acceptOffer: already sold.");
        require(sales[_sellId].seller == msg.sender, "acceptOffer: not seller");
        require(offer.isAccepted == false, "acceptOffer: already accepted");
        require(
            offer.offerPrice <= escrowAmount[offer.offerAddress],
            "acceptOffer: lower amount"
        );

        /*
            Get offerPrice and feePrice from the marketplaceFee
        */
        uint256 offerPrice = offer.offerPrice;
        /*
            Transfer offerPrice to the seller's wallet
        */
        payable(offer.offerAddress).transfer(offerPrice);

        /*
            Substract the offerPrice from the `escrowAmount[address]`
        */
        escrowAmount[offer.offerAddress] -= offerPrice;

        /* 
            After we send the Matic to the user, we send
            the amountOfToken to the msg.sender.
        */
        IERC1155(sales[_sellId].token).safeTransferFrom(
            sales[_sellId].seller,
            offer.offerAddress,
            sales[_sellId].tokenId,
            sales[_sellId].amountOfToken,
            "0x0"
        );

        /*
            Set the offer data as it is accepted
        */
        offerInfo[_sellId][_offerCount].isAccepted = true;
        sales[_sellId].isSold = true;
        return true;
    }

    /**
        @param _sellId The ID of the sell that you want to make an offer.
        @param _offerCount The offer count to be cancelled from the offerAddress.
    **/
    function cancelOffer(
        uint256 _sellId,
        uint256 _offerCount
    ) external returns (bool) {
        /*
            Get the offer data from _sellId and _offerCount
        */
        OfferData memory offer = offerInfo[_sellId][_offerCount];

        /*
            Check if the offer's offerAddress is msg.sender
                if the offer is already accepted
                if the offerPrice is larger than the escrowAmount
        */
        require(
            msg.sender == offer.offerAddress,
            "cancelOffer: not offerAddress"
        );
        require(offer.isAccepted == false, "acceptOffer: already accepted");
        require(
            offer.offerPrice <= escrowAmount[msg.sender],
            "cancelOffer: lower amount"
        );

        /*
            Transfer offerPrice return to the offerAddress
        */
        payable(offer.offerAddress).transfer(offer.offerPrice);

        /*
            Substract the offerPrice from the `escrowAmount[address]`
        */
        escrowAmount[msg.sender] -= offer.offerPrice;

        /*
            After that checking we can safely delete the offerData
            in our marketplace.
        */
        delete offerInfo[_sellId][_offerCount];
        return true;
    }

    /**
        @dev This function used to deposit the Matic on this platform 
    **/
    function depositEscrow() external payable returns (bool) {
        /*
            Add the value to the `escrowAmount[address]`
        */
        escrowAmount[msg.sender] += msg.value;

        return true;
    }

    /**
        @dev This function used to withdraw the Matic on this platform 
        @param _amount This is the amount of the Matic to withdraw from the marketplace
    **/
    function withdrawEscrow(uint256 _amount) external returns (bool) {
        /*
            The _amount should be smaller than the `escrowAmount[address]` 
        */
        require(
            _amount < escrowAmount[msg.sender],
            "withdrawEscrow: lower amount"
        );

        /*
            Transfer _amount to the msg.sender wallet
        */
        payable(msg.sender).transfer(_amount);

        /*
            Substract the _amount from the `escrowAmount[address]`
        */
        escrowAmount[msg.sender] -= _amount;

        return true;
    }

    /** 
        @param _token This is the address of the ERC1155 token.
        @param _tokenId This is the ID of the token that's inside of the ERC1155 token.
        @param _amountOfToken This is the amount of tokens that are going to be created in auction.
        @param _startPrice This is the start Price of the auction.
        @param _minIncrement This is the min increment of the bids in this auction.
        @param _startDate This is the start date in (seconds) so the auction starts.
        @param _duration This is the duration of this auction.
        @param _reserved 1: reserved acution 0: normal auction
        @param _highestBidder if the auction is reserverd, then send the highestbider address
        @dev We are making some require for the parameters that needs to be required.
        @return Return true if the auction is created successfully.
    **/
    function createAuction(
        address _token,
        uint256 _tokenId,
        uint256 _amountOfToken,
        uint256 _startPrice,
        uint256 _minIncrement,
        uint256 _startDate,
        uint256 _duration,
        bool _reserved,
        address _highestBidder
    ) external returns (bool) {
        /*
            Check if amount of token is greater than 0
                the full price for token  is greater than 0
                the deadline is longer than 1 day
                the startPrice should be larger than 0
                the minIncrement should be larger than 0
                the startDate should be later than now
        */
        require(
            _amountOfToken > 0,
            "createAuction: The amount of tokens to sell, needs to be greater than 0"
        );
        require(
            _startPrice > 0,
            "createAuction: The startPrice for the tokens need to be greater than 0"
        );
        require(
            _duration > 86400,
            "createAuction: The deadline should to be greater than 1 day"
        );
        require(
            _startPrice > 0,
            "createAuction: The start Price should be bigger than 0"
        );
        require(
            _minIncrement > 0,
            "createAuction: The minIncrement should be bigger than 0"
        );
        require(
            _startDate > block.timestamp,
            "createAuction: The start date should be after now"
        );

        Action action;
        address highestBidder;

        if (!_reserved) {
            highestBidder = address(0);
            action = Action.STARTED;
        } else {
            highestBidder = _highestBidder;
            action = Action.RESERVED;
        }

        /*
            Add variables to the SellList struct with tokenAddress, seller, tokenId, amountOfToken, deadline, price
        */
        auction[auctionId] = AuctionData(
            msg.sender,
            _token,
            highestBidder,
            _tokenId,
            _amountOfToken,
            _startPrice - _minIncrement,
            _startPrice,
            _minIncrement,
            _startDate,
            _duration,
            action
        );

        /*
            Add the auctionId as increment 1
        */
        auctionId++;

        return true;
    }

    /*
        @param _auctionId Users can bid to the _auctionId with value
    */
    function placeBid(uint256 _auctionId) external payable returns (bool) {
        /*
            Get the auction data from _aucitonId
        */
        AuctionData memory auctionInfo = auction[_auctionId];

        /*
            Check if bidAmount is bigger than the higestBid + minIncrement
                if the creator is msg.sender
                if the bidTime is after the startDate
        */
        require(
            msg.value >= auctionInfo.highestBid + auctionInfo.minIncrement,
            "placeBid: Bid amount should be bigger than highestBid"
        );
        require(
            msg.sender != auctionInfo.creator,
            "placeBid: Creator can't bid"
        );
        require(
            block.timestamp >= auctionInfo.startDate,
            "placeBid: Bid should be after the startDate"
        );
        require(
            auctionInfo.action == Action.RESERVED &&
                auctionInfo.highestBidder == msg.sender,
            "placeBid: It is RESERVED"
        );
        require(
                auctionInfo.startDate + auctionInfo.duration > block.timestamp,
            "placeBid: It is Ended"
        );

        /*
            Send back the highestBid to the highestBidder - who is not zero address
        */
        if (auctionInfo.action != Action.RESERVED && auctionInfo.highestBidder != address(0)) {
            payable(auctionInfo.highestBidder).transfer(auctionInfo.highestBid);
        }

        /*
            If the auction is reserved, set the startDate as now
            action as Action Enum - STARTED
        */
        if (auctionInfo.action == Action.RESERVED) {
            auction[_auctionId].action = Action.STARTED;
        }

        /*
            Set the auctionData's highest bidder as msg.sender - who is the new bidder
                the auctionData's highest bid as msg.value - what is the new bid value
        */
        auction[_auctionId].highestBidder = msg.sender;
        auction[_auctionId].highestBid = msg.value;

        return true;
    }

    /*
        @param _auctionId The auction Creator can cancel the auction
    */
    function cancelAuction(uint256 _auctionId) external returns (bool) {
        /*
            Get the auction data from _aucitonId
        */
        AuctionData memory auctionInfo = auction[_auctionId];

        /*
            Check if the msg.sender should be the auction's creator 
                if the now time should be after auction's endDate
                if the auction's highestBidder should be zero address
        */
        require(
            msg.sender == auctionInfo.creator,
            "cancelAuction: Only auction creator can cancel it"
        );
        // require(
        //     block.timestamp > auctionInfo.startDate + auctionInfo.duration,
        //     "cancelAuction: The time should be after endDate"
        // );
        // require(
        //     auctionInfo.highestBidder == address(0),
        //     "cancelAuction: There should be not highestBidder"
        // );

        /*
            Send back the highestBid to the highestBidder - who is not zero address
        */
        if (auctionInfo.highestBidder != address(0)) {
            payable(auctionInfo.highestBidder).transfer(auctionInfo.highestBid);
        }

        /*
            Delete the auctionData from the blockchain
        */
        delete auction[_auctionId];

        return true;
    }

    /*
        @param _auctionId The highest bidder can claim the _auctionId's result
    */
    function claimAuction(uint256 _auctionId) external returns (bool) {
        /*
            Get the auction data from _aucitonId
        */
        AuctionData memory auctionInfo = auction[_auctionId];

        /*
            Check if the msg.sender should be the highestBidder
                if the now time should be after auction's endDate
                if the auction's highestBidder should be zero address
        */
        require(
            msg.sender == auctionInfo.highestBidder,
            "claimAuction: The msg.sender should be the highest Bidder"
        );
        require(
            block.timestamp > auctionInfo.startDate + auctionInfo.duration,
            "claimAuction: The time should be after endDate"
        );

        /* 
            Send the amountOfToken to the highest Bidder.
        */
        IERC1155(auctionInfo.token).safeTransferFrom(
            auctionInfo.creator,
            auctionInfo.highestBidder,
            auctionInfo.tokenId,
            auctionInfo.amountOfToken,
            "0x0"
        );

        /*
            Get bidPrice and feePrice from the marketplaceFee
        */
        uint256 bidPrice = auctionInfo.highestBid;

        /*
            Transfer bidPrice to the creator's wallet
        */
        payable(auctionInfo.creator).transfer(bidPrice);

        return true;
    }

    // /*
    // creates a mapping of strings to ids (i.e ["one","two"], [1,2] - "one" maps to 1, vice versa.)
    // */
    // function createMapping() private {
    //     for (uint id = 0; id < ids.length; id++) {
    //         nameToId[names[id]] = ids[id];
    //         idToName[ids[id]] = names[id];
    //     }
    // }
    /*
    sets our URI and makes the ERC1155 OpenSea compatible
    */
    function uri(
        uint256 _tokenid
    ) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    baseMetadataURI,
                    Strings.toString(_tokenid),
                    ".json"
                )
            );
    }

    function getNames() public view returns (string[] memory) {
        return names;
    }

    /*
    used to change metadata, only owner access
    */
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /*
    set a mint fee. only used for mint, not batch.
    */
    function setFee(uint _fee) public onlyOwner {
        mintFee = _fee;
    }

    /*
    mint(address account, uint _id, uint256 amount)

    account - address to mint the token to
    _id - the ID being minted
    amount - amount of tokens to mint
    */
    function mint(
        address account,
        uint _id,
        uint256 amount
    ) public payable returns (uint) {
        require(msg.value == mintFee);
        _mint(account, _id, amount, "");
        return _id;
    }

    /*
    mintBatch(address to, uint256[] memory _ids, uint256[] memory amounts, bytes memory data)

    to - address to mint the token to
    _ids - the IDs being minted
    amounts - amount of tokens to mint given ID
    bytes - additional field to pass data to function
    */
    function mintBatch(
        address to,
        uint256[] memory _ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        _mintBatch(to, _ids, amounts, data);
    }
}
