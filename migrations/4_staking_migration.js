const Staking = artifacts.require("Staking");

module.exports = function (deployer) {
  deployer.deploy(Staking, "0x8E2E338e823310baE9576886f066303727AB8f87", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};