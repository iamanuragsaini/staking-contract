const { expect } = require("chai");
const hre = require("hardhat");
const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("StakingPool", function () {
  let StakingToken, stakingToken, StakingPool, stakingPool, owner, addr1, addr2;
  async function deployContracts() {
    [owner, addr1, addr2] = await ethers.getSigners();
    StakingToken = await ethers.getContractFactory("Token");
    StakingPool = await ethers.getContractFactory("StakingPool");
    stakingToken = await StakingToken.deploy();
    stakingPool = await StakingPool.deploy();

    return { stakingToken, stakingPool, owner, addr1, addr2 };
  }

  describe("Deployment", async () => {
    it("Should deploy the Token and StakingPool contract", async () => {
      const { stakingToken, stakingPool } = await loadFixture(deployContracts);
      expect(stakingToken.target).to.not.be.null;
      expect(stakingPool.target).to.not.be.null;
      await stakingToken.mint(owner.address, 1000);
      await stakingToken.mint(addr1.address, 1000);
      await stakingToken.mint(addr2.address, 1000);
    });
  });

  describe("Pool creation", async () => {
    it("Should create a staking pool", async () => {
      await stakingToken.approve(stakingPool.target, 1000);
      await stakingPool.createPool(stakingToken.target, 1000, 30, 7);
      expect(await stakingPool.poolStarted()).to.equal(true);
      expect(await stakingPool.totalDistributionAmount()).to.equal(1000);
    });

    it("Should revert if pool is already created", async function () {
      await stakingToken.approve(stakingPool.target, 1000);
      await stakingPool.createPool(stakingToken.target, 1000, 30, 7);
      await expect(
        stakingPool.createPool(stakingToken.target, 1000, 30, 7)
      ).to.be.revertedWith("Pool already created");
    });
  });

  describe("Staking", function () {
    it("Should allow users to stake tokens", async function () {
      await stakingToken.connect(addr1).approve(stakingPool.target, 100);
      await stakingPool.connect(addr1).stake(100);
      const stakerId = await stakingPool.getStakerId(addr1.address);
      const stakerDetails = await stakingPool.getStakerDetailsById(stakerId);
      expect(stakerDetails[0]).to.equal(100);
    });

    it("Should revert if staking amount is zero", async function () {
      await stakingToken.connect(addr1).approve(stakingPool.target, 100);
      await expect(stakingPool.connect(addr1).stake(0)).to.be.revertedWith(
        "Amount should be greater than zero"
      );
    });
  });

  describe("Unstaking", function () {
    it("Should revert if lock-in period is not completed", async function () {
      const stakerId = await stakingPool.getStakerId(addr1.address);
      await expect(
        stakingPool.connect(addr1).unstake(stakerId)
      ).to.be.revertedWith("Lock-in duration not completed");
    });

    it("Should allow users to unstake tokens after lock-in period", async function () {
      const stakerId = await stakingPool.getStakerId(addr1.address);
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);
      await stakingPool.connect(addr1).unstake(stakerId);
      const stakerDetails = await stakingPool.getStakerDetailsById(stakerId);
      expect(stakerDetails[0]).to.equal(0);
    });
  });

  describe("Rewards", function () {
    beforeEach(async function () {
      await stakingToken.approve(stakingPool.target, 1000);
      await stakingPool.createPool(stakingToken.target, 1000, 30, 7);
      await stakingToken.connect(addr1).approve(stakingPool.target, 100);
      await stakingPool.connect(addr1).stake(100);
      await ethers.provider.send("evm_increaseTime", [15 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);
    });

    it("Should revert if no rewards to claim", async function () {
      const stakerId = await stakingPool.getStakerId(addr1.address);
      await stakingPool.connect(addr1).claimRewards(stakerId);
      await expect(
        stakingPool.connect(addr1).claimRewards(stakerId)
      ).to.be.revertedWith("No rewards to claim");
    });

    it("Should calculate and claim rewards", async function () {
      const stakerId = await stakingPool.getStakerId(addr1.address);
      await stakingPool.connect(addr1).claimRewards(stakerId);
      const stakerDetails = await stakingPool.getStakerDetailsById(stakerId);
      expect(stakerDetails[4]).to.equal(0);
    });   
  });

  describe("View Functions", function () {
   it("Should return total pool amount left", async function () {
      const totalLeft = await stakingPool.totalPoolAmountLeft();
      expect(totalLeft).to.equal(1000);
    })
    it("Should return staker details by address", async function () {
      const stakerDetails = await stakingPool.getStakerDetailsByAddress(
        addr1.address
      );
      expect(stakerDetails[0]).to.equal(0);
    });
  });
});
