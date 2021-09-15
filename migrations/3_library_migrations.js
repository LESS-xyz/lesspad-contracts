require('dotenv').config();
const {
    MATIC_ROUTER, 
    M_USDC, 
    ETH_ROUTER, 
    ETH_USDT, 
    ETH_USDC, 
    BSC_ROUTER,
    DEV_ADDRESS,
    VAULT,
    BUSD,
    BUSDC
} = process.env;

const LessLibrary = artifacts.require("LessLibrary");

module.exports = async function (deployer, network, accounts) {
  //deployer.deploy(LessLibrary, "0x2f37c34a77d9235775b0a13ee220de2242ef98d2", "0xc164f38c8f338398aebed7b91b382fd4ef653cb5", MATIC_ROUTER, M_USDC, [M_USDC], 18);
  console.log(network);
  if (network == "test" || network == "develop") {
    await deployer.deploy(LessLibrary, accounts[0], accounts[1], MATIC_ROUTER, M_USDC, [M_USDC], 18);
  }
  else if (network == "bscTestnet"){
    await deployer.deploy(LessLibrary, DEV_ADDRESS, VAULT, BSC_ROUTER, BUSD, [BUSD, BUSDC], 18);
  }
  else if(network == "maticTestnet"){
    await deployer.deploy(LessLibrary, DEV_ADDRESS, VAULT, MATIC_ROUTER, M_USDC, [M_USDC], 18);
  }
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
  //deployer.deploy(LessLibrary, "0x6619D419A27bb005a0a51DA2610d036133E72a72", "0x8be1038D11c19F86071363E818A890014cBf3433", MATIC_ROUTER, M_USDC, [M_USDC], 18);
};