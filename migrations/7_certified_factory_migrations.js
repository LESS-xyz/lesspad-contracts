const PresaleFactoryCertified = artifacts.require("PresaleFactoryCertified");
const LessLibrary = artifacts.require("LessLibrary");
const Calculations = artifacts.require("Calculations");
const Calculation1 = artifacts.require("Calculation1");

const {
  LIBRARY_KOVAN, 
  LIBRARY_BSC, 
  LIBRARY_MATIC, 
  CALC_KOVAN, 
  CALC_BSC, 
  CALC_MATIC, 
  CALC1_KOVAN, 
  CALC1_BSC, 
  CALC1_MATIC
} = process.env;

module.exports = function (deployer, network, _) {
  return deployer.then(async () => {
    let calc;
    let calc1;
    let lib;
    if(network == "kovan"){
      calc = await Calculations.at(CALC_KOVAN);
      calc1 = await Calculation1.at(CALC1_KOVAN);
      lib = await LessLibrary.at(LIBRARY_KOVAN);
    }
    else if(network == "bscTestnet"){
      calc = await Calculations.at(CALC_BSC);
      calc1 = await Calculation1.at(CALC1_BSC);
      lib = await LessLibrary.at(LIBRARY_BSC);
    }
    else if (network == "maticTestnet") {
      calc = await Calculations.at(CALC_MATIC);
      calc1 = await Calculation1.at(CALC1_MATIC);
      lib = await LessLibrary.at(LIBRARY_MATIC);
    }
    else 
    {
      return;
    }
    await PresaleFactoryCertified.link("Calculations", calc.address);
    await PresaleFactoryCertified.link("Calculation1", calc1.address);
    const factory = await deployer.deploy(
        PresaleFactoryCertified,
        lib.address,
        {gas: 6000000}
    );
    console.log('Certified Factory\'s address ', factory.address);
  })
};