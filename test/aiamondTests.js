const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("Aiamond", function () {
    const CHIPS = 0;
    const MAX_CHIPS_SUPPLY = 1000000000;
    const FIRST_DEALER_NFT_ID = 1000000;
    const FIRST_PLAYER_NFT_ID = 10000000;
    const LAST_DEALER_NFT_ID = 1000099;
    const LAST_PLAYER_NFT_ID = 10099999;
    const dealerGuessPrice = 10;
    const playerRevealPrice = 10;
    let Aiamond;
    let aiamond;
    let owner;
    let addr1;
    let addr2;
    let dealerNft1;
    let dealerNft2;
    let playerNft1;
    let playerNft2;
    let aiamondAddress;
    let dealer1NftId = FIRST_DEALER_NFT_ID; // Use any ID in the range 1000000 - 1000099
    let dealer2NftId = FIRST_DEALER_NFT_ID + 1; // Use any ID in the range 1000000 - 1000099
    let player1NftId = FIRST_PLAYER_NFT_ID; // Use any ID in the range 102 - 200101
    let player2NftId = FIRST_PLAYER_NFT_ID + 1; // Use any ID in the range 102 - 200101

    const externTokenAddress = "0xa324175E95Ef225dDCc1852F9F7939D997c0757d";

    beforeEach(async function () {
        Aiamond = await ethers.getContractFactory("Aiamond");
        [owner, addr1, addr2, dealerNft1, dealerNft2, playerNft1, playerNft2, ...addrs] = await ethers.getSigners();
        aiamond = await Aiamond.deploy(owner.address).catch(console.error);
        await aiamond.waitForDeployment();
        aiamondAddress = await aiamond.getAddress();

        // Mint a dealer NFT for the dealer
        await aiamond.connect(owner).mint(dealerNft1.address, dealer1NftId, 1, "0x");

        // Mint a dealer NFT for the dealer
        await aiamond.connect(owner).mint(dealerNft2.address, dealer2NftId, 1, "0x");

        // Mint a player NFT for the player
        await aiamond.connect(owner).mint(playerNft1.address, player1NftId, 1, "0x");

        // Mint a player NFT for the player
        await aiamond.connect(owner).mint(playerNft2.address, player2NftId, 1, "0x");
    });

    describe("Constructor", function () {
        it("should set the owner correctly", async function () {
            expect(await aiamond.owner()).to.equal(owner.address);
        });
    });

    describe("withdrawBalance", function () {
        it("should not allow non-owners to withdraw the balance", async function () {
            // Add some funds to the contract
            await owner.sendTransaction({ to: aiamondAddress, value: ethers.parseEther("1.0") });

            try {
                await aiamond.connect(addr1).withdrawBalance();
                expect.fail('Expected withdrawBalance to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });

        it("should allow the owner to withdraw the balance", async function () {
            // Add some funds to the contract
            await owner.sendTransaction({ to: aiamondAddress, value: ethers.parseEther("1.0") });

            // Withdraw the balance
            await expect(() => aiamond.withdrawBalance())
                .to.changeEtherBalance(owner, ethers.parseEther("1.0"));
        });
    });

    describe("withdrawChips", function () {
        it("should not allow non-owners to withdraw chips", async function () {

            try {
                await aiamond.connect(addr1).withdrawChips();
                expect.fail('Expected withdrawChips to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });

        it("should fail if there are no chips to withdraw", async function () {
            await expect(aiamond.withdrawChips()).to.be.revertedWithCustomError(aiamond, "NoChipsToWithdraw");
        });

        it("should allow the owner to withdraw chips if there are any", async function () {
            // Add some chips to the contract
            // Note: You'll need to replace this with the actual method to add chips
            await aiamond.addChipsToContract(100);

            // Give approval for the contract to manage the owner's tokens
            // await aiamond.setApprovalForAll(aiamond.address, true, { from: owner.address });

            // Withdraw the chips
            await aiamond.withdrawChips();

            // Check that the owner received the chips
            expect(await aiamond.balanceOf(owner.address, 0)).to.equal(MAX_CHIPS_SUPPLY); // start balance should equal end (1000000)
        });
    });

    describe("withdrawFromNft", function () {
        it("should allow the owner to withdraw from an NFT", async function () {
            // Setup: Define the _nftId and add some balance to it
            let _nftId = 1;
            await aiamond.addChipsToNft(_nftId, 100);

            // Act: Call the withdrawFromNft function
            await aiamond.withdrawFromNft(_nftId);

            // Assert: Check the balance of the NFT
            expect(await aiamond.nftBalances(_nftId)).to.equal(0);

            // Assert: Check the balance of the owner
            expect(await aiamond.balanceOf(owner.address, 0)).to.equal(MAX_CHIPS_SUPPLY);
        });

        it("should allow the dealer to withdraw from his NFT", async function () {
            // Setup: Define the _nftId and add some balance to it
            let _nftId = FIRST_DEALER_NFT_ID;
            await aiamond.connect(owner).addChipsToNft(_nftId, 100);

            // Act: Call the withdrawFromNft function
            await aiamond.connect(dealerNft1).withdrawFromNft(_nftId);

            // Assert: Check the balance of the NFT
            expect(await aiamond.nftBalances(_nftId)).to.equal(0);

            // Assert: Check the balance of the dealer
            expect(await aiamond.balanceOf(dealerNft1.address, 0)).to.equal(100);
        });

        it("should fail if called by a non-owner and the caller does not own the NFT", async function () {
            // Setup: Define the _nftId and add some balance to it
            let _nftId = FIRST_DEALER_NFT_ID;
            aiamond.nftBalances[_nftId] = 100;

            // Act and Assert: Call the withdrawFromNft function and expect it to be reverted
            await expect(aiamond.connect(dealerNft2).withdrawFromNft(_nftId))
                .to.be.revertedWithCustomError(aiamond, "NftDoesNotExistOrSenderNotOwner");
        });

        it("should fail if there are no funds to withdraw", async function () {
            // Setup: Define the _nftId
            let _nftId = FIRST_DEALER_NFT_ID;

            // Act and Assert: Call the withdrawFromNft function and expect it to be reverted
            await expect(aiamond.connect(dealerNft1).withdrawFromNft(_nftId))
                .to.be.revertedWithCustomError(aiamond, "NoFundsToWithdraw");
        });
    });

    describe("revealPriceForGuess", function () {
        it("should reveal the price for a guess", async function () {

            // Setup: Add a guess
            let nftId = FIRST_DEALER_NFT_ID;
            let guessHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [100, 1]));
            let chainId = 1;
            let timestamp = Math.floor(Date.now() / 1000);
            let initialPrice = 100;
            let neededDeposit = 10;

            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, 0, 10, "0x");
            await aiamond.connect(dealerNft1).addGuess(guessHash, nftId, externTokenAddress, chainId, timestamp, initialPrice, neededDeposit);

            // Act: Reveal the price for the guess
            let guessId = await aiamond.getGuessId(nftId);
            let endPrice = 100;
            let guessedPrice = 100;
            let nonce = 1;

            // Get the initial guess count for the dealer
            let initialGuessCount = await aiamond.dealerGuessCount(nftId);

            await expect(aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice, nonce))
                .to.emit(aiamond, "PriceRevealed")
                .withArgs(
                    externTokenAddress,
                    timestamp,
                    endPrice,
                    initialPrice,
                    guessedPrice,
                    true,
                    nftId,
                    0 // because no player participated
                );

            // Assert: Check the guess details
            [dealer, playersParticipating, playersDeposits, tokenAddress, chainId, timestamp, guessHash, initialPrice, isPriceRevealed, neededDeposit] = await aiamond.getGuess(nftId, guessId);
            expect(isPriceRevealed).to.equal(true);

            // Assert: Check that the guess count for the dealer has been decremented
            let finalGuessCount = await aiamond.dealerGuessCount(nftId);
            expect(finalGuessCount).to.equal(Number(initialGuessCount) - 1);

        });

        it("should fail if the guess has already been revealed", async function () {
            // Setup: Add a guess and reveal the price
            let nftId = FIRST_DEALER_NFT_ID;
            let guessHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [100, 1]));
            let chainId = 1;
            let timestamp = Math.floor(Date.now() / 1000);
            let initialPrice = 100;
            let neededDeposit = 10;
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, 0, 10, "0x");
            await aiamond.connect(dealerNft1).addGuess(guessHash, nftId, externTokenAddress, chainId, timestamp, initialPrice, neededDeposit);

            let guessId = await aiamond.getGuessId(nftId);
            let endPrice = 100;
            let guessedPrice = 100;
            let nonce = 1;
            await aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice, nonce);

            // Act: Try to reveal the price again
            await expect(aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice, nonce))
                .to.be.revertedWithCustomError(aiamond, "PriceForGuessAlreadyRevealed");
        });

        it("should fail if the guessed price and nonce do not match the hash", async function () {
            // Setup: Add a guess with a certain hash
            let nftId = FIRST_DEALER_NFT_ID;
            let guessHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [100, 1]));
            let chainId = 1;
            let timestamp = Math.floor(Date.now() / 1000);
            let initialPrice = 100;
            let neededDeposit = 10;
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, 0, 10, "0x");
            await aiamond.connect(dealerNft1).addGuess(guessHash, nftId, externTokenAddress, chainId, timestamp, initialPrice, neededDeposit);

            // Act: Try to reveal the price with a different guessed price and nonce
            let guessId = await aiamond.getGuessId(nftId);
            let endPrice = 100;
            let guessedPrice = 100;
            let nonce = 1;
            await expect(aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice + 1, nonce))
                .to.be.revertedWithCustomError(aiamond, "GuessedPriceAndNonceDoNotMatchHash");
        });
    });

    describe("setCorrectGuesses", function () {
        it("should set the correctGuesses for a given dealerNftId", async function () {
            // Setup: Define the dealerNftId and correctGuesses
            let dealerNftId = FIRST_DEALER_NFT_ID;
            let correctGuesses = 5;

            // Act: Call the setCorrectGuesses function
            await aiamond.connect(owner).setCorrectGuesses(dealerNftId, correctGuesses);

            // Assert: Check the correctGuesses value
            let dealerEntry = await aiamond.nftInfo(dealerNftId);
            expect(dealerEntry).to.equal(correctGuesses);
        });

        it("should fail if called by a non-owner", async function () {
            // Setup: Define the dealerNftId and correctGuesses
            let dealerNftId = FIRST_DEALER_NFT_ID;
            let correctGuesses = 5;

            // Act and Assert: Call the setCorrectGuesses function and expect it to be reverted
            try {
                await aiamond.connect(addr1).setCorrectGuesses(dealerNftId, correctGuesses);
                expect.fail('Expected setCorrectGuesses to revert');
            } catch (err) {
                console.log(err);
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });
    });

    describe("addGuess", function () {

        it("should allow a dealer to add a guess", async function () {
            // Setup: Define the parameters for the guess
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;
            let initialGuessCount = await aiamond.dealerGuessCount(dealer1NftId);

            // Setup: Give the dealer enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, 0, 10, "0x");

            // Act: Call the addGuess function
            await expect(aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                dealer1NftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            ))
                .to.emit(aiamond, "GuessAdded")
                .withArgs(
                    dealerNft1.address,
                    _guessHash,
                    externTokenAddress,
                    _chainId,
                    _timestamp,
                    _initialPrice,
                    0,
                    _neededDeposit
                );

            // Assert: Check that the guess count for the dealer has been decremented
            let finalGuessCount = await aiamond.dealerGuessCount(dealer1NftId);
            expect(finalGuessCount).to.equal(Number(initialGuessCount) + 1);

            // Assert: Check the guess
            let guessId = 0;
            let guess = await aiamond.getGuess(dealer1NftId, guessId);
            expect(guess[0]).to.equal(dealer1NftId);
            expect(guess[1]).to.be.empty; // playersParticipating
            expect(guess[2]).to.be.empty; // playerDeposits
            expect(guess[3]).to.equal(externTokenAddress);
            expect(guess[4]).to.equal(_chainId);
            expect(guess[5]).to.equal(_timestamp);
            expect(guess[6]).to.equal(_guessHash);
            expect(guess[7]).to.equal(_initialPrice);
            expect(guess[8]).to.equal(false);
            expect(guess[9]).to.equal(_neededDeposit);
        });

        it("should allow a dealer to add a guess with a special price", async function () {
            // Setup: Define the parameters for the guess
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;
            let _customGuessPrice = 20; // Define a custom guess price
            await aiamond.connect(owner).setSpecialGuessPrice(dealer1NftId, _customGuessPrice);

            // Setup: Give the dealer enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, CHIPS, _customGuessPrice, "0x");
            let oldOwnerBalance = Number(await aiamond.balanceOf(await aiamond.owner(), CHIPS));

            // Act: Call the addGuess function
            await expect(aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                dealer1NftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            ))
                .to.emit(aiamond, "GuessAdded")
                .withArgs(
                    dealerNft1.address,
                    _guessHash,
                    externTokenAddress,
                    _chainId,
                    _timestamp,
                    _initialPrice,
                    0,
                    _neededDeposit
                );


            // Assert: Check the guess
            let guessId = 0;
            let guess = await aiamond.getGuess(dealer1NftId, guessId);
            expect(guess[0]).to.equal(dealer1NftId);
            expect(guess[1]).to.be.empty; // playersParticipating
            expect(guess[2]).to.be.empty; // playerDeposits
            expect(guess[3]).to.equal(externTokenAddress);
            expect(guess[4]).to.equal(_chainId);
            expect(guess[5]).to.equal(_timestamp);
            expect(guess[6]).to.equal(_guessHash);
            expect(guess[7]).to.equal(_initialPrice);
            expect(guess[8]).to.equal(false);
            expect(guess[9]).to.equal(_neededDeposit);

            // Assert: Check the balance of the owner
            expect(await aiamond.balanceOf(await aiamond.owner(), CHIPS)).to.equal(oldOwnerBalance + _customGuessPrice);

        });

        it("should fail when a dealer tries to add a guess over the limit", async function () {
            // Setup: Define the parameters for the guess
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;
            let maxGuesses = Number(await aiamond.maxGuesses());

            // Setup: Give the dealer enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, CHIPS, dealerGuessPrice * (maxGuesses + 1), "0x");

            // Setup: Add guesses up to the limit
            for (let i = 0; i < maxGuesses; i++) {
                await aiamond.connect(dealerNft1).addGuess(
                    _guessHash,
                    dealer1NftId,
                    externTokenAddress,
                    _chainId,
                    _timestamp,
                    _initialPrice,
                    _neededDeposit
                );
            }

            // Act: Try to add one more guess and expect it to be reverted
            await expect(aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                dealer1NftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            )).to.be.revertedWithCustomError(aiamond, "DealerReachedMaxGuesses");
        });

        it("should fail when a player without a dealer NFT tries to add a guess", async function () {
            // Setup: Define the parameters for the guess
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _nftId = FIRST_DEALER_NFT_ID; // This should be a valid NFT ID owned by the dealer
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;

            // Act: Call the addGuess function with a player who doesn't own a dealer NFT
            await expect(
                aiamond.connect(playerNft1).addGuess(
                    _guessHash,
                    _nftId,
                    externTokenAddress,
                    _chainId,
                    _timestamp,
                    _initialPrice,
                    _neededDeposit
                )
            ).to.be.revertedWithCustomError(aiamond, "OnlyDealerNftOwnersCanGuess"); // Assert: Check the failure message
        });
    });

    describe("revealGuessToPlayer", function () {
        it("should allow a player to reveal a guess", async function () {

            // Setup: Define the _nftId, _guessId and CHIPS
            let CHIPS = 0; // Assuming that the CHIPS token has an ID of 0
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;

            // Setup: Give the player enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, playerNft1.address, CHIPS, playerRevealPrice + _neededDeposit, "0x");

            // Setup: Give the dealer enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, CHIPS, dealerGuessPrice, "0x");

            let oldOwnerBalance = Number(await aiamond.balanceOf(await aiamond.owner(), CHIPS));

            // Setup: Add a guess to the NFT
            await aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                dealer1NftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            );

            let _guessId = await aiamond.getGuessId(dealer1NftId);

            // Act: Call the revealGuessToPlayer function
            await expect(aiamond.connect(playerNft1).revealGuessToPlayer(player1NftId, dealer1NftId, _guessId))
                .to.emit(aiamond, "GuessRevealedToPlayer")
                .withArgs(
                    player1NftId,
                    _guessId,
                    dealer1NftId,
                    externTokenAddress,
                    _chainId,
                    _timestamp,
                    _initialPrice,
                    _neededDeposit
                );

            // Assert: Check the guess
            let guess = await aiamond.getGuess(dealer1NftId, _guessId);
            expect(guess[1].map(Number)).to.include(player1NftId);
            expect(Number(guess[2][guess[1].map(Number).indexOf(player1NftId)])).to.equal(_neededDeposit);

            // Assert: Check the balance of the contract
            expect(await aiamond.balanceOf(aiamondAddress, CHIPS)).to.equal(_neededDeposit);

            // Assert: Check the balance of the owner
            expect(await aiamond.balanceOf(await aiamond.owner(), CHIPS)).to.equal(oldOwnerBalance + playerRevealPrice + dealerGuessPrice);
        });

        it("should allow a player to reveal a guess with a custom price", async function () {

            // Setup: Define the _nftId, _guessId and CHIPS
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;
            let _customRevealPrice = 20; // Define a custom reveal price
            await aiamond.connect(owner).setSpecialRevealPrice(dealer1NftId, _customRevealPrice);

            // Setup: Give the player enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, playerNft1.address, CHIPS, _customRevealPrice + _neededDeposit, "0x");

            // Setup: Give the dealer enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, CHIPS, dealerGuessPrice, "0x");

            // Setup: Add a guess to the NFT
            await aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                dealer1NftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            );

            let _guessId = await aiamond.getGuessId(dealer1NftId);

            let oldOwnerBalance = Number(await aiamond.balanceOf(await aiamond.owner(), CHIPS));

            // Act: Call the revealGuessToPlayer function
            await expect(aiamond.connect(playerNft1).revealGuessToPlayer(player1NftId, dealer1NftId, _guessId))
                .to.emit(aiamond, "GuessRevealedToPlayer")
                .withArgs(
                    player1NftId,
                    _guessId,
                    dealer1NftId,
                    externTokenAddress,
                    _chainId,
                    _timestamp,
                    _initialPrice,
                    _neededDeposit
                );

            // Assert: Check the guess
            let guess = await aiamond.getGuess(dealer1NftId, _guessId);
            expect(guess[1].map(Number)).to.include(player1NftId);
            expect(Number(guess[2][guess[1].map(Number).indexOf(player1NftId)])).to.equal(_neededDeposit);

            // Assert: Check the balance of the contract
            expect(await aiamond.balanceOf(aiamondAddress, CHIPS)).to.equal(_neededDeposit);

            // Assert: Check the balance of the owner
            expect(await aiamond.balanceOf(await aiamond.owner(), CHIPS)).to.equal(oldOwnerBalance + _customRevealPrice);
        });

        it("should fail when the player does not have enough tokens to cover the reveal price", async function () {

            // Setup: Define the _nftId, _guessId and CHIPS
            let CHIPS = 0; // Assuming that the CHIPS token has an ID of 0
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;
            let _customRevealPrice = 20; // Define a custom reveal price
            await aiamond.connect(owner).setSpecialRevealPrice(dealer1NftId, _customRevealPrice);

            // Setup: Give the player not enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, playerNft1.address, CHIPS, _customRevealPrice - 1, "0x");

            // Setup: Give the dealer enough CHIPS tokens
            await aiamond.connect(owner).safeTransferFrom(owner.address, dealerNft1.address, CHIPS, dealerGuessPrice, "0x");

            // Setup: Add a guess to the NFT
            await aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                dealer1NftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            );

            let _guessId = await aiamond.getGuessId(dealer1NftId);

            // Act: Call the revealGuessToPlayer function and expect it to be reverted
            await expect(aiamond.connect(playerNft1).revealGuessToPlayer(player1NftId, dealer1NftId, _guessId))
                .to.be.revertedWithCustomError(aiamond, "NotEnoughTokensToRevealAndDeposit");
        });
    });

    describe("mintDealer", function () {
        it("should mint a dealer token", async function () {
            // Arrange: Set the value to the dealerNFTPrice
            const value = ethers.parseEther("0.001"); // replace with your dealerNFTPrice

            // Act: Call the mintDealer function
            await aiamond.connect(dealerNft1).mintDealer({ value });

            // Assert: Check that the dealer now owns the last minted token
            let lastTokenId = await aiamond.lastUsedDealerTokenId();
            await expect(await aiamond.balanceOf(dealerNft1, lastTokenId)).to.equal(1);
        });

        it("should mint 11th DEALER NFT with new price", async function () {
            // Arrange: Set the value to the dealerNFTPrice
            let value = ethers.parseEther("0.001"); // replace with your dealerNFTPrice

            // Mint 10 token
            let lastTokenId = Number(await aiamond.lastUsedDealerTokenId());
            for (let i = lastTokenId; i <= FIRST_DEALER_NFT_ID + 9; i++) {
                await aiamond.connect(dealerNft1).mintDealer({ value });
                let lastTokenId = await aiamond.lastUsedDealerTokenId();
                await expect(await aiamond.balanceOf(dealerNft1, lastTokenId)).to.equal(1);
            }
            lastTokenId = Number(await aiamond.lastUsedDealerTokenId());

            // After 10 NFT minted, the price should be increased (2 have been minted in beforeEach)
            await expect(
                aiamond.connect(dealerNft1).mintDealer({ value })
            ).to.be.revertedWithCustomError(aiamond, "NotEnoughEtherForMinting");
            await expect(await aiamond.balanceOf(dealerNft1, lastTokenId + 1)).to.equal(0);

            await aiamond.connect(dealerNft1).mintDealer({ value: ethers.parseEther("0.002") });
            await expect(await aiamond.balanceOf(dealerNft1, lastTokenId + 1)).to.equal(1);
        });

        it("should fail when all dealer tokens have been minted", async function () {

            // Arrange: Mint all dealer tokens
            for (let i = (await aiamond.lastUsedDealerTokenId()) + BigInt(1); i <= LAST_DEALER_NFT_ID; i++) {
                await aiamond.connect(owner).mintDealer(); // owner can mint for free
            }

            /*
            for (let i = 0; i <= 110; i++) {
                for (let account of [owner, dealerNft1, dealerNft2, playerNft1, playerNft2]) {
                    let balance = await aiamond.balanceOf(account, i);
                    if (balance > 0) {
                        console.log(`Token ID: ${i}, Owner: ${account.address}, Balance: ${balance.toString()}`);
                    }
                }
            }
            */

            // Act & Assert: Attempt to mint one more dealer token and expect it to fail
            await expect(
                aiamond.connect(dealerNft1).mintDealer({ value: (await aiamond.dealerNFTPrice()).toString() })
            ).to.be.revertedWithCustomError(aiamond, "AllDealerTokensMinted");
        });

        it("should fail at the 10th DEALER NFT because the price went up", async function () {
            let value = ethers.parseEther("0.001"); // replace with your dealerNFTPrice

            // Arrange: Mint 10 dealer tokens
            let lastTokenId = Number(await aiamond.lastUsedDealerTokenId());
            for (let i = lastTokenId; i <= FIRST_DEALER_NFT_ID + 9; i++) {
                await aiamond.connect(dealerNft1).mintDealer({ value });
                let lastTokenId = await aiamond.lastUsedDealerTokenId();
                await expect(await aiamond.balanceOf(dealerNft1, lastTokenId)).to.equal(1);
            }
            lastTokenId = Number(await aiamond.lastUsedDealerTokenId());

            // Act & Assert: Attempt to mint one more dealer token and expect it to fail because of the new price
            await expect(
                aiamond.connect(dealerNft1).mintDealer({ value: ethers.parseEther("0.001") })
            ).to.be.revertedWithCustomError(aiamond, "NotEnoughEtherForMinting");

        });

    });

    describe("mintPlayer", function () {
        it("should mint a player token", async function () {
            // Arrange: Set the value to the playerNFTPrice
            const value = ethers.parseEther("0.0001"); // replace with your playerNFTPrice
            let tokenIdBefore = await aiamond.lastUsedPlayerTokenId();

            // Act: Call the mintPlayer function
            await aiamond.connect(playerNft1).mintPlayer({ value });

            // Assert: Check that the player now owns the last minted token
            let lastTokenId = await aiamond.lastUsedPlayerTokenId();
            await expect(await aiamond.balanceOf(playerNft1, lastTokenId)).to.equal(1);

            // Assert: Check that the lastUsedPlayerTokenId has been incremented
            await expect(lastTokenId).to.equal(tokenIdBefore + BigInt(1));
        });

        it("should fail when all player tokens have been minted", async function () {
            // Arrange: Set lastUsedPlayerTokenId to a high number, the minting would take too long
            await aiamond.setLastPlayerTokenId(LAST_PLAYER_NFT_ID - 100, { from: owner });

            // Arrange: Mint all player tokens
            let alreadyMinted = Number(await aiamond.lastUsedPlayerTokenId());
            const batchSize = 400; // Adjust this number based on what your environment can handle

            for (let i = alreadyMinted + 1; i <= LAST_PLAYER_NFT_ID; i += batchSize) {
                const batchEnd = Math.min(i + batchSize - 1, LAST_PLAYER_NFT_ID);
                const ids = Array.from({ length: batchEnd - i + 1 }, (_, j) => j + i);
                const amounts = Array(ids.length).fill(1);
                await aiamond.connect(owner).mintBatch(owner.address, ids, amounts, "0x", { gasLimit: 30000000 });
            }

            // Act & Assert: Attempt to mint one more player token and expect it to fail
            await expect(
                aiamond.connect(playerNft1).mintPlayer({ value: (await aiamond.playerNFTPrice()).toString() })
            ).to.be.revertedWithCustomError(aiamond, "AllPlayerTokensMinted");
        });
    });

    describe("setLastIds", function () {
        it("should allow owner to set lastUsedDealerTokenId", async () => {
            const newId = 10;
            await aiamond.connect(owner).setLastDealerTokenId(newId);
            assert.equal(parseInt(await aiamond.lastUsedDealerTokenId()), newId, "lastUsedDealerTokenId was not set correctly");
        });

        it("should allow owner to set lastUsedPlayerTokenId", async () => {
            const newId = 20;
            await aiamond.connect(owner).setLastPlayerTokenId(newId);
            assert.equal(parseInt(await aiamond.lastUsedPlayerTokenId()), newId, "lastUsedPlayerTokenId was not set correctly");
        });

        it("should not allow non-owner to set lastUsedDealerTokenId", async () => {
            const newId = 30;
            try {
                await aiamond.connect(addr1).setLastDealerTokenId(newId);
                assert.fail("Expected revert not received");
            } catch (error) {
                const revertFound = error.message.search('revert') >= 0;
                assert(revertFound, `Expected "revert", got ${error} instead`);
            }
        });

        it("should not allow non-owner to set lastUsedPlayerTokenId", async () => {
            const newId = 40;
            try {
                await aiamond.connect(addr1).setLastPlayerTokenId(newId);
                assert.fail("Expected revert not received");
            } catch (error) {
                const revertFound = error.message.search('revert') >= 0;
                assert(revertFound, `Expected "revert", got ${error} instead`);
            }
        });

        it("Should set the last dealer NFT ID if the owner calls the function", async function () {
            await aiamond.setLastDealerNftId(200);
            expect(await aiamond.lastDealerNftId()).to.equal(200);
        });

        it("Should set the last player NFT ID if the owner calls the function", async function () {
            await aiamond.setLastPlayerNftId(300);
            expect(await aiamond.lastPlayerNftId()).to.equal(300);
        });

        it("Should fail if someone other than the owner tries to set the last dealer NFT ID", async function () {
            try {
                await aiamond.connect(addr1).setLastDealerNftId(200);
                expect.fail('Expected setLastPlayerNftId to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });

        it("Should fail if someone other than the owner tries to set the last player NFT ID", async function () {
            try {
                await aiamond.connect(addr1).setLastPlayerNftId(300);
                expect.fail('Expected setLastPlayerNftId to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });

        it("Should set a special reveal price if the owner calls the function", async function () {
            await aiamond.connect(owner).setSpecialRevealPrice(1, 20);
            expect(await aiamond.getRevealPrice(1)).to.equal(20);
        });

        it("Should fail if someone other than the owner tries to set a special reveal price", async function () {
            try {
                await aiamond.connect(addr1).setSpecialRevealPrice(1, 20);
                expect.fail('Expected setSpecialRevealPrice to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });

        it("Should set a special guess price if the owner calls the function", async function () {
            await aiamond.connect(owner).setSpecialGuessPrice(1, 20);
            expect(await aiamond.getGuessPrice(1)).to.equal(20);
        });

        it("Should fail if someone other than the owner tries to set a special guess price", async function () {
            try {
                await aiamond.connect(addr1).setSpecialGuessPrice(1, 20);
                expect.fail('Expected setSpecialGuessPrice to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });

        it("should allow the owner to set a new limit for guesses", async function () {
            // Setup: Define a new limit
            let maxGuesses = Number(await aiamond.maxGuesses());
            let newLimit = maxGuesses + 5;

            // Act: Set the new limit
            await aiamond.connect(owner).setMaxGuesses(newLimit);

            // Assert: Check that the new limit has been set
            expect(await aiamond.maxGuesses()).to.equal(newLimit);
        });

        it("Should fail if someone other than the owner tries to set a new limit for guesses", async function () {
            try {
                await aiamond.connect(addr1).setMaxGuesses(20);
                expect.fail('Expected setMaxGuesses to revert');
            } catch (err) {
                expect(err.message).to.include('OwnableUnauthorizedAccount');
            }
        });
    });
});