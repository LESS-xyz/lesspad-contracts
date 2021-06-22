const Factory = artifacts.require("PresaleFactory");
//const TestToken = artifacts.require("TestToken");

module.exports = function (deployer) {
  return deployer.then(async () => {
    const factory = await deployer.deploy(
        Factory,
        "0xE751ffdC2a684EEbcaB9Dc95fEe05c083F963Bf1",
        "0xa372d1d35041714092900B233934fB2D002755E2",
        "0x9a44AaBd1305600B335Bde83760F165d2D742cFb"
    );
    console.log('Factory\'s address ', factory.address);
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};