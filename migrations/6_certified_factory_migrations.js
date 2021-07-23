const PresaleFactoryCertified = artifacts.require("PresaleFactoryCertified");
//const LessLibrary = artifacts.require("LessLibrary");
const Calculations = artifacts.require("Calculations");

module.exports = function (deployer) {
  return deployer.then(async () => {
    const calc = Calculations.at("0x84720f32Ff38768177E4465Df220Fe0934b014be");
    //const library = LessLibrary.at("0xEeCC14c0964082B0Fe0765549dE07889e7A776e4");
    await PresaleFactoryCertified.link(Calculations, calc.address);
    const factory = await deployer.deploy(
        PresaleFactoryCertified,
        "0x7BaABa8B15BfFf41573e4260E22226d7935Bbc60",
        "0xe29da66439bcbdb71d508f41bad13250f561e38f"
    );
    console.log('Certified Factory\'s address ', factory.address);
    //await library.setFactoryAddress(factory.address, 1);
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};