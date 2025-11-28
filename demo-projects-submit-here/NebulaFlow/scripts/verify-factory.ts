import { ethers } from "hardhat";

async function main() {
  // 默认使用最新部署的地址，也可以通过环境变量覆盖
  const factoryAddress = process.env.FACTORY_ADDRESS || "0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44";

  console.log("检查 ActivityFactory 地址:", factoryAddress);
  
  try {
    const factory = await ethers.getContractAt("ActivityFactory", factoryAddress);
    const registryAddress = await factory.activityRegistry();
    
    console.log("\n✅ 验证结果:");
    console.log("ActivityFactory 地址:", factoryAddress);
    console.log("ActivityRegistry 地址:", registryAddress);
    
    if (registryAddress === "0x0000000000000000000000000000000000000000") {
      console.log("\n❌ 错误: ActivityRegistry 地址为零，合约未正确初始化！");
      console.log("请重新部署合约。");
      process.exit(1);
    } else {
      console.log("\n✅ ActivityFactory 已正确初始化 ActivityRegistry");
      console.log("\n请更新前端配置:");
      console.log(`const ACTIVITY_FACTORY_ADDRESS = "${factoryAddress}";`);
    }
  } catch (error: any) {
    console.error("\n❌ 错误:", error.message);
    console.log("\n可能的原因:");
    console.log("1. 地址不是有效的 ActivityFactory 合约");
    console.log("2. 合约代码不匹配");
    console.log("3. 网络连接问题");
    console.log("\n请重新部署合约并使用新地址。");
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

