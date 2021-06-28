const HDWalletProvider = require("@truffle/hdwallet-provider");
const { BN } = require('@openzeppelin/test-helpers');
const Web3 = require("web3");
const {MNEMONIC, INFURA_ID_PROJECT} = process.env;
const provider = new HDWalletProvider(MNEMONIC, "https://ropsten.infura.io/v3/" + INFURA_ID_PROJECT)
const web3 = new Web3();
const fs = require('fs');
//const { inTransaction } = require("@openzeppelin/test-helpers/src/expectEvent");
//const chai = require("chai");
//const chai = require("chai");
//const { expect, assert } = require("chai");
//const expectRevert = require("./utils/expectRevert.js");
//chai.use(require("chai-bn")(BN));
//const OperationsProcessor = artifacts.require('OperationsProcessor');

const TestToken = artifacts.require('TestToken');
const TestTokenTwo = artifacts.require('TestTokenTwo');
const LessLibrary = artifacts.require('LessLibrary');
const PresaleFactory = artifacts.require('PresaleFactory');
const PresalePublic = artifacts.require('PresalePublic');
const Staking = artifacts.require('Staking');
let lessToken, ritaToken, library, staking, factory, presale;

const MINUS_ONE = new BN(-1);
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
const ONE_HUNDRED = new BN(100);
const ONE_THOUSAND = new BN(1000);

const DAY = new BN(86400);

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const DECIMALS = new BN(18);
const ONE_TOKEN = TEN.pow(DECIMALS);
const ONE_HALF_TOKEN = ONE_TOKEN.div(TWO);
const TWO_TOKEN = ONE_TOKEN.mul(TWO);
const THREE_TOKENS = ONE_TOKEN.mul(THREE);
const TEN_TOKENS = ONE_TOKEN.mul(TEN);
const FIFTY_TOKEN = ONE_TOKEN.mul(FIVE).mul(TEN);
const FIVE_TOKENS = ONE_TOKEN.mul(FIVE);
const SIX_TOKENS = ONE_TOKEN.mul(SIX);
const SEVEN_TOKENS = ONE_TOKEN.mul(SEVEN);
const ONE_HUNDRED_TOKENS = ONE_TOKEN.mul(ONE_HUNDRED);
const ONE_THOUSAND_TOKENS = ONE_TOKEN.mul(ONE_THOUSAND);

contract("PresaleFabric", async accounts => {
    it("test", async()=> {
        lessToken = await TestToken.at("0xa372d1d35041714092900b233934fb2d002755e2");
        ritaToken = await TestTokenTwo.at("0x662ae45fe98dfd93ea0eab6ade75fd42bfab48fd");
        library = await LessLibrary.at("0x4B01dE89936046228D87dad26B7796eA8f424FA4");
        staking = await Staking.at("0xF3016a3C8DdD673535A058b2b86Aa6299639E933");
        factory = await PresaleFactory.at("0x33918Fa73f367000c0911d8dD5949684e4ca3468");
        let info = require("./presalePublicInfo.json");
        let liquidityInfo = require("./presalePublicLiq.json");
        let stringInfo = require("./PresalePublicString.json");
        let nowTime = new BN(Math.floor(Date.now()/1000));
        console.log(nowTime.toString());
        info.openTime = nowTime.add(ONE_HUNDRED.mul(FOUR));
        info.closeTime = info.openTime.add(ONE_HUNDRED.mul(FOUR));
        liquidityInfo.liquidityAllocationTime = info.closeTime.add(ONE_HUNDRED);
        info.openTime = info.openTime.toString();
        info.closeTime = info.closeTime.toString();
        liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
        console.log("INFO: ", info, "\nLIQUIDITY: ", liquidityInfo, "\nSTRING INFO: ", stringInfo);
        const receipt = await factory.createPresalePublic(info, liquidityInfo, stringInfo, {value: ONE_HALF_TOKEN});
        console.log("TRANSACT: ", receipt);
    })
})