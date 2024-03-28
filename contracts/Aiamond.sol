// SPDX-License-Identifier: None
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";

error AllDealerTokensMinted();
error AllPlayerTokensMinted();
error NotEnoughEtherForMinting();
error OnlyDealerNftOwnersCanGuess();
error DealerReachedMaxGuesses();
error NotEnoughTokensToGuess();
error OnlyPlayerNftOwnersCanReveal();
error GuessDoesNotExist();
error GuessAlreadyRevealed();
error NotEnoughTokensToRevealAndDeposit();
error PriceForGuessAlreadyRevealed();
error GuessedPriceAndNonceDoNotMatchHash();
error FailedToSendEther();
error NoChipsToWithdraw();
error NotEnoughChips();
error TokenAlreadyMinted();
error IdsAndAmountsLengthMustMatch();
error NftDoesNotExistOrSenderNotOwner();
error NoFundsToWithdraw();
error NoGuessesForThisNft();
error InvalidGuessId();

/// @title Aiamond
/// @author Kipperlenny
/// @notice This contract manages the aiamond.com token
/// @custom:security-contact info@aiamond.com
contract Aiamond is
    ERC1155,
    Ownable,
    ERC1155Supply,
    ERC1155Pausable,
    ERC1155Burnable,
    ERC1155Holder
{

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

    /// @notice Max number of guesses each dealer NFT can create
    mapping(uint256 _dealerNftId => uint256 _guessCount) public dealerGuessCount;

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

    /// @notice Mapping from dealerNftId to guess price
    mapping(uint256 _nftId => uint256 _specialGuessPrice) public specialGuessPrices;

    /// @notice Mapping from dealerNftId to reveal price
    mapping(uint256 _nftId => uint256 _specialRevealPrice) public specialRevealPrices;

    /// @param dealer NFT ID of the dealer who made the guess
    /// @param guessHash Hash of the guessed endPrice
    /// @param tokenAddress The address of the token the guess is about
    /// @param chainId The chain ID of the token
    /// @param timestamp Timestamp of the endprice
    /// @param initialPrice Price at the moment, the guess was added
    /// @param guessId ID of the guess
    /// @param neededDeposit needed deposit for revealing the guess
    /// @notice Event to indicate a new guess is added
    event GuessAdded(
        // Address of the dealer who made the guess
        address indexed dealer,
        // Hash of the guess
        bytes32 guessHash,
        // Address of the token the guess is about
        address tokenAddress,
        // Chain ID of the token
        uint256 indexed chainId,
        // Timestamp of the guess
        uint256 timestamp,
        // Initial price of the token
        uint256 initialPrice,
        // ID of the guess
        uint256 guessId,
        // needed deposit for revealing the guess
        uint256 indexed neededDeposit
    );

    /// @param playerNftId NFT ID of the player who revealed the guess
    /// @param guessId ID of the guess
    /// @param dealerNftId NFT ID of the dealer who made the guess
    /// @param tokenAddress The address of the token the guess is about
    /// @param chainId The chain ID of the token
    /// @param timestamp Timestamp of the endprice
    /// @param initialPrice Price at the moment, the guess was added
    /// @param neededDeposit needed deposit for revealing the guess
    /// @notice Event to indicate a guess is revealed to a player
    event GuessRevealedToPlayer(
        // Player NFT which revealed
        uint256 playerNftId,
        // ID of the guess
        uint256 indexed guessId,
        // Guess Dealer NFT ID
        uint256 indexed dealerNftId,
        // Address of the token the guess is about
        address tokenAddress,
        // Chain ID of the token
        uint256 indexed chainId,
        // Timestamp of the guess
        uint256 timestamp,
        // Initial price of the token
        uint256 initialPrice,
        // needed deposit for revealing the guess
        uint256 neededDeposit
    );

    /// @param tokenAddress The address of the token the guess is about
    /// @param timestamp Timestamp of the endprice
    /// @param endPrice The real price at the end 
    /// @param initialPrice Price at the moment, the guess was added
    /// @param guessedPrice Price the dealer guessed
    /// @param isCorrect Was the guess from the dealer correct?
    /// @param dealerNft NFT ID of the dealer who made the guess 
    /// @param totalDeposited Total amount of deposits for this guess
    /// @notice Event to indicate a price is revealed
    event PriceRevealed(
        // Address of the token the price is about
        address indexed tokenAddress,
        // Timestamp of the price reveal
        uint256 timestamp,
        // Revealed endPrice
        uint256 endPrice,
        // Initial price
        uint256 initialPrice,
        // guessedPrice
        uint256 guessedPrice,
        // Flag indicating if the guess is correct
        bool indexed isCorrect,
        // Address of the NFT the guess is about
        uint256 indexed dealerNft,
        // Total deposited amount
        uint256 totalDeposited
    );
    
    /// @param tokenId ID of the token
    /// @param minter Address of the minter
    /// @notice Event to indicate a new dealer token is minted
    event DealerMinted(
        uint256 indexed tokenId,
        address indexed minter
    );
    
    /// @param tokenId ID of the token
    /// @param minter Address of the minter
    /// @notice Event to indicate a new player token is minted
    event PlayerMinted(
        uint256 indexed tokenId,
        address indexed minter
    );

    /// @param tokenId ID of the token
    /// @param payout Amount to withdraw
    /// @param withdrawer Address of the withdrawer
    /// @notice Event to indicate a withdrawal from an NFT
    event WithdrawFromNft(
        uint256 indexed tokenId, 
        uint256 payout, 
        address indexed withdrawer
    );

    /// @notice Keep track of the last minted token ID for Dealer token
    uint256 public lastUsedDealerTokenId = FIRST_DEALER_NFT_ID - 1;

    /// @notice Keep track of the last minted token ID for Player token
    uint256 public lastUsedPlayerTokenId = FIRST_PLAYER_NFT_ID - 1;

    struct NftInfo {
        Guess[] guesses;
        uint256 correctGuesses;
    }
    /// @notice keeping track of dealer activities
    mapping(uint256 _nftId => NftInfo nftstruct) public nftInfo;

    // Define a struct to represent a guess
    struct Guess {
        uint256 dealer;
        uint256[] playersParticipating;
        mapping(uint256 => uint256) players;
        address tokenAddress;
        uint256 chainId;
        uint256 timestamp;
        uint256 endPrice;
        uint256 guessedPrice;
        uint256 initialPrice;
        bool isPriceRevealed;
        bool isCorrect;
        bytes32 guessHash;
        bool revealed;
        uint256 neededDeposit;
    }

    /// @notice Mapping from NFT ID to balance
    mapping(uint256 _nftId => uint256 _balance) public nftBalances;

    /// @dev make our NFTs unique
    mapping(uint256 _tokenId => bool _isMinted) private _mintedTokens;

    constructor(
        address initialOwner
    ) ERC1155("https://aiamond.com/api/token/{id}.json") Ownable(initialOwner) {
        _mint(initialOwner, CHIPS, MAX_CHIPS_SUPPLY, "");
    }

    /// @notice Function to set the URI for the tokens
    /// @param newuri New URI for the tokens
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /// @notice Function to mint a dealer token
    function mintDealer() external payable whenNotPaused {
        if (lastUsedDealerTokenId >= lastDealerNftId) {
            revert AllDealerTokensMinted();
        }
        mintToken(++lastUsedDealerTokenId, dealerNFTPrice);

        emit DealerMinted(lastUsedDealerTokenId, _msgSender());
    }

    /// @notice Function to mint a player token
    function mintPlayer() external payable whenNotPaused {
        if (lastUsedPlayerTokenId >= lastPlayerNftId) {
            revert AllPlayerTokensMinted();
        }
        mintToken(++lastUsedPlayerTokenId, playerNFTPrice);
        
        emit PlayerMinted(lastUsedPlayerTokenId, _msgSender());
    }

    /// @notice Function to mint a token, only called by mintDealer and mintPlayer
    /// @param tokenId ID of the token to mint
    /// @param tokenPrice Price of the token
    function mintToken(uint256 tokenId, uint256 tokenPrice) private {
        if (_msgSender() != owner()) {
            if (msg.value < tokenPrice) {
                revert NotEnoughEtherForMinting();
            }

            // Transfer the payment to the contract owner
            // payable(owner()).transfer(msg.value);
            Address.sendValue(payable(owner()), msg.value);
        }

        // Mint the token to the user's address
        safeMint(_msgSender(), tokenId, 1, "");

        // Double the token price at different steps for dealer and player tokens
        if (tokenId <= lastDealerNftId && tokenId % dealerStep == 0) {
            // Dealer tokens
            dealerNFTPrice *= 2;
        } else if (tokenId > lastDealerNftId && tokenId % playerStep == 0) {
            // Player tokens
            playerNFTPrice *= 2;
        }
    }

    // START DEALER functions

    /// @notice Function to add a guess
    /// @param _guessHash hashed endPrice
    /// @param _nftId nft of the dealer
    /// @param _tokenAddress address of the guessed token
    /// @param _chainId chain of the guessed token
    /// @param _timestamp timestamp for revealing the guess
    /// @param _initialPrice price at the moment of the token
    /// @param _neededDeposit how much a player has to deposit for revealing the guess
    function addGuess(
        bytes32 _guessHash,
        uint256 _nftId,
        address _tokenAddress,
        uint256 _chainId,
        uint256 _timestamp,
        uint256 _initialPrice,
        uint256 _neededDeposit
    ) external whenNotPaused returns (uint256) {
        // Check if the sender owns the NFT
        bool isDealer;
        if (
            FIRST_DEALER_NFT_ID <= _nftId &&
            _nftId <= lastDealerNftId &&
            balanceOf(_msgSender(), _nftId) > 0
        ) {
            isDealer = true;
        }

        if (!isDealer) {
            revert OnlyDealerNftOwnersCanGuess();
        }

        // Check if the dealer has not exceeded the maximum number of guesses
        if (dealerGuessCount[_nftId] >= maxGuesses) {
            revert DealerReachedMaxGuesses();
        }

        uint256 guessPrice = getGuessPrice(_nftId);

        // Check if the sender has enough tokens of ID 0
        if (balanceOf(_msgSender(), 0) < guessPrice) {
            revert NotEnoughTokensToGuess();
        }

        // transfer the guessPrice to the owner
        safeTransferFrom(_msgSender(), owner(), CHIPS, guessPrice, "");

        nftInfo[_nftId].guesses.push();
        uint256 guessId = nftInfo[_nftId].guesses.length - 1;

        Guess storage newGuess = nftInfo[_nftId].guesses[guessId];
        newGuess.dealer = _nftId;
        newGuess.tokenAddress = _tokenAddress;
        newGuess.timestamp = _timestamp;
        newGuess.chainId = _chainId;
        newGuess.guessHash = _guessHash;
        newGuess.initialPrice = _initialPrice;
        newGuess.isPriceRevealed = false;
        newGuess.neededDeposit = _neededDeposit;

        // Increment the guess count for the dealer
        ++dealerGuessCount[_nftId];

        emit GuessAdded(
            _msgSender(),
            _guessHash,
            _tokenAddress,
            _chainId,
            _timestamp,
            _initialPrice,
            guessId,
            _neededDeposit
        );

        return guessId;
    }

    // END DEALER functions

    // START PLAYER functions

    /// @notice Function to reveal a guess to a player
    /// @param _playerNftId NFT ID of the player
    /// @param _dealerNftId NFT ID of the dealer
    /// @param _guessId ID of the guess
    function revealGuessToPlayer(
        uint256 _playerNftId,
        uint256 _dealerNftId,
        uint256 _guessId
    ) external whenNotPaused {
        // Check if the sender owns the NFT
        bool isPlayer;
        if (
            FIRST_PLAYER_NFT_ID <= _playerNftId &&
            _playerNftId <= lastPlayerNftId &&
            balanceOf(_msgSender(), _playerNftId) > 0
        ) {
            isPlayer = true;
        }

        if (!isPlayer) {
            revert OnlyPlayerNftOwnersCanReveal();
        }

        // Get the guess
        if (_guessId >= nftInfo[_dealerNftId].guesses.length) {
            revert GuessDoesNotExist();
        }
        Guess storage guess = nftInfo[_dealerNftId].guesses[_guessId];

        // Check if the guess has already been revealed by the player
        if (guess.players[_playerNftId] != 0) {
            revert GuessAlreadyRevealed();
        }

        uint256 revealPrice = getRevealPrice(_dealerNftId);

        if (balanceOf(_msgSender(), CHIPS) < revealPrice + guess.neededDeposit) {
            revert NotEnoughTokensToRevealAndDeposit();
        }

        safeTransferFrom(
            _msgSender(),
            address(this),
            CHIPS,
            guess.neededDeposit,
            ""
        ); // Transfer the deposit to the contract

        safeTransferFrom(_msgSender(), owner(), CHIPS, revealPrice, ""); // Transfer the reveal price to the owner

        guess.players[_playerNftId] = guess.neededDeposit;
        guess.playersParticipating.push(_playerNftId);

        emit GuessRevealedToPlayer(
            _playerNftId,
            _guessId,
            _dealerNftId,
            guess.tokenAddress,
            guess.chainId,
            guess.timestamp,
            guess.initialPrice,
            guess.neededDeposit
        );
    }

    // END PLAYER functions

    // START OWNER functions

    /// @notice Function to set the price for dealer NFTs
    /// @param _price New price for dealer NFTs
    function setDealerGuessPrice(uint256 _price) external onlyOwner {
        dealerGuessPrice = _price;
    }

    /// @notice Function to set the price for player NFTs
    /// @param _price New price for player NFTs
    function setPlayerRevealPrice(uint256 _price) external onlyOwner {
        playerRevealPrice = _price;
    }

    /// @notice Function to reveal the price for a guess
    /// @param _dealerNftId NFT ID of the dealer
    /// @param _guessId ID of the guess
    /// @param _endPrice The real price at the end
    /// @param _guessedPrice The price the dealer guessed
    /// @param _nonce Nonce used to create the hash
    function revealPriceForGuess(
        uint256 _dealerNftId,
        uint256 _guessId,
        uint256 _endPrice,
        uint256 _guessedPrice,
        uint256 _nonce
    ) external onlyOwner {
        NftInfo storage nft = nftInfo[_dealerNftId];
        Guess storage guess = nft.guesses[_guessId];

        // Check if the guess has already been revealed
        if (guess.isPriceRevealed) {
            revert PriceForGuessAlreadyRevealed();
        }

        // Check if the _guessedPrice and _nonce create the correct hash
        if (keccak256(abi.encodePacked(_guessedPrice, _nonce)) != guess.guessHash) {
            revert GuessedPriceAndNonceDoNotMatchHash();
        }

        // Reveal the price for this guess
        guess.isPriceRevealed = true;
        guess.endPrice = _endPrice;
        guess.guessedPrice = _guessedPrice;

        // Calculate multiplier and update correct guesses
        calculateAndUpdateGuesses(guess, nft, _endPrice);

        // If there are any pending deposits for this guess, transfer them now
        uint256 totalDeposited = transferDeposits(guess, _dealerNftId, _endPrice);

        // Decrement the guess count for the dealer
        --dealerGuessCount[_dealerNftId];

        // Emit the PriceRevealed event
        emit PriceRevealed(
            guess.tokenAddress,
            guess.timestamp,
            _endPrice,
            guess.initialPrice,
            guess.guessedPrice,
            guess.isCorrect,
            _dealerNftId,
            totalDeposited
        );
    }

    /// @notice Function to calculate the difference between the guessed price and the end price
    /// @param guess The guess to calculate the difference for
    /// @param nft The NFT the guess is about
    /// @param _endPrice The real price at the end
    function calculateAndUpdateGuesses(
        Guess storage guess,
        NftInfo storage nft,
        uint256 _endPrice
    ) private {
        // Calculate the absolute difference and the multiplier
        uint256 multiplier = (guess.initialPrice > _endPrice
            ? guess.initialPrice - _endPrice
            : _endPrice - guess.initialPrice) / guess.initialPrice;

        // Flag the guess as correct or incorrect based on the revealed price
        guess.isCorrect = guess.guessedPrice <= _endPrice;
        if (guess.isCorrect) {
            nft.correctGuesses += multiplier; // make the NFT better
        } else if (nft.correctGuesses > 0) {
            nft.correctGuesses -= multiplier; // make the NFT worse
        }
    }

    /// @notice Function to transfer the deposits for a guess
    /// @param guess The guess to transfer the deposits for
    /// @param _dealerNftId NFT ID of the dealer
    /// @param _endPrice The real price at the end
    /// @return totalDeposited Total amount of deposits for this guess
    function transferDeposits(Guess storage guess, uint256 _dealerNftId, uint256 _endPrice) private returns (uint256 totalDeposited) {
        uint256 playersLength = guess.playersParticipating.length;
        for (uint256 pi; pi < playersLength; ++pi) {
            uint256 playerNftId = guess.playersParticipating[pi];
            uint256 playerDeposited = guess.players[playerNftId];
            if (guess.guessedPrice <= _endPrice) {
                nftBalances[_dealerNftId] += playerDeposited;
            } else {
                nftBalances[playerNftId] += playerDeposited;
            }
            totalDeposited += playerDeposited;

            guess.players[pi] = 0; // Set the deposit to 0
        }

        return totalDeposited;
    }

    /// @notice Function to update the price of the dealer and player NFTs
    /// @param _newDealerNFTPrice New price for dealer NFTs
    /// @param _newPlayerNFTPrice New price for player NFTs
    function updateTokenPrices(
        uint256 _newDealerNFTPrice,
        uint256 _newPlayerNFTPrice
    ) external onlyOwner {
        dealerNFTPrice = _newDealerNFTPrice;
        playerNFTPrice = _newPlayerNFTPrice;
    }

    /// @notice Function to update the prices for guessing and revealing
    /// @param _newDealerGuessPrice New price for guessing
    /// @param _newPlayerRevealPrice New price for revealing
    function updatePrices(
        uint256 _newDealerGuessPrice,
        uint256 _newPlayerRevealPrice
    ) external onlyOwner {
        dealerGuessPrice = _newDealerGuessPrice;
        playerRevealPrice = _newPlayerRevealPrice;
    }

    /// @notice Function to update the URI for the tokens
    /// @param _newURI New URI for the tokens
    function updateURI(string memory _newURI) external onlyOwner {
        _setURI(_newURI);
    }

    /// @notice Function to update the owner of the contract
    /// @param _newOwner Address of the new owner
    function updateOwner(address _newOwner) external onlyOwner {
        transferOwnership(_newOwner);
    }

    /// @notice Function to withdraw the balance of the contract
    function withdrawBalance() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        if (!success) {
            revert FailedToSendEther();
        }
    }

    /// @notice Function to pay the contract
    receive() external payable {}

    /// @notice Function to withdraw the CHIPS tokens from the contract
    function withdrawChips() external onlyOwner {
        uint256 balance = balanceOf(address(this), CHIPS);
        if (balance <= 0) {
            revert NoChipsToWithdraw();
        }
        _safeTransferFrom(address(this), owner(), CHIPS, balance, "");

    }

    /// @notice Function to add CHIPS to an NFT (for testing purposes)
    /// @param _nftId ID of the NFT to add CHIPS to
    /// @param _amount Amount of CHIPS to add
    function addChipsToNft(uint256 _nftId, uint256 _amount) external onlyOwner {
        if (balanceOf(_msgSender(), CHIPS) < _amount) {
            revert NotEnoughChips();
        }

        // Transfer the CHIPS from the owner to the contract
        _safeTransferFrom(_msgSender(), address(this), CHIPS, _amount, "");

        // Add the CHIPS to the NFT
        nftBalances[_nftId] += _amount;
    }

    /// @notice Function to add CHIPS to the contract (for testing purposes)
    /// @param _amount Amount of CHIPS to add
    function addChipsToContract(uint256 _amount) external onlyOwner {
        if (balanceOf(_msgSender(), CHIPS) < _amount) {
            revert NotEnoughChips();
        }

        // Transfer the CHIPS from the owner to the contract
        safeTransferFrom(_msgSender(), address(this), CHIPS, _amount, "");
    }

    /// @notice Function to set the newStep for dealer NFTs
    /// @param newStep New step for doubling the price of dealer NFTs
    function setDealerStep(uint256 newStep) external onlyOwner {
        dealerStep = newStep;
    }

    /// @notice Function to set the newStep for player NFTs
    /// @param newStep New step for doubling the price for player NFTs
    function setPlayerStep(uint256 newStep) external onlyOwner {
        playerStep = newStep;
    }

    /// @notice Function to pause the game
    function pauseGame() external onlyOwner {
        _pause();
    }

    /// @notice Function to resume the game
    function resumeGame() external onlyOwner {
        _unpause();
    }

    /// @notice Function to set the correct guesses for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @param correctGuesses Number of correct guesses
    function setCorrectGuesses(
        uint256 dealerNftId,
        uint256 correctGuesses
    ) external onlyOwner {
        NftInfo storage dealerEntry = nftInfo[dealerNftId];
        dealerEntry.correctGuesses = correctGuesses;
    }

    /// @notice Function to set the open guesses count for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @param guessCount Number of open guesses
    function setDealerGuessCount(
        uint256 dealerNftId,
        uint256 guessCount
    ) external onlyOwner {
        dealerGuessCount[dealerNftId] = guessCount;
    }

    /// @notice Function to set the balance of an NFT
    /// @param nftId ID of the NFT
    /// @param balance New balance for the NFT
    function setNftBalance(uint256 nftId, uint256 balance) external onlyOwner {
        nftBalances[nftId] = balance;
    }

    /// @notice mint a token, keeps track of token IDs to make NFT unique
    /// @param account address to mint to
    /// @param id token id
    /// @param amount amount to mint
    /// @param data additional data
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {

        if (id >= FIRST_DEALER_NFT_ID && id <= lastDealerNftId) {
            if (lastUsedDealerTokenId >= lastDealerNftId) {
                revert AllDealerTokensMinted();
            }
        } else if (id >= FIRST_PLAYER_NFT_ID && id <= lastPlayerNftId) {
            if (lastUsedPlayerTokenId >= lastPlayerNftId) {
                revert AllPlayerTokensMinted();
            }
        }

        safeMint(account, id, amount, data);

        // owner can ask for an id, this can lead to a gap in the token ids!
        if (id >= FIRST_DEALER_NFT_ID && id <= lastDealerNftId) {
            lastUsedDealerTokenId = id;
        } else if (id >= FIRST_PLAYER_NFT_ID && id <= lastPlayerNftId) {
            lastUsedPlayerTokenId = id;
        }
    }

    /// @notice emergency function to mint NFT again, do not use it
    /// @param account address to mint to
    /// @param id token id
    /// @param amount amount to mint
    /// @param data additional data
    function mintUnsafe(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        _mint(account, id, amount, data);
    }

    /// @notice mint a batch of tokens, keeps track of token IDs to make NFT unique
    /// @param to address to mint to
    /// @param ids token ids
    /// @param amounts amounts to mint
    /// @param data additional data
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        uint256 maxDealerTokenId = lastUsedDealerTokenId;
        uint256 maxPlayerTokenId = lastUsedPlayerTokenId;

       // call safeMintBatch and safe the max return to vars
        (maxDealerTokenId, maxPlayerTokenId) = safeMintBatch(to, ids, amounts, data);

        if (maxDealerTokenId >= FIRST_DEALER_NFT_ID && maxDealerTokenId <= lastDealerNftId) {
            lastUsedDealerTokenId = maxDealerTokenId;
        }
        if (maxPlayerTokenId >= FIRST_PLAYER_NFT_ID && maxPlayerTokenId <= lastPlayerNftId) {
            lastUsedPlayerTokenId = maxPlayerTokenId;
        }
    }

    /// @notice emergency function to mint NFTs again, do not use it
    /// @param to address to mint to
    /// @param ids token ids
    /// @param amounts amounts to mint
    /// @param data additional data
    function mintBatchUnsafe(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    /// @notice Function to mint a token, only called by mint and mintBatch
    /// @param to address to mint to
    /// @param id token id
    /// @param amount amount to mint
    /// @param data additional data
    function safeMint(address to, uint256 id, uint256 amount, bytes memory data) private {
        if (_mintedTokens[id]) {
            revert TokenAlreadyMinted();
        }
        _mintedTokens[id] = true;
        _mint(to, id, amount, data);
    }
    
    /// @notice Function to mint a batch of tokens, only called by mintBatch
    /// @param to address to mint to
    /// @param ids token ids
    /// @param amounts amounts to mint
    /// @param data additional data
    function safeMintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private returns (uint256, uint256) {
        if (ids.length != amounts.length) {
            revert IdsAndAmountsLengthMustMatch();
        }

        uint256 maxDealerTokenId = lastUsedDealerTokenId;
        uint256 maxPlayerTokenId = lastUsedPlayerTokenId;

        // First, check all the tokens
        uint256 idsLength = ids.length;
        for (uint256 i; i < idsLength; ++i) {
            uint256 id = ids[i];

            if (_mintedTokens[id]) {
                revert TokenAlreadyMinted();
            }

            if (id >= FIRST_DEALER_NFT_ID && id <= lastDealerNftId) {
                if (id > maxDealerTokenId) {
                    maxDealerTokenId = id;
                }
            } else if (id >= FIRST_PLAYER_NFT_ID && id <= lastPlayerNftId) {
                if (id > maxPlayerTokenId) {
                    maxPlayerTokenId = id;
                }
            }
        }

        if (maxDealerTokenId > lastDealerNftId) {
            revert AllDealerTokensMinted();
        }
        if (maxPlayerTokenId > lastPlayerNftId) {
            revert AllPlayerTokensMinted();
        }

        _mintBatch(to, ids, amounts, data);

        // If all the tokens passed the check, mark them as minted
        for (uint256 i; i < idsLength; ++i) {
            _mintedTokens[ids[i]] = true;
        }

        return (maxDealerTokenId, maxPlayerTokenId);
    }

    /// @notice Function to set the last used token ID
    /// @param id ID to set
    function setLastDealerTokenId(uint256 id) external onlyOwner {
        lastUsedDealerTokenId = id;
    }

    /// @notice Function to set the last used token ID
    /// @param id ID to set
    function setLastPlayerTokenId(uint256 id) external onlyOwner {
        lastUsedPlayerTokenId = id;
    }
    
    /// @notice Function to set the last dealer NFT ID
    /// @param _lastDealerNftId ID to set
    function setLastDealerNftId(uint256 _lastDealerNftId) external onlyOwner {
        lastDealerNftId = _lastDealerNftId;
    }

    /// @notice Function to set the last player NFT ID
    /// @param _lastPlayerNftId ID to set
    function setLastPlayerNftId(uint256 _lastPlayerNftId) external onlyOwner {
        lastPlayerNftId = _lastPlayerNftId;
    }

    /// @notice Function to set the guess price individually for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @param price New price for guessing
    function setSpecialGuessPrice(uint256 dealerNftId, uint256 price) external onlyOwner {
        specialGuessPrices[dealerNftId] = price;
    }

    /// @notice Function to get the guess price for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @return price Price for guessing
    function getGuessPrice(uint256 dealerNftId) public view returns (uint256) {
        uint256 specialPrice = specialGuessPrices[dealerNftId];
        if (specialPrice > 0) {
            return specialPrice;
        } else {
            return dealerGuessPrice;
        }
    }

    /// @notice Function to set the reveal price individually for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @param price New price for revealing
    function setSpecialRevealPrice(uint256 dealerNftId, uint256 price) external onlyOwner {
        specialRevealPrices[dealerNftId] = price;
    }

    /// @notice Function to get the reveal price for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @return price Price for revealing
    function getRevealPrice(uint256 dealerNftId) public view returns (uint256) {
        uint256 specialPrice = specialRevealPrices[dealerNftId];
        if (specialPrice > 0) {
            return specialPrice;
        } else {
            return playerRevealPrice;
        }
    }

    /// @notice Function to set the maximum number of guesses for a dealer NFT
    /// @param _maxGuesses Maximum number of guesses
    function setMaxGuesses(uint256 _maxGuesses) external onlyOwner {
        maxGuesses = _maxGuesses;
    }

    // END OWNER functions

    // START dApp functions

    /// @notice Function to withdraw the balance of an NFT
    /// @param _nftId ID of the NFT
    function withdrawFromNft(uint256 _nftId) external {
        if (balanceOf(_msgSender(), _nftId) <= 0 && _msgSender() != owner()) {
            revert NftDoesNotExistOrSenderNotOwner();
        }
        if (nftBalances[_nftId] <= 0) {
            revert NoFundsToWithdraw();
        }

        uint256 payout = nftBalances[_nftId];
        nftBalances[_nftId] = 0;

        // Transfer the CHIPS tokens to the sender
        _safeTransferFrom(address(this), _msgSender(), CHIPS, payout, "");

        emit WithdrawFromNft(_nftId, payout, _msgSender());
    }

    /// @notice Function to get the balance of an NFT
    /// @param _nftId ID of the NFT
    /// @return balance Balance of the NFT
    function getNftBalance(uint256 _nftId) external view returns (uint256) {
        return nftBalances[_nftId];
    }

    /// @notice Function to get the balance of the contract
    /// @return balance Balance of the contract
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Function to get the price for guessing
    /// @param _nftId ID of the NFT
    /// @return price Price for guessing
    function getGuessPriceForNft(uint256 _nftId) external view returns (uint256) {
        return getGuessPrice(_nftId);
    }

    /// @notice Function to get the price for revealing
    /// @param _nftId ID of the NFT
    /// @return price Price for revealing
    function getRevealPriceForNft(uint256 _nftId) external view returns (uint256) {
        return getRevealPrice(_nftId);
    }

    /// @notice Function to get the correct guesses for a dealer NFT
    /// @param _nftId ID of the NFT
    /// @return correctGuesses Number of correct guesses
    function getCorrectGuessesForNft(uint256 _nftId) external view returns (uint256) {
        return nftInfo[_nftId].correctGuesses;
    }

    /// @notice Function to get the number of guesses for a dealer NFT
    /// @param _nftId ID of the NFT
    /// @return guessCount Number of guesses
    function getGuessCountForNft(uint256 _nftId) external view returns (uint256) {
        return nftInfo[_nftId].guesses.length;
    }

    /// @notice Function to get the revealed guesses for a dealer NFT
    /// @param _nftId ID of the NFT
    /// @return guessIds IDs of the guesses
    /// @return participants Number of participants for each guess
    /// @return deposits Deposits for each guess
    /// @return timestamps Timestamps for each guess
    /// @return prices Prices for each guess
     function getRevealedGuessesForNft(
        uint256 _nftId
    )
        external
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        // Initialize arrays to store the properties of the revealed guesses
        uint256[] memory guessIds = new uint256[](
            nftInfo[_nftId].guesses.length
        );
        uint256[] memory participants = new uint256[](
            nftInfo[_nftId].guesses.length
        );
        uint256[] memory deposits = new uint256[](
            nftInfo[_nftId].guesses.length
        );
        uint256[] memory timestamps = new uint256[](
            nftInfo[_nftId].guesses.length
        );
        uint256[] memory prices = new uint256[](nftInfo[_nftId].guesses.length);

        // Iterate over the guesses of the NFT
        uint256 guessesLength = nftInfo[_nftId].guesses.length;
        for (uint256 i; i < guessesLength; ++i) {
            Guess storage guess = nftInfo[_nftId].guesses[i];
            // If the guess is revealed, add its properties to the arrays
            if (guess.isPriceRevealed) {
                guessIds[i] = i;
                participants[i] += 1;
                deposits[i] = guess.players[_nftId];
                timestamps[i] = guess.timestamp;
                prices[i] = guess.endPrice;
            }
        }

        // Return the arrays
        return (guessIds, participants, deposits, timestamps, prices);
    }

    /// @notice Function to get the number of active guesses for an NFT
    /// @param _nftId ID of the NFT
    /// @return guesses Number of guesses
    function getGuessId(uint256 _nftId) external view returns (uint256) {
        if (nftInfo[_nftId].guesses.length <= 0) {
            revert NoGuessesForThisNft();
        }
        return nftInfo[_nftId].guesses.length - 1;
    }

    /// @notice Function to get a specific guess
    /// @param _nftId ID of the NFT
    /// @param _guessId ID of the guess
    /// @return dealer Address of the dealer
    /// @return playersParticipating IDs of the players participating
    /// @return playersDeposits Deposits of the players participating
    /// @return tokenAddress Address of the token the price is about
    /// @return chainId Chain ID of the token
    /// @return timestamp Timestamp of the guess
    /// @return guessHash Hash of the guess
    /// @return initialPrice Initial price of the token
    /// @return isPriceRevealed Flag indicating if the price is revealed
    /// @return neededDeposit Deposit needed for revealing the guess
    function getGuess(uint256 _nftId, uint256 _guessId) external view returns (uint256, uint256[] memory, uint256[] memory, address, uint256, uint256, bytes32, uint256, bool, uint256) {
        if (_guessId >= nftInfo[_nftId].guesses.length) {
            revert InvalidGuessId();
        }

        Guess storage guess = nftInfo[_nftId].guesses[_guessId];

        uint256 guessPlayersParticipatingLength = guess.playersParticipating.length;
        uint256[] memory playersDeposits = new uint256[](guessPlayersParticipatingLength);
        for (uint256 i; i < guessPlayersParticipatingLength; ++i) {
            playersDeposits[i] = guess.players[guess.playersParticipating[i]];
        }

        return (guess.dealer, guess.playersParticipating, playersDeposits, guess.tokenAddress, guess.chainId, guess.timestamp, guess.guessHash, guess.initialPrice, guess.isPriceRevealed, guess.neededDeposit);
    }

    /// @notice Function to get the number of correct guesses for a dealer NFT
    /// @param dealerNftId NFT ID of the dealer
    /// @return guesses Number of correct guesses
    /// @return correctGuesses Number of correct guesses
    function getNftInfo(uint256 dealerNftId) external view returns (uint256, uint256) {
        NftInfo storage info = nftInfo[dealerNftId];
        return (info.guesses.length, info.correctGuesses);
    }

    // END dApp functions

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    /// @notice Function to check if a contract supports an interface
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
