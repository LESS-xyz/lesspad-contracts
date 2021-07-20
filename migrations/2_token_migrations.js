const TestToken = artifacts.require("TestToken");

module.exports = function (deployer) {
  deployer.deploy(TestToken, "RitaToken", "RITA");
  deployer.deploy(TestToken, "LESS LP Token", "LESS LP");
};