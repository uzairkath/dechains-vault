require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    compilers: [{ version: "0.8.20" }, { version: "0.7.0" }],
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_RPC_URL,
        blockNumber: 21137094,
      },
      chainId: 1,
    },
  },
};
