const LessLibrary = artifacts.require("LessLibrary");

module.exports = function (deployer) {
  deployer.deploy(LessLibrary, "0x6619D419A27bb005a0a51DA2610d036133E72a72");
};