// 【FIX deposit create revert】调试脚本：测试押金模式创建活动
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("部署账户:", signer.address);
  console.log("账户余额:", ethers.formatEther(await ethers.provider.getBalance(signer.address)), "ETH");

  // 使用最新部署的 ActivityFactory 地址
  const factoryAddr = "0x95401dc811bb5740090279Ba06cfA8fcF6113778";
  console.log("\n使用 ActivityFactory 地址:", factoryAddr);

  const factory = await ethers.getContractAt("ActivityFactory", factoryAddr, signer);

  // 测试参数
  const title = "测试押金挑战";
  const description = "这是一个测试押金挑战活动";
  const depositAmount = ethers.parseEther("0.01"); // 0.01 ETH
  const totalRounds = 7;
  const maxParticipants = 10;
  const isPublic = true;

  console.log("\n=== 测试参数 ===");
  console.log("title:", title);
  console.log("description:", description);
  console.log("depositAmount:", ethers.formatEther(depositAmount), "ETH");
  console.log("totalRounds:", totalRounds);
  console.log("maxParticipants:", maxParticipants);
  console.log("isPublic:", isPublic);

  try {
    console.log("\n=== 调用 createDepositChallenge ===");
    const tx = await factory.createDepositChallenge(
      title,
      description,
      depositAmount,
      totalRounds,
      maxParticipants,
      isPublic
    );
    console.log("✅ 交易已提交，hash:", tx.hash);
    
    const receipt = await tx.wait();
    console.log("✅ 交易已确认，区块号:", receipt?.blockNumber);
    
    // 解析事件
    const event = receipt?.logs.find((log: any) => {
      try {
        const parsed = factory.interface.parseLog(log);
        return parsed?.name === "DepositChallengeCreated";
      } catch {
        return false;
      }
    });
    
    if (event) {
      const parsed = factory.interface.parseLog(event);
      console.log("✅ 事件解析成功:");
      console.log("  - challengeAddress:", parsed?.args[0]);
      console.log("  - creator:", parsed?.args[1]);
      console.log("  - activityId:", parsed?.args[2].toString());
      console.log("  - title:", parsed?.args[3]);
    }
    
    console.log("\n✅ createDepositChallenge 成功！");
  } catch (e: any) {
    console.error("\n❌ createDepositChallenge revert:");
    console.error("错误信息:", e.message);
    if (e.reason) {
      console.error("Revert reason:", e.reason);
    }
    if (e.data) {
      console.error("Error data:", e.data);
    }
    throw e;
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

