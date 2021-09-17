require('dotenv').config();
const {
    MATIC_ROUTER_TEST, 
    M_USDC_TEST, 
    BSC_ROUTER_TEST,
    DEV_ADDRESS,
    VAULT,
    BUSD_TEST,
    BUSDC_TEST,
    BUSD,
    CAKE,
    PANCAKE_ROUTER,
    QUICKSWAP_ROUTER,
    QUICK,
    WETH_POLYGON,
    USDC_MATIC
} = process.env;

const LessLibrary = artifacts.require("LessLibrary");

module.exports = function (deployer, network, accounts) {
  return deployer.then(async () => {
    let lib;
    if (network == "test" || network == "develop") {
      lib = await deployer.deploy(LessLibrary, accounts[0], accounts[1], MATIC_ROUTER_TEST, M_USDC_TEST, [M_USDC_TEST], 18, {gas: 2500000});
    }
    else if (network == "bscTestnet"){
      lib = await deployer.deploy(LessLibrary, DEV_ADDRESS, VAULT, BSC_ROUTER_TEST, BUSD_TEST, [BUSD_TEST, BUSDC_TEST], 18, {gas: 2500000});
    }
    else if(network == "maticTestnet"){
      lib = await deployer.deploy(LessLibrary, DEV_ADDRESS, VAULT, MATIC_ROUTER_TEST, M_USDC_TEST, [M_USDC_TEST], 18, {gas: 2500000});
    }
    else if(network == "bscMainnet"){
      lib = await deployer.deploy(LessLibrary, DEV_ADDRESS, VAULT, PANCAKE_ROUTER, BUSD, [BUSD, CAKE], 18, {gas: 2500000});
    }
    else if( network == "maticMainnet"){
      lib = await deployer.deploy(LessLibrary, DEV_ADDRESS, VAULT, QUICKSWAP_ROUTER, USDC_MATIC, [QUICK, WETH_POLYGON, USDC_MATIC], 6, {gas: 3000000});
    }
    else {
      return;
    }
  
    console.log(`LessLibrary's address in ${network} is : ` , lib.address);
  })
};