const { ethers } = require("hardhat")

async function main() {
    const Aiamond = await ethers.getContractFactory("Aiamond");

    [owner, ...addrs] = await ethers.getSigners();

    const aiamond = await Aiamond.deploy(owner.address).catch(console.error);

    await aiamond.waitForDeployment();

    const txHash = aiamond.deployTransaction.hash;
    const txReceipt = await ethers.provider.waitForTransaction(txHash);
    console.log("Contract deployed to address:", txReceipt.contractAddress);

    
    aiamondAddress = await aiamond.getAddress();
    console.log("Aiamond deployed to:", aiamondAddress);
 }
 
 main()
 .then(() => process.exit(0))
 .catch((error) => {
     process.exit(1);
 });