const PresaleFactoryPublic = artifacts.require("PresaleFactoryPublic");

module.exports = function (deployer) {
  return deployer.then(async () => {
    const factory = await deployer.deploy(
        PresaleFactoryPublic,
        "0x46589Ab934277E44A5060f3273761b86396d5429",
        "0xa372d1d35041714092900B233934fB2D002755E2"
    );
    console.log('Public Factory\'s address ', factory.address);
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};