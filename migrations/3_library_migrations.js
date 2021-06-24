const LessLibrary = artifacts.require("LessLibrary");

module.exports = function(deployer, network, accounts) {
  // Use the accounts within your migrations.
  if (network == "develop") {
    deployer.deploy(LessLibrary, accounts[0], accounts[1]);
  }
}