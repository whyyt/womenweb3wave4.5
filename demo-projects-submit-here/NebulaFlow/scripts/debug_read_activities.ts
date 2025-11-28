import { ethers } from "hardhat";
import { ACTIVITY_REGISTRY_ABI, ACTIVITY_FACTORY_ABI } from "../client/lib/activityRegistry";

// 请更新为最新部署的合约地址
const ACTIVITY_FACTORY_ADDRESS = "0xb9bEECD1A582768711dE1EE7B0A1d582D9d72a6C";
const ACTIVITY_REGISTRY_ADDRESS = "0x2a810409872AfC346F9B5b26571Fd6eC42EA4849";

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("=== 调试脚本：读取链上活动数据 ===");
  console.log("部署账户:", signer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(signer.address)), "ETH");

  console.log("\n=== 合约地址验证 ===");
  console.log("ActivityFactory 地址:", ACTIVITY_FACTORY_ADDRESS);
  console.log("ActivityRegistry 地址:", ACTIVITY_REGISTRY_ADDRESS);

  const factory = await ethers.getContractAt("ActivityFactory", ACTIVITY_FACTORY_ADDRESS, signer);
  const registry = await ethers.getContractAt("ActivityRegistry", ACTIVITY_REGISTRY_ADDRESS, signer);

  // 验证工厂合约是否正确初始化了 registry
  const factoryRegistryAddr = await factory.activityRegistry();
  console.log("\n=== ActivityFactory 初始化验证 ===");
  console.log("factory.activityRegistry:", factoryRegistryAddr);
  
  if (factoryRegistryAddr === ACTIVITY_REGISTRY_ADDRESS) {
    console.log("✅ ActivityFactory 合约验证通过");
  } else {
    console.error("❌ ActivityFactory 合约初始化错误！");
    console.error("  - 预期 activityRegistry:", ACTIVITY_REGISTRY_ADDRESS, "实际:", factoryRegistryAddr);
  }

  // 读取活动总数
  console.log("\n=== 读取活动总数 ===");
  const activityCount = await registry.activityCount();
  console.log("ActivityRegistry.activityCount:", activityCount.toString());
  console.log("活动总数（数字）:", Number(activityCount));

  if (activityCount === 0n) {
    console.log("⚠️  链上暂无活动");
    return;
  }

  // 读取每个活动的完整结构
  console.log("\n=== 读取活动详情 ===");
  console.log("⚠️  注意：activityId 从 1 开始，不是从 0 开始！");
  
  for (let i = 1; i <= Number(activityCount); i++) {
    console.log(`\n--- 活动 ID ${i} ---`);
    try {
      const metadata = await registry.getActivityMetadataTuple(BigInt(i));
      console.log("活动合约地址:", metadata[0]);
      console.log("创建者:", metadata[1]);
      console.log("标题:", metadata[2]);
      console.log("描述:", metadata[3]);
      console.log("创建时间:", metadata[4].toString(), `(${new Date(Number(metadata[4]) * 1000).toLocaleString()})`);
      console.log("是否公开:", metadata[5]);
      console.log("激励类型:", metadata[6].toString(), "(押金池)");
      
      // 验证活动合约是否存在
      const code = await ethers.provider.getCode(metadata[0]);
      if (code === "0x") {
        console.error("❌ 活动合约地址无效（无代码）");
      } else {
        console.log("✅ 活动合约地址有效（有代码）");
      }
    } catch (err: any) {
      console.error(`❌ 读取活动 ID ${i} 失败:`, err.message);
    }
  }

  // 读取 Factory 中的活动列表
  console.log("\n=== 读取 ActivityFactory 中的活动列表 ===");
  const factoryActivities = await factory.getAllActivities();
  console.log("Factory 活动数量:", factoryActivities.length);
  factoryActivities.forEach((addr, index) => {
    console.log(`  [${index}] ${addr}`);
  });

  console.log("\n=== 调试脚本完成 ===");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
