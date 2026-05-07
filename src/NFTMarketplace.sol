// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketplace is Ownable, ReentrancyGuard {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_SALE_FEE_BPS = 1_000; // 10%
    uint256 public constant MAX_LISTING_FEE = 0.1 ether;

    uint256 public listingFee;
    uint256 public saleFeeBps;

    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NFTCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);
    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);
    event ListingFeeUpdated(uint256 oldFee, uint256 newFee);
    event SaleFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    constructor() Ownable(msg.sender) {
        listingFee = 0.01 ether;
        saleFeeBps = 250; // 2.5%
    }

    function setListingFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= MAX_LISTING_FEE, "Listing fee too high");

        uint256 oldFee = listingFee;
        listingFee = _newFee;
        emit ListingFeeUpdated(oldFee, _newFee);
    }

    function setSaleFeeBps(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= MAX_SALE_FEE_BPS, "Sale fee too high");

        uint256 oldFeeBps = saleFeeBps;
        saleFeeBps = _newFeeBps;
        emit SaleFeeUpdated(oldFeeBps, _newFeeBps);
    }

    function listNFT(address _nftAddress, uint256 _tokenId, uint256 _price) external payable {
        require(_price > 0, "Price must be greater than zero");
        require(msg.value == listingFee, "Incorrect listing fee");

        address nftOwner = IERC721(_nftAddress).ownerOf(_tokenId);
        require(nftOwner == msg.sender, "Only the owner can list the NFT");

        (bool feeSent, ) = payable(owner()).call{value: msg.value}("");
        require(feeSent, "Listing fee transfer failed");

        listings[_nftAddress][_tokenId] = Listing(msg.sender, _nftAddress, _tokenId, _price);
        emit NFTListed(msg.sender, _nftAddress, _tokenId, _price);
    }

    function buyNFT(address _nftAddress, uint256 _tokenId) external payable nonReentrant {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.price > 0, "NFT not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        uint256 commission = (msg.value * saleFeeBps) / BPS_DENOMINATOR;
        uint256 sellerAmount = msg.value - commission;

        delete listings[_nftAddress][_tokenId];

        IERC721(_nftAddress).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        (bool sellerPaid, ) = payable(listing.seller).call{value: sellerAmount}("");
        require(sellerPaid, "Payment transfer failed");

        (bool feePaid, ) = payable(owner()).call{value: commission}("");
        require(feePaid, "Commission transfer failed");

        emit NFTSold(msg.sender, listing.seller, _nftAddress, _tokenId, listing.price);
    }

    function cancelListing(address _nftAddress, uint256 _tokenId) external {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.seller == msg.sender, "Only the seller can cancel the listing");

        delete listings[_nftAddress][_tokenId];
        emit NFTCancelled(msg.sender, _nftAddress, _tokenId);
    }
}
