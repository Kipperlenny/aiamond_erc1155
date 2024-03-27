const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aiamond", function () {
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

    const externTokenAddress = "0xa324175E95Ef225dDCc1852F9F7939D997c0757d";

    beforeEach(async function () {
        Aiamond = await ethers.getContractFactory("Aiamond");
        [owner, addr1, addr2, dealerNft1, dealerNft2, playerNft1, playerNft2, ...addrs] = await ethers.getSigners();
        aiamond = await Aiamond.deploy(owner.address).catch(console.error);
        await aiamond.waitForDeployment();
        aiamondAddress = await aiamond.getAddress();

        // Mint a dealer NFT for the dealer
        let dealer1NftId = 1; // Use any ID in the range 1 - 101
        await aiamond.connect(owner).mint(dealerNft1.address, dealer1NftId, 1, "0x");

        // Mint a dealer NFT for the dealer
        let dealer2NftId = 2; // Use any ID in the range 1 - 101
        await aiamond.connect(owner).mint(dealerNft2.address, dealer2NftId, 1, "0x");

        // Mint a player NFT for the player
        let player1NftId = 102; // Use any ID in the range 102 - 200101
        await aiamond.connect(owner).mint(playerNft1.address, player1NftId, 1, "0x");

        // Mint a player NFT for the player
        let player2NftId = 102; // Use any ID in the range 102 - 200101
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
            await expect(aiamond.withdrawChips()).to.be.revertedWith("No CHIPS to withdraw");
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
            expect(await aiamond.balanceOf(owner.address, 0)).to.equal(1000000); // start balance should equal end (1000000)
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
            expect(await aiamond.balanceOf(owner.address, 0)).to.equal(1000000);
        });
    
        it("should allow the dealer to withdraw from his NFT", async function () {
            // Setup: Define the _nftId and add some balance to it
            let _nftId = 1;
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
            let _nftId = 1;
            aiamond.nftBalances[_nftId] = 100;

            // Act and Assert: Call the withdrawFromNft function and expect it to be reverted
            await expect(aiamond.connect(dealerNft2).withdrawFromNft(_nftId))
                .to.be.revertedWith("NFT does not exist or sender is not the owner");
        });

        it("should fail if there are no funds to withdraw", async function () {
            // Setup: Define the _nftId
            let _nftId = 1;

            // Act and Assert: Call the withdrawFromNft function and expect it to be reverted
            await expect(aiamond.connect(dealerNft1).withdrawFromNft(_nftId))
                .to.be.revertedWith("No funds to withdraw");
        });
    });

    describe("revealPriceForGuess", function () {
        it.only("should reveal the price for a guess", async function () {

            // Setup: Add a guess
            let nftId = 1;
            let guessHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [100, 1]));
            let timestamp = Math.floor(Date.now() / 1000);
            let initialPrice = 100;
            let neededDeposit = 10;
            await aiamond.addGuess(guessHash, nftId, externTokenAddress, timestamp, initialPrice, neededDeposit);

            // Act: Reveal the price for the guess
            let guessId = await aiamond.getGuessId(nftId);
            let endPrice = 100;
            let guessedPrice = 100;
            let nonce = 1;
            let tx = await aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice, nonce);

            // Assert: Check the guess details
            [dealer, tokenAddress, timestamp, guessHash, initialPrice, isPriceRevealed, neededDeposit] = await aiamond.getGuess(nftId, guessId);
            expect(isPriceRevealed).to.equal(true);

            // Assert: Check the event
            let receipt = await tx.wait();
            expect(receipt.events).to.satisfy((events) =>
                events.some((event) =>
                    event.event === "PriceRevealed" &&
                    event.args._dealerNftId === nftId &&
                    event.args._endPrice === endPrice &&
                    event.args._guessedPrice === guessedPrice
                )
            );
        });

        it("should fail if the guess has already been revealed", async function () {
            // Setup: Add a guess and reveal the price
            let nftId = 1;
            let guessHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [100, 1]));
            let timestamp = Math.floor(Date.now() / 1000);
            let initialPrice = 100;
            let neededDeposit = 10;
            await aiamond.addGuess(guessHash, nftId, externTokenAddress, timestamp, initialPrice, neededDeposit);
            let guessId = await aiamond.getGuessId(nftId);
            let endPrice = 100;
            let guessedPrice = 100;
            let nonce = 1;
            await aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice, nonce);

            // Act: Try to reveal the price again
            await expect(aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice, nonce))
                .to.be.revertedWith("Price for this guess has already been revealed");
        });

        it("should fail if the guessed price and nonce do not match the hash", async function () {
            // Setup: Add a guess with a certain hash
            let nftId = 1;
            let guessHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "uint256"], [100, 1]));
            let timestamp = Math.floor(Date.now() / 1000);
            let initialPrice = 100;
            let neededDeposit = 10;
            await aiamond.addGuess(guessHash, nftId, externTokenAddress, timestamp, initialPrice, neededDeposit);

            // Act: Try to reveal the price with a different guessed price and nonce
            let guessId = await aiamond.getGuessId(nftId);
            let endPrice = 100;
            await expect(aiamond.revealPriceForGuess(nftId, guessId, endPrice, guessedPrice + 1, nonce))
                .to.be.revertedWith("Guessed price and nonce do not match the hash");
        });
    });

    describe("setCorrectGuesses", function () {
        it("should set the correctGuesses for a given dealerNftId", async function () {
            // Setup: Define the dealerNftId and correctGuesses
            let dealerNftId = 1;
            let correctGuesses = 5;
    
            // Act: Call the setCorrectGuesses function
            await aiamond.connect(owner).setCorrectGuesses(dealerNftId, correctGuesses);
    
            // Assert: Check the correctGuesses value
            let dealerEntry = await aiamond.nftInfo(dealerNftId);
            expect(dealerEntry.correctGuesses).to.equal(correctGuesses);
        });
    
        it("should fail if called by a non-owner", async function () {
            // Setup: Define the dealerNftId and correctGuesses
            let dealerNftId = 1;
            let correctGuesses = 5;
    
            // Act and Assert: Call the setCorrectGuesses function and expect it to be reverted
            await expect(aiamond.connect(addr1).setCorrectGuesses(dealerNftId, correctGuesses))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("revealGuessToPlayer", function () {
        it("should allow a player to reveal a guess", async function () {
   
            // Setup: Define the _nftId, _guessId and _chipsId
            let _nftId = 1;
            let _guessId = 0;
            let _chipsId = 0; // Assuming that the CHIPS token has an ID of 0
    
            // Setup: Add a guess to the NFT
            aiamond.nftInfo[_nftId].guesses.push({
                tokenAddress: "0xTokenAddress",
                timestamp: Math.floor(Date.now() / 1000),
                initialPrice: ethers.parseEther("1.0"),
                dealer: dealerNft1,
                neededDeposit: 10,
                players: {},
                playersParticipating: []
            });
    
            // Setup: Give the player enough CHIPS tokens
            await aiamond.connect(playerNft1).mint(player.address, _chipsId, ethers.parseEther("1.1"), "0x");
    
            // Act: Call the revealGuessToPlayer function
            await aiamond.connect(owner).revealGuessToPlayer(_nftId, _guessId);
    
            // Assert: Check the guess
            let guess = aiamond.nftInfo[_nftId].guesses[_guessId];
            expect(guess.players[_nftId]).to.equal(10);
            expect(guess.playersParticipating).to.include(_nftId);
    
            // Assert: Check the balance of the contract
            expect(await aiamond.balanceOf(aiamondAddress, _chipsId)).to.equal(10);
    
            // Assert: Check the balance of the owner
            expect(await aiamond.balanceOf(await aiamond.owner(), _chipsId)).to.equal(10);
        });
    });

    describe("addGuess", function () {
        it("should allow a dealer to add a guess", async function () {
            // Setup: Define the parameters for the guess
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _nftId = 1; // This should be a valid NFT ID owned by the dealer
            let _chainId = 1; // Replace with your chain ID
            let _timestamp = Math.floor(Date.now() / 1000);
            let _initialPrice = ethers.parseEther("1.0");
            let _neededDeposit = 10;
    
            // Act: Call the addGuess function
            let tx = await aiamond.connect(dealerNft1).addGuess(
                _guessHash,
                _nftId,
                externTokenAddress,
                _chainId,
                _timestamp,
                _initialPrice,
                _neededDeposit
            );

            // Wait for the transaction to be mined and get the receipt
            let receipt = await tx.wait();

            // Find the GuessAdded event in the receipt
            let event = receipt.events?.find(e => e.event === "GuessAdded");

            // Assert: Check the event
            expect(event).to.not.be.undefined;
            expect(event.args[0]).to.equal(dealerNft1.address);
            expect(event.args[1]).to.equal(_guessHash);
            expect(event.args[2]).to.equal(externTokenAddress);
            expect(event.args[3]).to.equal(_chainId);
            expect(event.args[4]).to.equal(_timestamp);
            expect(event.args[5]).to.equal(_initialPrice);
            expect(event.args[7]).to.equal(_neededDeposit);

            // Assert: Check the guess
            let guessId = event.args[6];
            let guess = await aiamond.guesses(_nftId, guessId);
            expect(guess.dealer).to.equal(_nftId);
            expect(guess.tokenAddress).to.equal(externTokenAddress);
            expect(guess.timestamp).to.equal(_timestamp);
            expect(guess.chainId).to.equal(_chainId);
            expect(guess.guessHash).to.equal(_guessHash);
            expect(guess.initialPrice).to.equal(_initialPrice);
            expect(guess.isPriceRevealed).to.equal(false);
            expect(guess.neededDeposit).to.equal(_neededDeposit);
        });

        it("should fail when a player without a dealer NFT tries to add a guess", async function () {
            // Setup: Define the parameters for the guess
            let _guessHash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            let _nftId = 1; // This should be a valid NFT ID owned by the dealer
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
            ).to.be.revertedWith("Only DEALER NFT owners can make a guess"); // Assert: Check the failure message
        });
    });
});