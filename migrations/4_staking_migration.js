const Staking = artifacts.require("Staking");

module.exports = function (deployer) {
  deployer.deploy(Staking, "0xa372d1d35041714092900B233934fB2D002755E2", "0xE751ffdC2a684EEbcaB9Dc95fEe05c083F963Bf1");
};