const LessLibrary = artifacts.require("LessLibrary");

module.exports = function (deployer) {
  deployer.deploy(LessLibrary, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x8be1038D11c19F86071363E818A890014cBf3433", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "0x07de306FF27a2B630B1141956844eB1552B956B5");
};