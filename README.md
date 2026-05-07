# NFT Marketplace (Foundry)

A Solidity-based NFT Marketplace built as part of my blockchain academy practice.
This project focuses on core marketplace flows, fee design, access control, and test-driven smart contract development with Foundry.

## What This Marketplace Does

The smart contract allows users to:

- List an ERC-721 NFT for sale.
- Buy a listed NFT with ETH.
- Cancel their own listing.

The marketplace owner (deployer or current `owner()`) earns fees from:

- Listing fee: paid when a user lists an NFT.
- Sale fee: percentage commission paid on successful purchases.

## Fee System (Configurable)

Fees are configurable by `onlyOwner` (not fixed forever):

- `listingFee`: fixed ETH amount for listing.
- `saleFeeBps`: sale commission in basis points.

Safety limits to prevent abusive configuration:

- `MAX_LISTING_FEE = 0.1 ether`
- `MAX_SALE_FEE_BPS = 1000` (10%)

Owner functions:

- `setListingFee(uint256 newFee)`
- `setSaleFeeBps(uint256 newFeeBps)`

## Core Contract

- [`NFTMarketplace.sol`](./src/NFTMarketplace.sol)

Main external functions:

- `listNFT(address nft, uint256 tokenId, uint256 price)` (`payable`)
- `buyNFT(address nft, uint256 tokenId)` (`payable`)
- `cancelListing(address nft, uint256 tokenId)`

## Security/Design Notes

- Uses `Ownable` for admin permissions.
- Uses `ReentrancyGuard` on purchase flow.
- Validates listing ownership before listing.
- Validates exact listing fee payment.
- Validates minimum payment on purchase.
- Uses checks-effects-interactions style by clearing listing state before external value transfers.

## Test Coverage

- Listing success path.
- Purchase success path.
- Purchase revert on insufficient payment.
- Cancel success path.
- Cancel revert when caller is not seller.
- Revert on incorrect listing fee.
- Owner can update fees.
- Non-owner cannot update fees.
- Revert when new fees exceed max limits.

Test file:

- [`NFTMarketplace.t.sol`](./test/¨NFTMarketplace.t.sol)

## Tech Stack

- Solidity `^0.8.24`
- Foundry (`forge`)
- OpenZeppelin Contracts (`Ownable`, `IERC721`, `ReentrancyGuard`, `ERC721` for mocks)

## How To Run

### Build

```bash
forge build
```

### Test

```bash
forge test -vvv
```

## Project Goal

This repository demonstrates practical Web3 engineering skills:

- Smart contract architecture.
- Marketplace logic and fee modeling.
- Access control and security constraints.
- Meaningful automated tests with Foundry.

---

If you are reviewing this project (recruiter/mentor/developer), I’d be happy to walk through the design decisions and test strategy.
