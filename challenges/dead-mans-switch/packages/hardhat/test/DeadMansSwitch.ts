import { expect } from "chai";
import { ethers } from "hardhat";
import { DeadMansSwitch } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("DeadMansSwitch", function () {
  let deadMansSwitch: DeadMansSwitch;
  let user: HardhatEthersSigner;
  let beneficiary: HardhatEthersSigner;
  let otherAccount: HardhatEthersSigner;

  const depositAmount = ethers.parseEther("1");
  const withdrawAmount = ethers.parseEther("0.5");
  const interval = 3600; // 1 hour

  beforeEach(async function () {
    [user, beneficiary, otherAccount] = await ethers.getSigners();

    const deadMansSwitchFactory = await ethers.getContractFactory("DeadMansSwitch");
    deadMansSwitch = (await deadMansSwitchFactory.deploy()) as DeadMansSwitch;
  });

  describe("Deposits", function () {
    it("Should accept deposits via deposit() function", async function () {
      await expect(deadMansSwitch.connect(user).deposit({ value: depositAmount }))
        .to.emit(deadMansSwitch, "Deposit")
        .withArgs(user.address, depositAmount);

      expect(await deadMansSwitch.balanceOf(user.address)).to.equal(depositAmount);
    });

    it("Should accept deposits via receive()", async function () {
      await expect(
        user.sendTransaction({
          to: await deadMansSwitch.getAddress(),
          value: depositAmount,
        }),
      ).to.changeEtherBalances([user, deadMansSwitch], [-depositAmount, depositAmount]);

      expect(await deadMansSwitch.balanceOf(user.address)).to.equal(depositAmount);
    });

    it("Should fail if deposit amount is 0", async function () {
      await expect(deadMansSwitch.connect(user).deposit({ value: 0 })).to.be.revertedWithCustomError(
        deadMansSwitch,
        "InvalidAmount",
      );
    });
  });

  describe("Check-in and Intervals", function () {
    beforeEach(async function () {
      await deadMansSwitch.connect(user).deposit({ value: depositAmount });
    });

    it("Should allow user to set check-in interval", async function () {
      await deadMansSwitch.connect(user).setCheckInInterval(interval);
      expect(await deadMansSwitch.checkInInterval(user.address)).to.equal(interval);
    });

    it("Should allow user to check in", async function () {
      await deadMansSwitch.connect(user).checkIn();
      const latestTime = await time.latest();
      expect(await deadMansSwitch.lastCheckIn(user.address)).to.equal(latestTime);
    });
  });

  describe("Beneficiary Management", function () {
    beforeEach(async function () {
      await deadMansSwitch.connect(user).deposit({ value: depositAmount });
    });

    it("Should allow adding a beneficiary", async function () {
      await expect(deadMansSwitch.connect(user).addBeneficiary(beneficiary.address))
        .to.emit(deadMansSwitch, "BeneficiaryAdded")
        .withArgs(user.address, beneficiary.address);

      expect(await deadMansSwitch.isBeneficiary(user.address, beneficiary.address)).to.equal(true);
    });

    it("Should fail to add self as beneficiary", async function () {
      await expect(deadMansSwitch.connect(user).addBeneficiary(user.address)).to.be.revertedWithCustomError(
        deadMansSwitch,
        "InvalidBeneficiary",
      );
    });

    it("Should allow removing a beneficiary", async function () {
      await deadMansSwitch.connect(user).addBeneficiary(beneficiary.address);

      await expect(deadMansSwitch.connect(user).removeBeneficiary(beneficiary.address))
        .to.emit(deadMansSwitch, "BeneficiaryRemoved")
        .withArgs(user.address, beneficiary.address);

      expect(await deadMansSwitch.isBeneficiary(user.address, beneficiary.address)).to.be.equal(false);
    });

    it("Should fail to remove a beneficiary that is not active", async function () {
      await expect(deadMansSwitch.connect(user).removeBeneficiary(beneficiary.address)).to.be.revertedWithCustomError(
        deadMansSwitch,
        "NotBeneficiary",
      );
    });
  });

  describe("Withdrawals", function () {
    beforeEach(async function () {
      await deadMansSwitch.connect(user).deposit({ value: depositAmount });
      await deadMansSwitch.connect(user).setCheckInInterval(interval);
      await deadMansSwitch.connect(user).checkIn();
      await deadMansSwitch.connect(user).addBeneficiary(beneficiary.address);
    });

    it("Should allow the user to withdraw anytime", async function () {
      await expect(deadMansSwitch.connect(user).withdraw(user.address, withdrawAmount)).to.changeEtherBalances([user,deadMansSwitch],[withdrawAmount,-withdrawAmount]);

      expect(await deadMansSwitch.balanceOf(user.address)).to.equal(depositAmount - withdrawAmount);
    });

    it("Should fail if withdrawal amount is 0", async function () {
      await expect(deadMansSwitch.connect(user).withdraw(user.address, 0)).to.be.revertedWithCustomError(
        deadMansSwitch,
        "InvalidAmount",
      );
    });

    it("Should fail if withdrawal amount exceeds balance", async function () {
      const excessiveAmount = depositAmount + ethers.parseEther("1");
      await expect(deadMansSwitch.connect(user).withdraw(user.address, excessiveAmount)).to.be.revertedWithCustomError(
        deadMansSwitch,
        "InsufficientBalance",
      );
    });

    it("Should fail if beneficiary tries to withdraw before interval expiration", async function () {
      await expect(deadMansSwitch.connect(beneficiary).withdraw(user.address, withdrawAmount)).to.be.revertedWithCustomError(deadMansSwitch,"IntervalNotExceeded");
    });

    it("Should allow beneficiary to withdraw after interval expiration", async function () {
      await time.increase(interval + 1);

      await expect(deadMansSwitch.connect(beneficiary).withdraw(user.address, withdrawAmount)).to.emit(deadMansSwitch, "Withdrawal").withArgs(beneficiary.address, withdrawAmount);

      expect(await deadMansSwitch.balanceOf(user.address)).to.equal(depositAmount - withdrawAmount);
    });

    it("Should fail if non-beneficiary tries to withdraw after interval expiration", async function () {
      await time.increase(interval + 1);
      await expect(deadMansSwitch.connect(otherAccount).withdraw(user.address, withdrawAmount)).to.be.revertedWithCustomError(deadMansSwitch,"NotBeneficiary");
    });
  });
});
