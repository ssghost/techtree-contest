import { ethers } from "hardhat";
import type { ContractTransactionReceipt } from "ethers";

type GasReportItem = {
  functionName: string;
  gasUsed: number;
};

const calculateTotalGasUsed = (gasReport: GasReportItem[]): number => {
  return gasReport.reduce((total, item) => total + item.gasUsed, 0);
};

async function main() {
  const gasReport: GasReportItem[] = [];

  const [user, beneficiary] = await ethers.getSigners();

  const DeadMansSwitch = await ethers.getContractFactory("DeadMansSwitch");
  const contract = await DeadMansSwitch.deploy();
  await contract.waitForDeployment();

  const recordGas = async (functionName: string, txPromise: Promise<any>) => {
    const tx = await txPromise;
    const receipt = (await tx.wait()) as ContractTransactionReceipt;
    gasReport.push({
      functionName,
      gasUsed: Number(receipt.gasUsed),
    });
  };

  await recordGas(
    "deposit",
    contract.connect(user).deposit({
      value: ethers.parseEther("1"),
    }),
  );

  await recordGas("setCheckInInterval", contract.connect(user).setCheckInInterval(3600));
  await recordGas("addBeneficiary", contract.connect(user).addBeneficiary(await beneficiary.getAddress()));
  await recordGas("checkIn", contract.connect(user).checkIn());
  await ethers.provider.send("evm_increaseTime", [7200]);
  await ethers.provider.send("evm_mine", []);
  await recordGas("withdraw_as_beneficiary", contract.connect(beneficiary).withdraw(await user.getAddress(), ethers.parseEther("0.5")));

  const totalGasUsed = calculateTotalGasUsed(gasReport);

  console.log("Gas Report:");
  gasReport.forEach(item => {
    console.log(`${item.functionName}: ${item.gasUsed}`);
  });

  console.log("\nTotal Gas Used:", totalGasUsed);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
