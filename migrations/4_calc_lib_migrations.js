const Calculations = artifacts.require("Calculations");

module.exports = function (deployer) {
    return deployer.then(async () => {
      //const library = LessLibrary.at("0x2915E92ee441399F9106Ee72f6763f27Ce3Bba27");
      const calc = await deployer.deploy(Calculations);
      console.log('Libraries calc\'s address ', calc.address);
      //await library.setFactoryAddress(factory.address, 1);
    })
  };