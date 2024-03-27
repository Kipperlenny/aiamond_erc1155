require("@nomicfoundation/hardhat-toolbox");

require('dotenv').config();

const endpointUrl = process.env.quickNodeEndpoint;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  sourcify: {
    enabled: true
  },
  defaultNetwork: "polygonMumbai",
  networks: {
    polygonMumbai: {
      url: endpointUrl,
      accounts: [process.env.metaMaskPrivateKey],
      network_id: 80001, // change if using a different network other than polygon mainnet
      gasPrice: 40000000000,
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    }
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.polygonMumbaiApiKey,
    },
  },
};
