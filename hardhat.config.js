require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { ethers } = require("ethers");

module.exports = {
  defaultNetwork: "hardhat",
  gasPrice: 0,
  gas: "0x1ffffffffffffe",
  networks: {
    hardhat: {
      blockGasLimit: 10000000,
      mining: {
        auto: true,
      },
      // accounts: {
      //   count: 1000,
      //   accountsBalance: ethers.utils.parseUnits("10000", "ether").toString(),
      // },
    },
    ganache: {
      url: "http://127.0.0.1:8545",
      accounts: [
        `0x1931607ecb0dbbaf4f9a2eb1a9afcf35d89558f350b886c0cfe86f2007dec198`,
        `0x4159c009508ff0815e87637c11d950313de0b7bdb1928af3a505c0e764abfb1e`,
        `0x366bd023c9169d63db5c88a92555019643ee8d3527b6a955ef2b33e8812c81e1`,
      ],
      network_id: "*",
    },
  },
  solidity: {
    version: "0.8.20",
    settings: {
      // evmVersion: "london",
      optimizer: {
        enabled: true,
        runs: 200,
        // details: {
        //   yul: true,
        // },
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
  ignition: {
    requiredConfirmations: 1,
  },
};
