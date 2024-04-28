const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const AiamondModule = buildModule("AiamondModule", (m) => {
    const token = m.contract("Aiamond");
  
    return { token };
  });