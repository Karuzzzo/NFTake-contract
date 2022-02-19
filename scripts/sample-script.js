const hre = require("hardhat");

// const address_handler = require("./utils/address_handler");
// const {Aave_lending_pool_v2_provider, Uniswap, Comptroller, SomeDude} = require("./consts/consts");

async function main() {
    const Uniswap_factory = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
    const [deployer] = await ethers.getSigners();

    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );

    // console.log("Account balance:", (await deployer.getBalance()).toString());


    const EmptyFlashloan = await hre.ethers.getContractFactory("NFTake");
    const flashloan = await EmptyFlashloan
    // .connect(signer)
    .deploy();

    await flashloan.deployed();
    // address_handler.write_deployed_addr(flashloan.address);
    console.log("Flashloan deployed to:", flashloan.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
