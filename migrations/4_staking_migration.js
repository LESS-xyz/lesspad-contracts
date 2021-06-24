const Staking = artifacts.require("Staking");
const LessLibrary = artifacts.require("LessLibrary");
const TestToken = artifacts.require("TestToken");

module.exports = async function (deployer) {
  const lessToken = await TestToken.deployed();
  const library = await LessLibrary.deployed();
  const staking = await deployer.deploy(Staking, lessToken.address, library.address);
  console.log("Staking address: ", staking.address);
};