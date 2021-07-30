const TestTokenTwo = artifacts.require("TestTokenTwo");
//const PresaleFactoryCertified = artifacts.require("PresaleFactoryCertified");

module.exports = function (deployer) {
  //const presale = TestTokenTwo.at("0x699cb9621b8adc304cbd161d77aa2932ae69dfc5");
  
  //PresaleCertified.link(PresaleCertified, "0x699cb9621b8adc304cbd161d77aa2932ae69dfc5");
  deployer.deploy(TestTokenTwo, "Rita Token", "RITA");
};
