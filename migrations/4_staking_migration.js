const Staking = artifacts.require("Staking");

module.exports = function (deployer) {
  deployer.deploy(Staking, "0x6d478b336d39707b57b4747d7cfca3386516b859", "0x66bf43b9fbd7780a5bdccae0adee692588ae4944", "0xA0BDCb13fD00D7cEF0eb872C4537fbf3F379E5Bb");
};