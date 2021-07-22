const PresaleFactoryCertified = artifacts.require("PresaleFactoryCertified");
const LessLibrary = artifacts.require("LessLibrary");
const Calculations = artifacts.require("Calculations");

module.exports = function (deployer) {
  return deployer.then(async () => {
    const calc = Calculations.at("0x531EAdCD741Bc487Eb6A918e2E42226e004C6528");
    const library = LessLibrary.at("0xEeCC14c0964082B0Fe0765549dE07889e7A776e4");
    await PresaleFactoryCertified.link(Calculations, calc.address);
    const factory = await deployer.deploy(
        PresaleFactoryCertified,
        "0xEeCC14c0964082B0Fe0765549dE07889e7A776e4",
        "0x5127500909f55455Ebdf1129aF369Fe45106756B"
    );
    console.log('Certified Factory\'s address ', factory.address);
    //await library.setFactoryAddress(factory.address, 1);
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};