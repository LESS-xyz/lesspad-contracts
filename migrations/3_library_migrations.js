const LessLibrary = artifacts.require("LessLibrary");

module.exports = function (deployer) {
  /*return deployer.then(async () => {
    const library = await deployer.deploy(
        LessLibrary,
        "0x6619D419A27bb005a0a51DA2610d036133E72a72",
        "0x8be1038D11c19F86071363E818A890014cBf3433",
        "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        "0xd9ba894e0097f8cc2bbc9d24d308b98e36dc6d02",
        "0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b"
    );
    console.log('Library\'s address ', library.address);
    //await library.
  })*/
  deployer.deploy(LessLibrary, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x8be1038D11c19F86071363E818A890014cBf3433", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "0x07de306ff27a2b630b1141956844eb1552b956b5", "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede");
};