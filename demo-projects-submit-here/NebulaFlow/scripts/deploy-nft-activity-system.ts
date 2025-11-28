import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 注意：NFT Activity Factory 需要 ActivityRegistry 地址
  // 这里假设 ActivityRegistry 已经部署，地址为：
  const ACTIVITY_REGISTRY_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // 需要根据实际部署更新

  // 1. 部署 NFTActivityFactory
  console.log("\n1. 部署 NFTActivityFactory...");
  const NFTActivityFactory = await ethers.getContractFactory("NFTActivityFactory");
  const nftActivityFactory = await NFTActivityFactory.deploy(ACTIVITY_REGISTRY_ADDRESS);
  await nftActivityFactory.waitForDeployment();
  const factoryAddress = await nftActivityFactory.getAddress();
  console.log("NFTActivityFactory 地址:", factoryAddress);

  console.log("\n✅ NFT 活动系统部署完成！");
  console.log("\n请更新前端配置中的以下地址：");
  console.log(`NFT_ACTIVITY_FACTORY_ADDRESS = "${factoryAddress}"`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

