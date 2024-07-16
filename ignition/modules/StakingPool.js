const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("StakingPoolModule", (m) => {
    const stakingPool = m.contract("StakingPool");
    return { stakingPool };
})