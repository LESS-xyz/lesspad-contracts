const { BN } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const EthCrypto = require("eth-crypto");

const PresaleFactoryCertified = artifacts.require("PresaleFactoryCertified");
const PresaleCertified = artifacts.require("PresaleCertified");
const LessLibrary = artifacts.require("LessLibrary");
const Calculation1 = artifacts.require("Calculation1");
const TestTokenTwo = artifacts.require("TestTokenTwo");

const {
    DEPLOYER_ADDRESS, 
    DEV_ADDRESS, 
    MNEMONIC, 
    LIBRARY_KOVAN, 
    LIBRARY_BSC, 
    LIBRARY_MATIC, 
    CALC1_KOVAN, 
    CALC1_BSC, 
    CALC1_MATIC,
    TOKEN_KOVAN, 
    TOKEN_BSC, 
    TOKEN_MATIC
} = process.env;

const MINUTE = new BN(60);
const ZERO = new BN(0);
const ONE = new BN(1);
const TWO = new BN(2);
const THREE = new BN(3);
const FOUR = new BN(4);
const FIVE = new BN(5);
const SIX = new BN(6);
const SEVEN = new BN(7);
const EIGHT = new BN(8);
const NINE = new BN(9);
const TEN = new BN(10);
const FIFTEEN = new BN(15)
const TWENTY = new BN(20)
const THIRTY = new BN(30)

module.exports = function (deployer, network, _) {
  return deployer.then(async () => {
    const factory = await PresaleFactoryCertified.deployed();
    let library;
    let ritaToken;
    let calculations;

    if(network == "kovan"){
        library = await LessLibrary.at(LIBRARY_KOVAN);
        calculations = await Calculation1.at(CALC1_KOVAN);
        ritaToken = await TestTokenTwo.at(TOKEN_KOVAN);
    }
    else if(network == "bscTestnet"){
        library = await LessLibrary.at(LIBRARY_BSC);
        calculations = await Calculation1.at(CALC1_BSC);
        ritaToken = await TestTokenTwo.at(TOKEN_BSC);
    }
    else if(network == "maticTestnet"){
        library = await LessLibrary.at(LIBRARY_MATIC);
        calculations = await Calculation1.at(CALC1_MATIC);
        ritaToken = await TestTokenTwo.at(TOKEN_MATIC);
    }
    
    let info = require("../testnet-params/presalePublicInfo.json");
    let liquidityInfo = require("../testnet-params/presalePublicLiq.json");
    let stringInfo = require("../testnet-params/PresalePublicString.json");
    let additionalInfo = require("../testnet-params/presaleCertifiedAddition.json")
    additionalInfo.nativeToken = ZERO_ADDRESS;
    info.tokenAddress = ritaToken.address;
    let nowTime = new BN(Math.floor(Date.now() / 1000));
    console.log(nowTime.toString());
    
    info.openTime = nowTime.add(MINUTE.mul(TEN));
    info.closeTime = info.openTime.add(MINUTE.mul(FIVE).mul(FIVE));
    liquidityInfo.liquidityAllocationTime = info.closeTime.add(MINUTE.mul(TEN));
    info.openTime = info.openTime.toString();
    info.closeTime = info.closeTime.toString();
    liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
    
    let timeForSign = nowTime;
    info._tokenAmount = "10000000000000000000000";
    info._timestamp = timeForSign.toString();
    let data = web3.utils.soliditySha3(info.tokenAddress, DEPLOYER_ADDRESS, '10000000000000000000000' , info._timestamp);
    console.log(data);        
    let signature = EthCrypto.sign(MNEMONIC, data);
    info._signature = signature;
    
    console.log("INFO: ", info, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
    
    let balanceOfDeployer = await ritaToken.balanceOf(DEPLOYER_ADDRESS);
    let allowanceOfDeployer = await ritaToken.allowance(DEPLOYER_ADDRESS, factory.address);
    console.log('balance of deployer', balanceOfDeployer.toString());
    
    let amountOfTokens = await calculations.countAmountOfTokens(
        info.hardCapInWei,
        info.tokenPriceInWei, 
        liquidityInfo.listingPriceInWei,
        liquidityInfo.liquidityPercentageAllocation,
        (new BN(await ritaToken.decimals())).toString(),
        new BN("18")
    )
    let amountToCreatePresale = amountOfTokens[2]
    console.log('amount to create presale', amountToCreatePresale.toString())


    if (amountToCreatePresale > allowanceOfDeployer) {
        await ritaToken.approve(factory.address, amountToCreatePresale);
    }
      
    if (amountToCreatePresale > balanceOfDeployer) {
        await ritaToken.mint(DEPLOYER_ADDRESS, amountToCreatePresale);
    }
    
    //let ethFee = await calculations.usdtToEthFee(library.address)
    let ethFee = new BN(500000000);
    console.log('eth fee', ethFee.toString())
    
    let libraryDev = DEV_ADDRESS;
    console.log('lib dev', libraryDev)
    let encode_type_array = ['address', 'address', 'address']
    let encoded_args = web3.eth.abi.encodeParameters(
        encode_type_array, 
        [factory.address, library.address, libraryDev]
    )
    console.log('encoded constructor params of presale', encoded_args)
    
    const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {value: ethFee});
    console.log(receipt);
    
  })
  
};