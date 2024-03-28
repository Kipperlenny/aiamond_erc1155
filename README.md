# Aiamond Project

This project is a Solidity ERC1155 smart contract for the Aiamond platform. It creates three types of token. Chips as a utility for the plattform, Dealer NFTs for guessing token prices and Player NFTs for revealing guesses.

Check out the project on https://aiamond.com
Join our Discord: https://discord.gg/T92Ekjg3fx

## Description

This project contains a Solidity smart contract named `Aiamond.sol` located in the `contracts` folder. The contract uses OpenZeppelin libraries for standard functionality and defines custom errors for specific conditions.

## Features

- Dealer and Player NFT minting
- Price guessing and revealing
- Token withdrawal

## Testing
The tests for the contract are located in the test folder, in a file named aiamondTests.js. To run the tests:

```shell
npx hardhat test
```

## Events
The contract emits several events to indicate various actions:

 - GuessAdded: Indicates a new guess is added.
 - GuessRevealedToPlayer: Indicates a guess is revealed to a player.
 - PriceRevealed: Indicates a price is revealed.
 - DealerMinted: Indicates a new dealer token is minted.
 - PlayerMinted: Indicates a new player token is minted.
 - WithdrawFromNft: Indicates a withdrawal from an NFT.

## Configuration
The contract contains several configuration constants at the top of the file, such as the ID for chips, the utility token of Aiamond, the first and last IDs for dealer and player NFTs, the maximum supply of tokens, the maximum number of guesses each dealer NFT can create, the prices for dealer and player NFTs, and the default prices for a guess and revealing a guess.

```solidity
/// @notice Represents the ID for chips, the utility token of aiamond
uint256 public constant CHIPS = 0;

/// @notice First ID for dealer NFTs
uint256 public constant FIRST_DEALER_NFT_ID = 1000000;

/// @notice Last ID for dealer NFTs, can be changed by the owner
uint256 public lastDealerNftId = 1000099;

/// @notice First ID for player NFTs
uint256 public constant FIRST_PLAYER_NFT_ID = 10000000;

/// @notice Last ID for player NFTs, can be changed by the owner
uint256 public lastPlayerNftId = 10099999;

/// @notice Set the maximum supply of tokens
uint256 public constant MAX_CHIPS_SUPPLY = 1000000000;

/// @notice initial Max number of guesses each dealer NFT can create
uint256 public maxGuesses = 10;

/// @notice Price for dealer NFTs
uint256 public dealerNFTPrice = 0.001 ether;

/// @notice Price for player NFTs
uint256 public playerNFTPrice = 0.0001 ether;

/// @notice doubling the price after X dealer NFTs sold
uint256 public dealerStep = 10;

/// @notice doubling the price after X player NFTs sold
uint256 public playerStep = 1000;

/// @notice default Price for a guess
uint256 public dealerGuessPrice = 10;

/// @notice default Price for revealing a guess
uint256 public playerRevealPrice = 10;
```

## Contributing
Feel free to test the contract and create issues for bugs!

## License
No License at the moment