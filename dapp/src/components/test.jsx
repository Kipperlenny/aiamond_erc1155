'use client'

import { useState, useEffect } from 'react';

import { BrowserProvider, Contract, formatUnits } from 'ethers';
import { useWeb3ModalProvider, useWeb3ModalAccount } from '@web3modal/ethers/react'
import Aiamond from '@smart/artifacts/contracts/Aiamond.sol/Aiamond.json';

let provider;

const USDTAddress = '0x617f3112bf5397D0467D315cC709EF968D9ba546'

// The ERC-20 Contract ABI, which is a common contract interface
// for tokens (this is the Human-Readable ABI format)
const USDTAbi = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function balanceOf(address) view returns (uint)',
  'function transfer(address to, uint amount)',
  'event Transfer(address indexed from, address indexed to, uint amount)'
]

function Components() {
  const { address, chainId, isConnected } = useWeb3ModalAccount()
  const { walletProvider } = useWeb3ModalProvider()

  async function getBalance() {
    if (!isConnected) throw Error('User disconnected')

    const ethersProvider = new BrowserProvider(walletProvider)
    const signer = await ethersProvider.getSigner()
    // The Contract object
    const USDTContract = new Contract(USDTAddress, USDTAbi, signer)
    const USDTBalance = await USDTContract.balanceOf(address)

    console.log(formatUnits(USDTBalance, 18))
  }

  return <button onClick={getBalance}>Get User Balance</button>
}

async function getEthProvider() {
  provider = new BrowserProvider(window.ethereum);
}

async function getBlockNumber() {
  if (!provider) {
    await getEthProvider();
  }
  return await provider.getBlockNumber();
}

async function getTotalSupply() {
  const contract = new Contract(
    "0x5fbdb2315678afecb367f032d93f642f64180aa3", 
    Aiamond.abi, 
    provider
  );

  const totalSupply = await contract.totalSupply();

  return totalSupply.toString();
}

const Test = () => {
  const { address, chainId, isConnected } = useWeb3ModalAccount();
  const [blockNumber, setBlockNumber] = useState(null);
  const [totalSupply, setTotalSupply] = useState(null);

  useEffect(() => {
    if (isConnected) {
      getBlockNumber().then(setBlockNumber);
      getTotalSupply().then(setTotalSupply);
    }
  }, [isConnected]);

  if (!isConnected) {
    return <w3m-button />;
  } else {
    return (
      <div>
        <p>Connected to the local Hardhat network. Current block number is {blockNumber}.</p>
        <p>Total CHIPS supply of Aiamond is {totalSupply}.</p>
      </div>
    );
  }
}

export { Test };