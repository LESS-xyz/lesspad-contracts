const Staking = artifacts.require("LessStaking");

module.exports = function (deployer) {
  deployer.deploy(Staking, "0xa372d1d35041714092900B233934fB2D002755E2", "0x46589Ab934277E44A5060f3273761b86396d5429");
};