import { ethers } from "hardhat";

async function main() {
  const address = process.env.CONTRACT_ADDRESS || "0x67d269191c92Caf3cD7723F116c85e6E9bf55933";
  
  console.log("检查合约地址:", address);
  
  try {
    const code = await ethers.provider.getCode(address);
    console.log("\n合约代码长度:", code.length);
    console.log("是否有代码:", code !== "0x" && code.length > 2);
    
    if (code === "0x" || code.length <= 2) {
      console.log("\n❌ 该地址没有部署合约或合约代码为空");
      console.log("请重新部署合约。");
      process.exit(1);
    }
    
    // 尝试读取 ActivityFactory 的 activityRegistry 字段
    try {
      const factory = await ethers.getContractAt("ActivityFactory", address);
      const registryAddress = await factory.activityRegistry();
      
      console.log("\n✅ 合约是 ActivityFactory");
      console.log("ActivityRegistry 地址:", registryAddress);
      
      if (registryAddress === "0x0000000000000000000000000000000000000000") {
        console.log("\n❌ ActivityRegistry 地址为零，合约未正确初始化！");
        console.log("请重新部署合约。");
        process.exit(1);
      } else {
        console.log("\n✅ ActivityFactory 已正确初始化 ActivityRegistry");
      }
    } catch (error: any) {
      console.log("\n❌ 该地址不是有效的 ActivityFactory 合约");
      console.log("错误:", error.message);
      console.log("\n请重新部署合约。");
      process.exit(1);
    }
  } catch (error: any) {
    console.error("\n❌ 检查失败:", error.message);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


