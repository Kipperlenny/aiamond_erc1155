// SPDX-License-Identifier: None
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

/// @custom:security-contact info@aiamond.com
contract Aiamond is ERC1155, Ownable, ERC1155Supply {

    // Event to indicate a new guess is added
    event GuessAdded(
        // Address of the dealer who made the guess
        address indexed dealer,
        // Hash of the guess
        bytes32 guessHash,
        // Address of the token the guess is about
        address tokenAddress,
        // Timestamp of the guess
        uint256 timestamp,
        // Price of the guess
        uint256 price
    );

    // Event to indicate a price is revealed
    event PriceRevealed(
        // Address of the token the price is about
        address tokenAddress,
        // Timestamp of the price reveal
        uint256 timestamp,
        // Revealed price
        uint256 price
    );

    // Event to indicate a guess is revealed to a player
    event GuessRevealedToPlayer(
        // Address of the dealer who revealed the guess
        address indexed dealer,
        // Address of the player who paid for the reveal
        address indexed player,
        // Address of the token the guess is about
        address tokenAddress,
        // Timestamp of the guess
        uint256 timestamp,
        // Price of the guess
        uint256 price
    );

    // Set the maximum supply of tokens
    uint256 public constant MAX_SUPPLY = 200000;

    // Set the base price for minting a new token
    uint256 public tokenPrice = 0.0001 ether;

    // Keep track of the number of tokens minted
    uint256 public tokensMinted = 0;

    // Keep track of the last minted token ID for each type of token
    uint256 public lastDealerTokenId = 0;
    uint256 public lastPlayerTokenId = 100;

    // Define a struct to represent a guess
    struct Guess {
        bytes32 guessHash; // Add the guessHash variable
        bool isPriceRevealed; // Renamed from isPriceRevealed
        address tokenAddress;
        uint256 tokenPrice;
        uint256 timestamp;
        bool isCorrect;
        uint256 price; // Price of the guess in ETH
        address dealer; // Owner of the guess
    }

    // Define a struct to represent a price reveal
    struct PriceReveal {
        address tokenAddress;
        uint256 timestamp;
        uint256 price;
    }

    // Add these state variables to the contract
    uint256 public dealerGuessPrice = 10;
    uint256 public playerRevealPrice = 10;

    // Add this state variable to the contract
    uint256 public playerDeposit = 100;

    // Keep track of the price reveals
    PriceReveal[] public priceReveals;

    Guess[] public guessesArray;
    mapping(address => mapping(uint256 => Guess)) public guessesMapping;

    mapping(address => uint256[]) public playerGuesses;
    mapping(uint256 => Guess) public guesses;

    // Keep track of the dealers who have made guesses
    address[] public dealers;
    mapping(address => bool) isDealer;

    mapping(address => uint256[]) revealedGuesses;

    // Keep track of which guesses a player has revealed
    mapping(address => mapping(address => mapping(uint256 => bool))) public playerRevealedGuesses;

    // Map a token address and a timestamp to a price
    mapping(address => mapping(uint256 => uint256)) public revealedPrices;

    // Define a mapping to store the deposits of guesses that are waiting for the price to be revealed
    mapping(address => mapping(address => mapping(uint256 => uint256))) public pendingDeposits;

    constructor(address initialOwner)
        ERC1155("https://aiamond.com/api/token/{id}.json")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 0, 1000000, "");

    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mintDealer() public payable {
        require(lastDealerTokenId < 100, "All DEALER tokens have been minted");
        mintToken(++lastDealerTokenId);
    }

    function mintPlayer() public payable {
        require(lastPlayerTokenId < 200101, "All PLAYER tokens have been minted");
        mintToken(++lastPlayerTokenId);
    }

    function mintToken(uint256 tokenId) public payable {
        require(msg.value >= tokenPrice, "Not enough Ether sent for minting a token");
        require(tokensMinted < MAX_SUPPLY, "Max supply reached");

        // Transfer the payment to the contract owner
        payable(owner()).transfer(msg.value);

        // Mint the token to the user's address
        _mint(msg.sender, tokenId, 1, "");

        tokensMinted += 1;

        // Double the token price every 10th token
        if (tokensMinted % 10 == 0) {
            tokenPrice *= 2;
        }
    }

    // START DEALER functions

    // Add a function for the dealer to add a guess
    function addGuess(bytes32 _guessHash, address _tokenAddress, uint256 _timestamp, uint256 _price) public {
        // Check if the sender owns a dealer token
        bool hasDealerNft = false;
        for (uint i = 1; i <= 100; i++) {
            if (balanceOf(msg.sender, i) > 0) {
                hasDealerNft = true;
                break;
            }
        }
        require(hasDealerNft, "Only dealers can make a guess");

        // Check if the sender has enough tokens of ID 0
        require(balanceOf(msg.sender, 0) >= dealerGuessPrice, "Not enough tokens to make a guess");
        safeTransferFrom(msg.sender, owner(), 0, dealerGuessPrice, "");

        // Add the dealer to the array of dealers if they haven't made a guess before
        if (!isDealer[msg.sender]) {
            dealers.push(msg.sender);
            isDealer[msg.sender] = true;
        }

        // Add the guess to the array of the dealer's guesses
        // Create a new Guess
        Guess memory newGuess;
        newGuess.dealer = msg.sender;
        newGuess.tokenAddress = _tokenAddress;
        newGuess.timestamp = _timestamp;
        newGuess.tokenPrice = _price;
        newGuess.isPriceRevealed = false;

        // Store the Guess in the guesses mapping
        guessesMapping[msg.sender][_timestamp] = newGuess;

        // Also add the Guess to the guesses array
        guessesArray.push(newGuess);
        
        // In the addGuess function
        emit GuessAdded(msg.sender, _guessHash, _tokenAddress, _timestamp, _price);
    }

    // END DEALER functions

    // START PLAYER functions

    function revealGuessToPlayer(address _dealer, uint256 _guessId) public {
        require(balanceOf(msg.sender, 0) >= playerRevealPrice + playerDeposit, "Not enough tokens to reveal a guess and make a deposit");
        safeTransferFrom(msg.sender, address(this), 0, playerDeposit, ""); // Transfer the deposit to the contract
        safeTransferFrom(msg.sender, _dealer, 0, playerRevealPrice, ""); // Transfer the reveal price to the dealer

        // Check if the guess has already been revealed by the player
        require(!playerRevealedGuesses[msg.sender][_dealer][_guessId], "You've already revealed this guess");

        playerRevealedGuesses[msg.sender][_dealer][_guessId] = true;
        revealedGuesses[msg.sender].push(_guessId);

        pendingDeposits[msg.sender][_dealer][_guessId] = playerDeposit;
    }

    // END PLAYER functions

    // START OWNER functions

    function setDealerGuessPrice(uint256 _price) public onlyOwner {
        dealerGuessPrice = _price;
    }

    function setPlayerRevealPrice(uint256 _price) public onlyOwner {
        playerRevealPrice = _price;
    }

    function revealPriceForGuess(address _tokenAddress, uint256 _timestamp, uint256 _price) public onlyOwner {
        // Loop through all the guesses
        for (uint i = 0; i < guessesArray.length; i++) {
            // If the guess matches the given tokenAddress and timestamp
            if (guessesArray[i].tokenAddress == _tokenAddress && guessesArray[i].timestamp == _timestamp) {
                // Reveal the price for this guess
                guessesArray[i].isPriceRevealed = true;
                guessesArray[i].tokenPrice = _price;

                // Flag the guess as correct or incorrect based on the revealed price
                if (keccak256(abi.encodePacked(_price)) == guessesArray[i].guessHash) {
                    guessesArray[i].isCorrect = true;
                } else {
                    guessesArray[i].isCorrect = false;
                }

                // If there are any pending deposits for this guess, transfer them now
                if (pendingDeposits[guessesArray[i].dealer][_tokenAddress][_timestamp] > 0) {
                    // If the guess is correct, transfer the deposit to the dealer
                    if (guessesArray[i].price == _price) {
                        safeTransferFrom(address(this), _tokenAddress, 0, pendingDeposits[guessesArray[i].dealer][_tokenAddress][_timestamp], "");
                    }
                    // If the guess is not correct, transfer the deposit back to the player
                    else {
                        safeTransferFrom(address(this), guessesArray[i].dealer, 0, pendingDeposits[guessesArray[i].dealer][_tokenAddress][_timestamp], "");
                    }

                    // Clear the pending deposit
                    delete pendingDeposits[guessesArray[i].dealer][_tokenAddress][_timestamp];
                }

                // Emit the PriceRevealed event
                emit PriceRevealed(guessesArray[i].tokenAddress, guessesArray[i].timestamp, _price);
            }
        }
    }

    // Create a function to change the playerDeposit
    function setPlayerDeposit(uint256 _newDeposit) public onlyOwner {
        // Only allow the owner to change the playerDeposit
        require(msg.sender == owner(), "Only the owner can change the playerDeposit");

        // Update the playerDeposit
        playerDeposit = _newDeposit;
    }

    // Function to burn tokens
    function burn(address a, uint256 _tokenId, uint256 _amount) public {
        _burn(a, _tokenId, _amount);
    }

    // Function to update the token price
    function updateTokenPrice(uint256 _newPrice) public onlyOwner {
        tokenPrice = _newPrice;
    }

    // Function to update the dealer guess price and player reveal price
    function updatePrices(uint256 _newDealerGuessPrice, uint256 _newPlayerRevealPrice) public onlyOwner {
        dealerGuessPrice = _newDealerGuessPrice;
        playerRevealPrice = _newPlayerRevealPrice;
    }

    // Function to update the player deposit
    function updatePlayerDeposit(uint256 _newDeposit) public onlyOwner {
        playerDeposit = _newDeposit;
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
        require(payable(owner()).send(address(this).balance), "Failed to send Ether");
    }

    // END OWNER functions

    // START dApp functions

    function getRevealedGuessesForPlayer(address _player) public view returns (address[] memory, uint256[] memory, uint256[] memory) {
        // Initialize arrays to store the properties of the revealed guesses
        address[] memory playerDealers = new address[](playerGuesses[_player].length);
        uint256[] memory timestamps = new uint256[](playerGuesses[_player].length);
        uint256[] memory prices = new uint256[](playerGuesses[_player].length);

        // Iterate over the guesses of the player
        for (uint i = 0; i < playerGuesses[_player].length; i++) {
            Guess storage guess = guesses[playerGuesses[_player][i]];
            // If the guess is revealed, add its properties to the arrays
            if (guess.isPriceRevealed) {
                playerDealers[i] = _player;
                timestamps[i] = guess.timestamp;
                prices[i] = guess.tokenPrice;
            }
        }

        // Return the arrays
        return (playerDealers, timestamps, prices);
    }

    // END dApp functions

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}