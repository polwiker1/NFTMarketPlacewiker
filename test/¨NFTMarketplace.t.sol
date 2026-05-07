// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../lib/forge-std/src/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/NFTMarketplace.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTMarketplaceTest is Test {
    NFTMarketplace marketplace;
    MockNFT nft;

    address deployer = vm.addr(1);
    address user = vm.addr(2);
    address buyer = vm.addr(3);
    uint256 tokenId = 0;

    function setUp() public {
        vm.prank(deployer);
        marketplace = new NFTMarketplace();

        nft = new MockNFT();
        nft.mint(user, tokenId);

        vm.deal(user, 5 ether);
        vm.deal(buyer, 5 ether);
    }

    function testMintNFT() public view {
        address owner = nft.ownerOf(tokenId);
        assertEq(owner, user);
    }

    function testOwnerCanUpdateFees() public {
        vm.startPrank(deployer);
        marketplace.setListingFee(0.02 ether);
        marketplace.setSaleFeeBps(300);
        vm.stopPrank();

        assertEq(marketplace.listingFee(), 0.02 ether);
        assertEq(marketplace.saleFeeBps(), 300);
    }

    function testUpdateFeesRevertsIfNotOwner() public {
        vm.expectRevert();
        vm.prank(user);
        marketplace.setListingFee(0.02 ether);

        vm.expectRevert();
        vm.prank(user);
        marketplace.setSaleFeeBps(300);
    }

    function testUpdateFeesRevertsIfTooHigh() public {
        vm.startPrank(deployer);
        uint256 maxListingFee = marketplace.MAX_LISTING_FEE();
        uint256 maxSaleFeeBps = marketplace.MAX_SALE_FEE_BPS();

        vm.expectRevert("Listing fee too high");
        marketplace.setListingFee(maxListingFee + 1);

        vm.expectRevert("Sale fee too high");
        marketplace.setSaleFeeBps(maxSaleFeeBps + 1);

        vm.stopPrank();
    }

    function testListNFT() public {
        uint256 ownerBalanceBefore = deployer.balance;

        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT{value: marketplace.listingFee()}(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        (address seller, address nftAddress, uint256 listedTokenId, uint256 price) = marketplace.listings(address(nft), tokenId);
        assertEq(seller, user);
        assertEq(nftAddress, address(nft));
        assertEq(listedTokenId, tokenId);
        assertEq(price, 1 ether);
        assertEq(deployer.balance, ownerBalanceBefore + marketplace.listingFee());
    }

    function testBuyNFT() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT{value: marketplace.listingFee()}(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        uint256 sellerBalanceBefore = user.balance;
        uint256 ownerBalanceBefore = deployer.balance;

        vm.prank(buyer);
        marketplace.buyNFT{value: 1 ether}(address(nft), tokenId);

        uint256 commission = (1 ether * marketplace.saleFeeBps()) / marketplace.BPS_DENOMINATOR();
        uint256 sellerExpected = 1 ether - commission;

        assertEq(nft.ownerOf(tokenId), buyer);

        (address seller, , , uint256 price) = marketplace.listings(address(nft), tokenId);
        assertEq(seller, address(0));
        assertEq(price, 0);

        assertEq(user.balance, sellerBalanceBefore + sellerExpected);
        assertEq(deployer.balance, ownerBalanceBefore + commission);
    }

    function testBuyNFTRevertsIfInsufficientPayment() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT{value: marketplace.listingFee()}(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        vm.expectRevert("Insufficient payment");
        vm.prank(buyer);
        marketplace.buyNFT{value: 0.5 ether}(address(nft), tokenId);
    }

    function testCancelListing() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT{value: marketplace.listingFee()}(address(nft), tokenId, 1 ether);
        marketplace.cancelListing(address(nft), tokenId);
        vm.stopPrank();

        (address seller, , , uint256 price) = marketplace.listings(address(nft), tokenId);
        assertEq(seller, address(0));
        assertEq(price, 0);
        assertEq(nft.ownerOf(tokenId), user);
    }

    function testCancelListingRevertsIfNotSeller() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT{value: marketplace.listingFee()}(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        vm.expectRevert("Only the seller can cancel the listing");
        vm.prank(buyer);
        marketplace.cancelListing(address(nft), tokenId);
    }

    function testListNFTRevertsIfIncorrectFee() public {
        vm.startPrank(user);
        nft.approve(address(marketplace), tokenId);

        vm.expectRevert("Incorrect listing fee");
        marketplace.listNFT{value: 0}(address(nft), tokenId, 1 ether);
        vm.stopPrank();
    }
}
