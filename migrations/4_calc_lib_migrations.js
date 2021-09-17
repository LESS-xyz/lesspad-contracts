const Calculation1 = artifacts.require("Calculation1");
const Calculations = artifacts.require("Calculations");

module.exports = function (deployer) {
    return deployer.then(async () => {
      const calc = await deployer.deploy(Calculations, {gas: 800000});
      const calc1 = await deployer.deploy(Calculation1, {gas: 400000});
      console.log(`Libraries calc\'s & calc1 addresses `, calc.address, calc1.address);
    })
  };