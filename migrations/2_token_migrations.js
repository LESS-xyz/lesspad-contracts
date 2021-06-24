const TestToken = artifacts.require("TestToken");
const TestTokenTwo = artifacts.require("TestTokenTwo");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(TestToken, "LessToken", "LESS");
  deployer.deploy(TestTokenTwo, "RitaToken", "RITA", {from: accounts[2]});
};