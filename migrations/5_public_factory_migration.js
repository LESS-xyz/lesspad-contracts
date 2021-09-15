const PresaleFactoryPublic = artifacts.require("PresaleFactoryPublic");
const Calculations = artifacts.require("Calculations");
const LessLibrary = artifacts.require("LessLibrary");

const {
  LIBRARY_KOVAN, 
  LIBRARY_BSC, 
  LIBRARY_MATIC, 
  CALC_KOVAN, 
  CALC_BSC, 
  CALC_MATIC
} = process.env;

module.exports = function (deployer, network, _) {
  return deployer.then(async () => {
    let calc;
    let lib;
    if(network == "kovan"){
      calc = await Calculations.at(CALC_KOVAN);
      lib = await LessLibrary.at(LIBRARY_KOVAN);
    }
    else if(network == "bscTestnet"){
      calc = await Calculations.at(CALC_BSC);
      lib = await LessLibrary.at(LIBRARY_BSC);
    }
    else if (network == "maticTestnet") {
      calc = await Calculations.at(CALC_MATIC);
      lib = await LessLibrary.at(LIBRARY_MATIC);
    }
    else 
    {
      return;
    }
    await PresaleFactoryPublic.link("Calculations", calc.address);
    const factory = await deployer.deploy(
        PresaleFactoryPublic,
        lib.address
    );
    console.log('Public Factory\'s address ', factory.address);
  })
};