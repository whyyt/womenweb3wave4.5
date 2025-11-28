import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. 部署 ActivityRegistry
  console.log("\n1. 部署 ActivityRegistry...");
  const ActivityRegistry = await ethers.getContractFactory("ActivityRegistry");
  const activityRegistry = await ActivityRegistry.deploy();
  await activityRegistry.waitForDeployment();
  const registryAddress = await activityRegistry.getAddress();
  console.log("ActivityRegistry 地址:", registryAddress);

  // 2. 部署 ActivityFactory
  console.log("\n2. 部署 ActivityFactory...");
  const ActivityFactory = await ethers.getContractFactory("ActivityFactory");
  const activityFactory = await ActivityFactory.deploy(registryAddress);
  await activityFactory.waitForDeployment();
  const factoryAddress = await activityFactory.getAddress();
  console.log("ActivityFactory 地址:", factoryAddress);

  // 3. 部署 NFTActivityFactory
  console.log("\n3. 部署 NFTActivityFactory...");
  const NFTActivityFactory = await ethers.getContractFactory("NFTActivityFactory");
  const nftActivityFactory = await NFTActivityFactory.deploy(registryAddress);
  await nftActivityFactory.waitForDeployment();
  const nftFactoryAddress = await nftActivityFactory.getAddress();
  console.log("NFTActivityFactory 地址:", nftFactoryAddress);

  console.log("\n✅ 部署完成！");
  console.log("\n请更新前端配置中的以下地址：");
  console.log(`ACTIVITY_REGISTRY_ADDRESS = "${registryAddress}"`);
  console.log(`ACTIVITY_FACTORY_ADDRESS = "${factoryAddress}"`);
  console.log(`NFT_ACTIVITY_FACTORY_ADDRESS = "${nftFactoryAddress}"`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


