const Factory = artifacts.require("PresaleFactory");
const TestToken = artifacts.require("TestToken");
const LessLibrary = artifacts.require("LessLibrary");
const Staking = artifacts.require("Staking");

module.exports = async function (deployer) {
  return deployer.then(async () => {
    const lessToken = await TestToken.deployed();
    const library = await LessLibrary.deployed();
    const staking = await Staking.deployed();
    const factory = await deployer.deploy(
        Factory,
        library.address,
        lessToken.address,
        staking.address
    );
    console.log('Factory\'s address ', factory.address);
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};