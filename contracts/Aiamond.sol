// SPDX-License-Identifier: None
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/// @custom:security-contact info@aiamond.com
contract Aiamond is
    ERC1155,
    Ownable,
    ERC1155Supply,
    ERC1155Pausable,
    ERC1155Burnable,
    ERC1155Holder
{
    uint256 public constant CHIPS = 0;
    uint256 public constant FIRST_DEALER_NFT_ID = 1;
    uint256 public constant LAST_DEALER_NFT_ID = 100;
    uint256 public constant FIRST_PLAYER_NFT_ID = 101;
    uint256 public constant LAST_PLAYER_NFT_ID = 200101;

    // Event to indicate a new guess is added
    event GuessAdded(
        // Address of the dealer who made the guess
        address indexed dealer,
        // Hash of the guess
        bytes32 guessHash,
        // Address of the token the guess is about
        address tokenAddress,
        // Chain ID of the token
        uint256 chainId,
        // Timestamp of the guess
        uint256 timestamp,
        // Initial price of the token
        uint256 initialPrice,
        // ID of the guess
        uint256 guessId,
        // needed deposit for revealing the guess
        uint256 neededDeposit
    );

    // Event to indicate a guess is revealed
    event GuessRevealedToPlayer(
        // Address of the NFT the guess is about
        uint256 indexed nftId,
        // ID of the guess
        uint256 indexed guessId,
        // Address of the player who revealed the guess
        address player,
        // Address of the token the guess is about
        address tokenAddress,
        // Timestamp of the guess
        uint256 timestamp,
        // Initial price of the token
        uint256 initialPrice,
        // Address of the dealer who made the guess
        uint256 dealer,
        // needed deposit for revealing the guess
        uint256 neededDeposit
    );

    // Event to indicate a price is revealed
    event PriceRevealed(
        // Address of the token the price is about
        address tokenAddress,
        // Timestamp of the price reveal
        uint256 timestamp,
        // Revealed price
        uint256 price,
        // Initial guess price
        uint256 initialPrice,
        // Guessed price
        uint256 guessedPrice,
        // Flag indicating if the guess is correct
        bool isCorrect,
        // Address of the NFT the guess is about
        uint256 nftId,
        // Total deposited amount
        uint256 totalDeposited
    );

    // Set the maximum supply of tokens
    uint256 public constant MAX_SUPPLY = 1000000;

    // Keep track of the number of tokens minted
    uint256 public tokensMinted = 0;

    // Keep track of the last minted token ID for each type of token
    uint256 public lastDealerTokenId = 0;
    uint256 public lastPlayerTokenId = 100;

    // keeping track of dealer activities
    struct NftInfo {
        Guess[] guesses;
        uint256 correctGuesses;
    }
    mapping(uint256 => NftInfo) public nftInfo;

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

    // Define a struct to represent a price reveal
    struct PriceReveal {
        address tokenAddress;
        uint256 timestamp;
        uint256 price;
    }

    // Mapping from NFT ID to balance
    mapping(uint256 => uint256) public nftBalances;

    // Add these state variables to the contract
    uint256 public dealerNFTPrice = 0.001 ether;
    uint256 public playerNFTPrice = 0.0001 ether;

    // doubling the price after...
    uint256 public dealerStep = 10;
    uint256 public playerStep = 20;

    // Add these state variables to the contract
    uint256 public dealerGuessPrice = 10;
    uint256 public playerRevealPrice = 10;

    // Add this state variable to the contract
    uint256 public playerDeposit = 100;

    constructor(
        address initialOwner
    ) ERC1155("https://aiamond.com/api/token/{id}.json") Ownable(initialOwner) {
        _mint(initialOwner, CHIPS, MAX_SUPPLY, "");
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mintDealer() public payable whenNotPaused {
        require(
            lastDealerTokenId <= LAST_DEALER_NFT_ID,
            "All DEALER tokens have been minted"
        );
        mintToken(++lastDealerTokenId, dealerNFTPrice);
    }

    function mintPlayer() public payable whenNotPaused {
        require(
            lastPlayerTokenId <= LAST_PLAYER_NFT_ID,
            "All PLAYER tokens have been minted"
        );
        mintToken(++lastPlayerTokenId, playerNFTPrice);
    }

    function mintToken(uint256 tokenId, uint256 tokenPrice) internal {
        require(
            msg.value >= tokenPrice,
            "Not enough Ether sent for minting a token"
        );

        // Transfer the payment to the contract owner
        payable(owner()).transfer(msg.value);

        // Mint the token to the user's address
        _mint(msg.sender, tokenId, 1, "");

        // Double the token price at different steps for dealer and player tokens
        if (tokenId <= LAST_DEALER_NFT_ID && tokenId % dealerStep == 0) {
            // Dealer tokens
            dealerNFTPrice *= 2;
        } else if (tokenId > LAST_DEALER_NFT_ID && tokenId % playerStep == 0) {
            // Player tokens
            playerNFTPrice *= 2;
        }
    }

    // START DEALER functions

    // Add a function for the dealer to add a guess
    function addGuess(
        bytes32 _guessHash,
        uint256 _nftId,
        address _tokenAddress,
        uint256 _chainId,
        uint256 _timestamp,
        uint256 _initialPrice,
        uint256 _neededDeposit
    ) public whenNotPaused returns (uint256) {
        // Check if the sender owns the NFT
        bool isDealer = false;
        if (
            FIRST_DEALER_NFT_ID <= _nftId &&
            _nftId <= LAST_DEALER_NFT_ID &&
            balanceOf(msg.sender, _nftId) > 0
        ) {
            isDealer = true;
        }
        require(isDealer, "Only DEALER NFT owners can make a guess");

        // Check if the sender has enough tokens of ID 0
        require(
            balanceOf(msg.sender, 0) >= dealerGuessPrice,
            "Not enough tokens to make a guess"
        );

        // transfer the dealerGuessPrice to the owner
        safeTransferFrom(msg.sender, owner(), CHIPS, dealerGuessPrice, "");

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

        emit GuessAdded(
            msg.sender,
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

    // Player pays to get a guess revealed
    function revealGuessToPlayer(
        uint256 _nftId,
        uint256 _guessId
    ) public whenNotPaused {
        // Check if the sender owns the NFT
        bool isPlayer = false;
        if (
            FIRST_PLAYER_NFT_ID <= _nftId &&
            _nftId <= LAST_PLAYER_NFT_ID &&
            balanceOf(msg.sender, _nftId) > 0
        ) {
            isPlayer = true;
        }
        require(isPlayer, "Only PLAYER NFT owners can reveal a guess");

        // Get the guess
        require(
            _guessId < nftInfo[_nftId].guesses.length,
            "Guess does not exist"
        );
        Guess storage guess = nftInfo[_nftId].guesses[_guessId];

        // Check if the guess has already been revealed by the player
        require(
            guess.players[_nftId] == 0,
            "This guess has already been revealed"
        );

        require(
            balanceOf(msg.sender, CHIPS) >=
                playerRevealPrice + guess.neededDeposit,
            "Not enough tokens to reveal a guess and make a deposit"
        );

        safeTransferFrom(
            msg.sender,
            address(this),
            CHIPS,
            guess.neededDeposit,
            ""
        ); // Transfer the deposit to the contract
        safeTransferFrom(msg.sender, owner(), CHIPS, playerRevealPrice, ""); // Transfer the reveal price to the owner

        guess.players[_nftId] = guess.neededDeposit;
        guess.playersParticipating.push(_nftId);

        emit GuessRevealedToPlayer(
            _nftId,
            _guessId,
            msg.sender,
            guess.tokenAddress,
            guess.timestamp,
            guess.initialPrice,
            guess.dealer,
            guess.neededDeposit
        );
    }

    // END PLAYER functions

    // START OWNER functions

    function setDealerGuessPrice(uint256 _price) public onlyOwner {
        dealerGuessPrice = _price;
    }

    function setPlayerRevealPrice(uint256 _price) public onlyOwner {
        playerRevealPrice = _price;
    }

    // Reveal price for guess
    function revealPriceForGuess(
        uint256 _dealerNftId,
        uint256 _guessId,
        uint256 _endPrice,
        uint256 _guessedPrice,
        uint256 _nonce
    ) public onlyOwner {
        NftInfo storage nft = nftInfo[_dealerNftId];
        Guess storage guess = nft.guesses[_guessId];

        // Check if the guess has already been revealed
        require(
            !guess.isPriceRevealed,
            "Price for this guess has already been revealed"
        );

        // Check if the _guessedPrice and _nonce create the correct hash
        require(
            keccak256(abi.encodePacked(_guessedPrice, _nonce)) ==
                guess.guessHash,
            "Guessed price and nonce do not match the hash"
        );

        // Reveal the price for this guess
        guess.isPriceRevealed = true;
        guess.endPrice = _endPrice;
        guess.guessedPrice = _guessedPrice;

        // Calculate multiplier and update correct guesses
        calculateAndUpdateGuesses(guess, nft, _endPrice);

        // If there are any pending deposits for this guess, transfer them now
        uint256 totalDeposited = transferDeposits(guess, _dealerNftId, _endPrice);

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

    // Calculate multiplier and update correct guesses
    function calculateAndUpdateGuesses(
        Guess storage guess,
        NftInfo storage nft,
        uint256 _endPrice
    ) internal {
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

    // Transfer deposits for a guess
    function transferDeposits(Guess storage guess, uint256 _dealerNftId, uint256 _endPrice) internal returns (uint256 totalDeposited) {
        for (uint pi = 0; pi < guess.playersParticipating.length; pi++) {
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

    // Function to update the token prices
    function updateTokenPrices(
        uint256 _newDealerNFTPrice,
        uint256 _newPlayerNFTPrice
    ) public onlyOwner {
        dealerNFTPrice = _newDealerNFTPrice;
        playerNFTPrice = _newPlayerNFTPrice;
    }

    // Function to update the dealer guess price and player reveal price
    function updatePrices(
        uint256 _newDealerGuessPrice,
        uint256 _newPlayerRevealPrice
    ) public onlyOwner {
        dealerGuessPrice = _newDealerGuessPrice;
        playerRevealPrice = _newPlayerRevealPrice;
    }

    // Function to update the URI of the tokens
    function updateURI(string memory _newURI) public onlyOwner {
        _setURI(_newURI);
    }

    // Function to update the owner of the contract
    function updateOwner(address _newOwner) public onlyOwner {
        transferOwnership(_newOwner);
    }

    // Function to withdraw the contract balance
    function withdrawBalance() public onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Failed to send Ether");
    }

    receive() external payable {}

    function withdrawChips() public onlyOwner {
        uint256 balance = balanceOf(address(this), CHIPS);
        require(balance > 0, "No CHIPS to withdraw");
        _safeTransferFrom(address(this), owner(), CHIPS, balance, "");

    }

    // Function to add CHIPS to an NFT (for testing purposes)
    function addChipsToNft(uint256 _nftId, uint256 _amount) public onlyOwner {
        require(balanceOf(msg.sender, CHIPS) >= _amount, "Not enough CHIPS");

        // Transfer the CHIPS from the owner to the contract
        safeTransferFrom(msg.sender, address(this), CHIPS, _amount, "");

        // Add the CHIPS to the NFT
        nftBalances[_nftId] += _amount;
    }

    // Function to add CHIPS to the contract
    function addChipsToContract(uint256 _amount) public onlyOwner {
        require(balanceOf(msg.sender, CHIPS) >= _amount, "Not enough CHIPS");

        // Transfer the CHIPS from the owner to the contract
        safeTransferFrom(msg.sender, address(this), CHIPS, _amount, "");
    }

    function setDealerStep(uint256 newStep) public onlyOwner {
        dealerStep = newStep;
    }

    function setPlayerStep(uint256 newStep) public onlyOwner {
        playerStep = newStep;
    }

    // Add a function to pause game
    function pauseGame() public onlyOwner {
        _pause();
    }

    // Add a function to resume game
    function resumeGame() public onlyOwner {
        _unpause();
    }

    // Function to change correctGuesses in a dealerInfo entry
    function setCorrectGuesses(
        uint256 dealerNftId,
        uint256 correctGuesses
    ) public onlyOwner {
        NftInfo storage dealerEntry = nftInfo[dealerNftId];
        dealerEntry.correctGuesses = correctGuesses;
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    // END OWNER functions

    // START dApp functions

    // Function for the holder of an NFT to withdraw their funds
    function withdrawFromNft(uint256 _nftId) public {
        require(
            balanceOf(msg.sender, _nftId) > 0 || msg.sender == owner(),
            "NFT does not exist or sender is not the owner"
        );
        require(nftBalances[_nftId] > 0, "No funds to withdraw");

        uint256 payout = nftBalances[_nftId];
        nftBalances[_nftId] = 0;

        // Transfer the CHIPS tokens to the sender
        safeTransferFrom(address(this), msg.sender, CHIPS, payout, "");
    }

    function getRevealedGuessesForNft(
        uint256 _nftId
    )
        public
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
        for (uint i = 0; i < nftInfo[_nftId].guesses.length; i++) {
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

    // Get the ID of the last guess added for a given NFT
    function getGuessId(uint256 _nftId) public view returns (uint256) {
        require(nftInfo[_nftId].guesses.length > 0, "No guesses for this NFT");
        return nftInfo[_nftId].guesses.length - 1;
    }

    // Get the details of a guess
    function getGuess(uint256 _nftId, uint256 _guessId) public view returns (uint256, address, uint256, bytes32, uint256, bool, uint256) {
        require(_guessId < nftInfo[_nftId].guesses.length, "Invalid guess ID");
        Guess storage guess = nftInfo[_nftId].guesses[_guessId];
        return (guess.dealer, guess.tokenAddress, guess.timestamp, guess.guessHash, guess.initialPrice, guess.isPriceRevealed, guess.neededDeposit);
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC1155Holder) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
