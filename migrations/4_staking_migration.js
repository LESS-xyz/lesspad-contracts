const Staking = artifacts.require("Staking");

module.exports = function (deployer) {
  deployer.deploy(Staking, "0x4fe142c6CBD294ef96DbBa8a837CdE3035850A97", "0x87feef975fd65f32A0836f910Fd13d9Cf4553690", 10, Math.floor(Date.now()/1000));
};