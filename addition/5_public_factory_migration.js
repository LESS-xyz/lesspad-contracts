const PresaleFactoryPublic = artifacts.require("PresaleFactoryPublic");
const Calculations = artifacts.require("Calculations");

module.exports = function (deployer) {
  return deployer.then(async () => {
    //const calc = Calculations.at("0x0E2967580BE47c5ceC6Af37B6393829300cFe22E");
    const calc = await Calculations.at("0x34E414C5d3A4d06a36e285bea695fae1E8e448Cd");
    //const library = await LessLibrary.deployed();
    //const ritaToken = TestTokenTwo.at("0x63Adf149ac95cb7cc24254Cfad2ceD43D6b067E3");
    await PresaleFactoryPublic.link("Calculations", calc.address);
    const factory = await deployer.deploy(
        PresaleFactoryPublic,
        "0x0B58bF30d19E4c6C71A6118108db810A4E68C9E6"
        //"0x076877073D287Ee8c10878B190d7166367899fdA"
    );
    console.log('Public Factory\'s address ', factory.address);
    //await library.setFactoryAddress(factory.address, 1);
    //await ritaToken.approve(factory.address, 10000000000000000000000000000);
    /*const presale = await factory.createPresaleCertified(["0xd16787110bfe152d44563f8629e213baa30995c8",      "10000000000000000",      "4000000000000000000",      "2000000000000000000",    "1627470951",     "1627557351",    "0", "0x88c803f529ed45e3e92a5ff8ecdec72b3956d6aeeb928735b7df13fe741acc8d4fe3381016a5968018a027cef1020f62f328c8da38938dfb5992c3d17f4b587e1c","2021072314041627049078"],[false, false, "0", [], "0xd0A1E359811322d97991E03f863a0C30C2cF029C"],["0" , "0", "0", "1627643751"],["0x7269746100000000000000000000000000000000000000000000000000000000", "0x7269746100000000000000000000000000000000000000000000000000000000", "0x7269746100000000000000000000000000000000000000000000000000000000", "0x7269746100000000000000000000000000000000000000000000000000000000", "0x7269746100000000000000000000000000000000000000000000000000000000", "RITA", "RITA", "RITA"], {value: 300000000000000000});
    console.log("Certified presale address: ", presale.address);*/
  })
  //deployer.deploy(Presale, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x075FDA89Eb389734E563eafC22F5629D76FC2500");
};