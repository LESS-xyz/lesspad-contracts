const Presale = artifacts.require("Presale");
const TestToken = artifacts.require("TestToken");

module.exports = function (deployer) {
  return deployer.then(async () => {
    const token = await TestToken.at("0x8E2E338e823310baE9576886f066303727AB8f87");
    const presale = await deployer.deploy(
        Presale,
        "0x6619D419A27bb005a0a51DA2610d036133E72a72",
        "0x075FDA89Eb389734E563eafC22F5629D76FC2500"
    );
    /*await token.approve(presale.address, "10000000000000000000000000");
    await presale.init(
      "0x6619D419A27bb005a0a51DA2610d036133E72a72",
      "0x8E2E338e823310baE9576886f066303727AB8f87",
      "5000000000000000000",
      "100000000000000000", 
      "100000000000000000",
      "500000000000000000",
      Math.floor(Date.now()/1000) + 600,
      Math.floor(Date.now()/1000) + 2000,
      "0x6619D419A27bb005a0a51DA2610d036133E72a72"
    );*/
    //console.log('Staking\'s address ', staking.address);
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};