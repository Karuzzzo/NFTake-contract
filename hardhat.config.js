require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    networks: {
        hardhat: {
          chainId: 1,
          forking: {
            url: "https://eth-mainnet.alchemyapi.io/v2/" + process.env.PRIVATE_NODE_KEY, // url to RPC node, ${PRIVATE_NODE_KEY} - must be your API key
            // accounts: [DEFAULT_HARDHAT_ACCOUNT, process.env.MAIN_BOT_PRIVATE_KEY],
            // blockNumber: 13971397-1, // a specific block number which you want to work
          },
        },
        localhost: {
          url: "http://127.0.0.1:8545",
        //   accounts: [DEFAULT_HARDHAT_ACCOUNT, process.env.MAIN_BOT_PRIVATE_KEY],
        },
        mainnet: {
            url: "https://eth-mainnet.alchemyapi.io/v2/" + process.env.PRIVATE_NODE_KEY, // url to RPC node, ${PRIVATE_NODE_KEY} - must be your API key
            // accounts: [process.env.MAIN_BOT_PRIVATE_KEY],
            gasPrice: 100000000000, // 100 Gwei
        },
        kovan: {
            url: "https://eth-kovan.alchemyapi.io/v2/" + process.env.PRIVATE_NODE_KEY,
            // accounts: [process.env.MAIN_BOT_PRIVATE_KEY],
        },
        rinkeby: {
          url: "https://rinkeby.infura.io/v3/" + process.env.PRIVATE_NODE_KEY,
          accounts: [process.env.MAIN_BOT_PRIVATE_KEY],

        }
    },
  solidity: "0.8.4",
};
