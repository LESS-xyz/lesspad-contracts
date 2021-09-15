const { expect } = require('chai');
const { BN, expectEvent, expectRevert, makeInterfaceId, time } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { inTransaction } = require('@openzeppelin/test-helpers/src/expectEvent');
const ERC20 = artifacts.require("ERC20");
const TestToken = artifacts.require("TestToken");
const TestTokenTwo = artifacts.require('TestTokenTwo');
const LessLibrary = artifacts.require('LessLibrary');
const PresaleFactoryCertified = artifacts.require('PresaleFactoryCertified');
const PresaleCertified = artifacts.require('PresaleCertified');
//pancake artifacts
const WETH = artifacts.require('WETH');
let wethInst;
const PancakeFactory = artifacts.require('PancakeFactory');
let pancakeFactoryInstant;
const PancakeRouter = artifacts.require('PancakeRouter');
let pancakeRouterInstant;
const PancakePair = artifacts.require('PancakePair');
let pancakePairInstant;

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
const MINUTE = new BN(60);

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

const TIER1 = ONE_THOUSAND_TOKENS;
const TIER2 = ONE_THOUSAND_TOKENS.mul(FIVE);
const TIER3 = ONE_THOUSAND_TOKENS.mul(TEN).mul(TWO);
const TIER4 = ONE_THOUSAND_TOKENS.mul(TEN).mul(FIVE);
const TIER5 = ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED).mul(TWO);
const THIRTY = THREE.mul(TEN);
const TWENTY = TWO.mul(TEN);
const FIFTEEN = FIVE.mul(THREE);
const TWENTY_FIVE = FIVE.mul(FIVE);

contract (
    'PresaleCertified',
    ([
        deployer,
        vault,
        signer,
        account_one,
        account_two,
        account_three,
        account_four,
        account_five
    ]) => {
        before(async function () {
            // Advance to the next block to correctly read time in the solidity "now" function interpreted by ganache
            await time.advanceBlock();
        });

        //contracts
        let library, factory, ritaToken;//, usdc, usdcPair;

        beforeEach(async()=>{
            //usdc = await TestToken.deployed();
            ritaToken = await TestTokenTwo.deployed();

            library = await LessLibrary.deployed();
            factory = await PresaleFactoryCertified.deployed();
            wethInst = await WETH.new(
                { from: deployer }
            );
        
            pancakeFactoryInstant = await PancakeFactory.new(
                deployer,
                { from: deployer }
            );
        
            pancakeRouterInstant = await PancakeRouter.new(
                pancakeFactoryInstant.address,
                wethInst.address,
                { from: deployer }
            );

            //await usdc.approve(pancakeRouterInstant.address, ONE_THOUSAND_TOKENS, {from: deployer});
            //usdcPair = await pancakeRouterInstant.addLiquidityETH(usdc.address, ONE_THOUSAND_TOKENS, ZERO , ZERO, deployer, await time.latest(), {from: deployer, value: ONE_TOKEN.mul(TEN)});
            library.setUniswapRouter(pancakeRouterInstant.address);
            library.setFactoryAddress(factory.address, 1);
            library.addOrRemoveSigner(signer, "true");
            //library.addOrRemoveStaiblecoin(usdc.address, true);
        })

        /*it("Approve", async()=> {
            await lessToken.approve(
                staking.address,
                ONE_THOUSAND_TOKENS.mul(TWO).mul(TEN),
                {from: account_one}
            );
            await lessToken.approve(
                staking.address,
                ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED),
                {from: account_two}
            );
            await lessToken.approve(
                staking.address,
                ONE_THOUSAND_TOKENS,
                {from: account_three}
            );
        })*/

        /*it('should mint less tokens to accs', async function() {
            const valueOne = ONE_THOUSAND_TOKENS.mul(THREE).mul(TEN);
            const valueTwo = ONE_THOUSAND_TOKENS.mul(FOUR).mul(TEN);
            const valueThree = ONE_THOUSAND_TOKENS;
            await lessToken.mint(account_one, valueOne);
            await lessToken.mint(account_two, valueTwo);
            await lessToken.mint(account_three, valueThree);
            const balanceOne = await lessToken.balanceOf(account_one);
            const balanceTwo = await lessToken.balanceOf(account_two);
            const balanceThree = await lessToken.balanceOf(account_three);
            expect(balanceOne).bignumber.equal(valueOne);
            expect(balanceTwo).bignumber.equal(valueTwo);
            expect(balanceThree).bignumber.equal(valueThree);
        })*/

        /*it("should stake correctly", async()=> {
            let balanceOne = await lessToken.balanceOf(account_one);
            await staking.stake(ONE_HALF_TOKEN, {from: account_one});
            let balanceTwo = await lessToken.balanceOf(account_one);
            let stakenAmount = await staking.getStakedAmount();
            expect(stakenAmount).bignumber.equal(ONE_HALF_TOKEN);
            let stakingBalance = await lessToken.balanceOf(staking.address);
            expect(stakingBalance).bignumber.equal(ONE_HALF_TOKEN);
            expect(balanceOne).bignumber.equal(balanceTwo.add(ONE_HALF_TOKEN));
            let stake = await staking.getAccountInfo(account_one);
            expect(stake[0]).bignumber.equal(ONE_HALF_TOKEN);
            await expectRevert(staking.unstake(ONE_HALF_TOKEN, {from: account_one}), "Invalid Unstake Time");
            await time.increase(time.duration.days(3));
            await expectRevert(staking.unstake(ONE_HALF_TOKEN, {from: account_one}), "Invalid Unstake Time");
            await time.increase(time.duration.days(3));
            await staking.unstake(ONE_TOKEN, {from: account_one});
            balanceTwo = await lessToken.balanceOf(account_one);
            expect(balanceTwo).bignumber.equal(balanceOne);
            balanceTwo = await lessToken.balanceOf(staking.address);
            expect(balanceTwo).bignumber.equal(ZERO);
        })*/

        /* it("signeture", async()=>{
            let signature = await web3.eth.accounts.sign('rita', "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            console.log("SIGN: ", signature);
            await library._verifySigner(signature.messageHash, signature.signature, 1);
            let data = web3.utils.soliditySha3('rita');
            console.log("DATA: ", data);
        }) */

        /* it('should create presale', async()=> {
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(DAY.mul(FIVE));
            info.closeTime = info.openTime.add(DAY.mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(DAY);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            let timeForSign = await time.latest();
            info._tokenAmount = "0";
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            additionalInfo.nativeToken = ZERO_ADDRESS;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);
            let genInfo = await presale.generalInfo.call();
            console.log("GEN INFO TOK LEFT: ",genInfo.tokensForSaleLeft.toString());
            //await presale.approvePresale({from: deployer});
            await expectRevert(presale.register(FIVE_TOKENS.mul(ONE_THOUSAND), FOUR, timeForSign, signature.signature, {from: account_two}), "N.REG");
            await time.increase(time.duration.days(4));
            await expectRevert(presale.register(FIVE_TOKENS.mul(ONE_THOUSAND), FOUR, timeForSign, signature.signature, {from: account_two}), "W.PARAMS");
            await presale.approvePresale({from: deployer});
            await expectRevert(presale.register(ONE_TOKEN, ZERO, timeForSign, signature.signature), "W.PARAMS");
            await presale.register(FIVE_TOKENS.mul(ONE_THOUSAND), TWO, timeForSign, signature.signature, {from: account_two});
            genInfo = await presale.generalInfo.call();
            console.log("GEN INFO TOK LEFT: ",genInfo.tokensForSaleLeft.toString());
            await presale.register(FIVE_TOKENS.mul(TEN).mul(ONE_THOUSAND), FOUR, timeForSign, signature.signature, {from: account_three});
            genInfo = await presale.generalInfo.call();
            console.log("GEN INFO TOK LEFT: ",genInfo.tokensForSaleLeft.toString());
            await expectRevert(presale.register(ONE_THOUSAND_TOKENS, FOUR, timeForSign, signature.signature, {from: account_three}), "W.PARAMS");
            await expectRevert(presale.register(ONE_THOUSAND_TOKENS, FOUR, timeForSign, signature.signature, {from: account_one}), "W.PARAMS");
            await time.increase(time.duration.days(1));
            await expectRevert(presale.invest(ZERO,signature.signature, TIER5,timeForSign, {from: account_four}), "SIGN/REG");
            await expectRevert(presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three}), "can't invest zero");
            console.log(info.openTime, (await time.latest()).toString());
            await expectRevert(presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three, value: ONE_TOKEN.div(ONE_HUNDRED)}), "TIER 5");
            await time.increase(time.duration.minutes(61));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three, value: TWO_TOKEN}), "(N)ENOUGH");
            let ethBalanceTwoBefore = await web3.eth.getBalance(account_two);
            let ethBalanceThreeBefore = await web3.eth.getBalance(account_three);
            console.log(ethBalanceThreeBefore.toString());
            await presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three, value: ONE_TOKEN.div(ONE_HUNDRED)});
            let ethBalanceThreeAfter = await web3.eth.getBalance(account_three);
            console.log(ethBalanceThreeAfter.toString());
            //expect(ethBalanceThreeBefore.sub(ONE_TOKEN.div(ONE_HUNDRED))).bignumber.equal(ethBalanceThreeAfter);
            genInfo = await presale.generalInfo.call();
            console.log("GEN INFO TOK LEFT: ",genInfo.tokensForSaleLeft.toString());
            let investmentThree = await presale.investments.call(account_three);
            console.log(investmentThree.amountEth.toString(), investmentThree.amountTokens.toString());
            await time.increase(time.duration.minutes(31));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER2, timeForSign,  {from: account_two, value: ONE_TOKEN.div(ONE_HUNDRED)}), "TIER 3");
            await time.increase(time.duration.minutes(15));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER2, timeForSign,  {from: account_two, value: ONE_TOKEN.mul(FOUR)}), "(N)ENOUGH");
            await presale.invest(ZERO, signature.signature, TIER2, timeForSign,  {from: account_two, value: ONE_TOKEN.div(ONE_HUNDRED)});
            let ethBalanceTwoAfter = await web3.eth.getBalance(account_two);
            //expect(ethBalanceTwoBefore.sub(ethBalanceTwoAfter)).bignumber.equal(ONE_TOKEN.div(ONE_HUNDRED));
            genInfo = await presale.generalInfo.call();
            console.log("GEN INFO TOK LEFT: ",genInfo.tokensForSaleLeft.toString());
            let investmentTwo = await presale.investments.call(account_two);
            console.log(investmentTwo.amountEth.toString(), investmentTwo.amountTokens.toString());
            //await expectRevert(presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three, value: ONE_TOKEN.div(ONE_HUNDRED)}), "u cant vote");
            await time.increase(time.duration.minutes(11));
            await presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three, value: ONE_TOKEN});
            investmentThree = await presale.investments.call(account_three);
            console.log(investmentThree.amountEth.toString(), investmentThree.amountTokens.toString());
            inter = await presale.intermediate.call();
            console.log("RAISED AMOUNT: ",inter.raisedAmount.toString());
            await expectRevert(presale.withdrawInvestment(account_three, TWO_TOKEN, {from: account_three}), "W.PARAMS");
            await presale.withdrawInvestment(account_three, ONE_HALF_TOKEN,  {from: account_three});
            investmentThree = await presale.investments.call(account_three);
            console.log(investmentThree.amountEth.toString(), investmentThree.amountTokens.toString());
            let presaleBalanceInWei = await web3.eth.getBalance(presale.address);
            inter = await presale.intermediate.call();
            expect(presaleBalanceInWei).bignumber.equal(genInfo.collectedFee.add(inter.raisedAmount));
            let balOwner = await web3.eth.getBalance(deployer);
            console.log("BALANCE OWNER: ",balOwner.toString());
            await presale.collectFee({from:deployer});
            balOwner = await web3.eth.getBalance(deployer);
            console.log("BALANCE OWNER: ",balOwner.toString());
            await presale.invest(ZERO, signature.signature, TIER4, timeForSign,  {from: account_three, value: TWO_TOKEN});
            inter = await presale.intermediate.call();
            console.log("RAISED AMOUNT: ",inter.raisedAmount.toString());
            await expectRevert(presale.withdrawInvestment(account_three, ONE_HALF_TOKEN,  {from: account_three}), "AFTERCAP");
            await expectRevert(presale.claimTokens({from: account_two}), "W.PARAMS");
            await time.increase(time.duration.days(5));
            await expectRevert(presale.addLiquidity({from: account_one}), "W.PARAMS");
            const ritaBalTwo = await ritaToken.balanceOf(account_two);
            await presale.claimTokens({from: account_two});
            const ritaBalTwoafter = await ritaToken.balanceOf(account_two);
            expect(ritaBalTwoafter.sub(ritaBalTwo)).bignumber.equal(ONE_TOKEN);
            await expectRevert(presale.claimTokens({from: account_four}), "W.PARAMS");
            await expectRevert(presale.claimTokens({from: account_two}), "W.PARAMS");
            const ritaBalTree = await ritaToken.balanceOf(account_three);
            await presale.claimTokens({from:account_three});
            const ritaBalTreeafetr = await ritaToken.balanceOf(account_three);
            expect(ritaBalTreeafetr.sub(ritaBalTree)).bignumber.equal(TWO.mul(ONE_HUNDRED_TOKENS).add(ONE_TOKEN).add(FIVE.mul(TEN_TOKENS)));
            let ritaBalPres = await ritaToken.balanceOf(presale.address);
            console.log("PRES RITA BALANCE: ",ritaBalPres.toString());
            const creatorBalOne = await web3.eth.getBalance(account_one);
            await presale.collectFundsRaised({from: account_one});
            const creatorBalTwo = await web3.eth.getBalance(account_one);
            //expect(creatorBalTwo.sub(creatorBalOne)).bignumber.equal(new BN("2520000000000000000"));
            console.log("BEFORE: ", creatorBalOne, "AFTER: ", creatorBalTwo);
            ritaBalPres = await ritaToken.balanceOf(presale.address);
            expect(ritaBalPres).bignumber.equal(ZERO);
        }) */

        /* it("presale in stablecoins", async()=>{
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(DAY.mul(FIVE));
            info.closeTime = info.openTime.add(DAY.mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(DAY);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            additionalInfo.nativeToken = usdc.address;
            let timeForSign = await time.latest();
            info._tokenAmount = "0";
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            //additionalInfo.nativeToken = ZERO_ADDRESS;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            //await expectRevert(factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")}), "Wrong liq param");
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);

            //mint//approve

            await usdc.mint(account_two, ONE_HUNDRED_TOKENS);
            await usdc.mint(account_three, ONE_HUNDRED_TOKENS);
            await usdc.mint(account_four, ONE_HUNDRED_TOKENS);
            await usdc.mint(account_five, ONE_HUNDRED_TOKENS);
            await usdc.approve(presale.address, ONE_HUNDRED_TOKENS, {from: account_two});
            await usdc.approve(presale.address, ONE_HUNDRED_TOKENS, {from: account_three});
            await usdc.approve(presale.address, ONE_HUNDRED_TOKENS, {from: account_four});
            await usdc.approve(presale.address, ONE_HUNDRED_TOKENS, {from: account_five});

            //try to register
            await expectRevert(presale.register(ZERO, FOUR, timeForSign, signature.signature, {from: account_two}), "N.REG");
            await time.increase(time.duration.days(4));
            await expectRevert(presale.register(ZERO, FOUR, timeForSign, signature.signature, {from: account_two}), "W.PARAMS");
            await presale.approvePresale({from: deployer});
            await presale.register(ZERO, TWO, timeForSign, signature.signature, {from: account_two});
            await presale.register(ZERO, FOUR, timeForSign, signature.signature, {from: account_four});
            await presale.register(ZERO, FIVE, timeForSign, signature.signature, {from: account_five});
            await expectRevert(presale.register(ZERO, FIVE, timeForSign, signature.signature, {from: account_five}), "W.PARAMS");

            //try to invest
            const genInfo = await presale.generalInfo.call();
            const collectedFee = genInfo[9];
            console.log("COLLECTED FEE : ", collectedFee.toString());
            await expectRevert(presale.invest(ZERO, signature.signature, TIER2, timeForSign, {from: account_two}), "N.OPEN");
            
            await time.increase(time.duration.days(1));
            const addit = await presale.certifiedAddition.call();
            console.log(addit, usdc.address);
            await expectRevert(presale.invest(ZERO, signature.signature, TIER2, timeForSign, {from: account_two, value: new BN("1000000000")}), "can't invest zero");
            await expectRevert(presale.invest(ONE_TOKEN, signature.signature, TIER4, timeForSign, {from: account_three}), "SIGN/REG");
            await expectRevert(presale.invest(TEN.mul(ONE_TOKEN), signature.signature, TIER5, timeForSign, {from: account_five}), "(N)ENOUGH");
            await presale.invest(ONE_HALF_TOKEN, signature.signature, TIER5, timeForSign, {from: account_five});
            expect(await usdc.balanceOf(presale.address)).bignumber.equal(ONE_HALF_TOKEN);
            await expectRevert(presale.invest(ONE_TOKEN, signature.signature, TIER4, timeForSign, {from: account_four}), "TIER 5");
            await time.increase(time.duration.minutes(60));
            await presale.invest(ONE_TOKEN, signature.signature, TIER4, timeForSign, {from: account_four});
            expect(await usdc.balanceOf(presale.address)).bignumber.equal(ONE_HALF_TOKEN.add(ONE_TOKEN));
            await expectRevert(presale.invest(ONE_TOKEN, signature.signature, TIER2, timeForSign, {from: account_two}), "TIER 4");
            await time.increase(time.duration.minutes(30));
            await expectRevert(presale.invest(ONE_TOKEN, signature.signature, TIER2, timeForSign, {from: account_two}), "TIER 3");
            await time.increase(time.duration.minutes(15));
            await presale.invest(ONE_TOKEN, signature.signature, TIER2, timeForSign, {from: account_two});
            expect(await usdc.balanceOf(presale.address)).bignumber.equal(ONE_HALF_TOKEN.add(TWO_TOKEN));
            //expect(await web3.eth.getBalance(presale.address)).bignumber.equal(ONE_TOKEN.add(collectedFee));
            let investThree = await presale.investments.call(account_two);
            expect(investThree[0]).bignumber.equal(ONE_TOKEN);
            expect(investThree[1]).bignumber.equal(ONE_HUNDRED_TOKENS);
            investThree = await presale.investments.call(account_four);
            expect(investThree[0]).bignumber.equal(ONE_TOKEN);
            expect(investThree[1]).bignumber.equal(ONE_HUNDRED_TOKENS);
            investThree = await presale.investments.call(account_five);
            expect(investThree[0]).bignumber.equal(ONE_HALF_TOKEN);
            expect(investThree[1]).bignumber.equal(ONE_TOKEN.mul(TEN).mul(FIVE));

            await expectRevert(presale.collectFee({from: account_two}), "OWNERS");
            const balBefore = await web3.eth.getBalance(deployer);
            console.log("BEFORE FEE: ",balBefore)
            await presale.collectFee({from: account_one});
            const balAfet = await web3.eth.getBalance(deployer);
            console.log("AFTER FEE: ", balAfet);
            //expect(balAfet.sub(balBefore)).bignumber.equal(collectedFee);
            
            //claim tokens
            await expectRevert(presale.withdrawInvestment(account_two, ONE_HALF_TOKEN, {from: account_two}), "AFTERCAP");
            await expectRevert(presale.claimTokens({from:account_two}), "W.PARAMS");
            await time.increase(time.duration.days(5));
            await expectRevert(presale.withdrawInvestment(account_two, ONE_HALF_TOKEN, {from: account_two}), "AFTERCAP");
            expect(await ritaToken.balanceOf(account_two)).bignumber.equal(ZERO);
            await presale.claimTokens({from: account_two});
            expect(await ritaToken.balanceOf(account_two)).bignumber.equal(ONE_HUNDRED_TOKENS);
            await expectRevert(presale.claimTokens({from: account_three}), "W.PARAMS");
            expect(await ritaToken.balanceOf(account_four)).bignumber.equal(ZERO);
            await presale.claimTokens({from: account_four});
            expect(await ritaToken.balanceOf(account_four)).bignumber.equal(ONE_HUNDRED_TOKENS);
            expect(await ritaToken.balanceOf(account_five)).bignumber.equal(ZERO);
            await presale.claimTokens({from: account_five});
            expect(await ritaToken.balanceOf(account_five)).bignumber.equal(ONE_HUNDRED_TOKENS.div(TWO));
            await expectRevert(presale.collectFee({from: deployer}), "WITHDRAWN");
            //const usdcBalanceBefore = await usdc.balanceOf(account_one);
            expect(await usdc.balanceOf(account_one)).bignumber.equal(ZERO);
            await presale.collectFundsRaised({from: account_one});
            expect(await usdc.balanceOf(account_one)).bignumber.equal(TWO_TOKEN.add(ONE_HALF_TOKEN));
            await expectRevert(presale.collectFundsRaised({from:account_one}), "ONCE");
        }) */

        /* it("check vesting", async()=>{
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(MINUTE.mul(EIGHT).add(ONE));
            info.closeTime = info.openTime.add(MINUTE.mul(FIVE).mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(MINUTE);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            let timeForSign = await time.latest();
            info._tokenAmount = (ONE_THOUSAND_TOKENS.mul(TEN)).toString() ;
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            additionalInfo.nativeToken = ZERO_ADDRESS;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            //await expectRevert(factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("500000000")}), "TIME");
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("500000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);

            let certifiedAddition = await presale.certifiedAddition.call();
            console.log(certifiedAddition);

            //APPROVE
            await presale.approvePresale();
            //COLLECT FEE
            const balBefore = await web3.eth.getBalance(deployer);
            await presale.collectFee({from: account_one});
            const balAfetr = await web3.eth.getBalance(deployer);
            //expect(balAfetr.sub(balBefore)).bignumber.equal(new BN("500000000"));
            console.log("BEFORE FEE: ", balBefore.toString());
            console.log("AFTER FEE: ", balAfetr.toString());
            await expectRevert(presale.register(TIER1, ONE, timeForSign, signature.signature, {from: account_two}), "W.PARAMS");
            await time.increase(time.duration.minutes(3));
            //REGISTER
            await time.increase(time.duration.seconds(1));
            await presale.register(TIER1, ONE, timeForSign, signature.signature, {from: account_two});
            await presale.register(TIER5, FIVE, timeForSign, signature.signature, {from: account_three});
            await presale.register(TIER4, FOUR, timeForSign, signature.signature, {from: account_four});
            await presale.register(TIER3, THREE, timeForSign, signature.signature, {from: account_five});
            //INVESTMENTS
            await expectRevert(presale.invest(ZERO, signature.signature, TIER5, timeForSign, {from: account_three, value: ONE_HALF_TOKEN}), "SIGN/REG");
            await time.increase(time.duration.minutes(5));
            await presale.invest(ZERO, signature.signature, TIER5, timeForSign, {from: account_three, value: ONE_HALF_TOKEN});
            await expectRevert(presale.invest(ZERO, signature.signature, TIER4, timeForSign, {from: account_four, value: ONE_HALF_TOKEN}), "TIER 5");
            await time.increase(time.duration.minutes(5));
            await presale.invest(ZERO, signature.signature, TIER4, timeForSign, {from: account_four, value: ONE_HALF_TOKEN});
            await time.increase(time.duration.minutes(5));
            await presale.invest(ZERO, signature.signature, TIER3, timeForSign, {from: account_five, value: ONE_HALF_TOKEN});
            await time.increase(time.duration.minutes(5));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER1, timeForSign, {from: account_two, value: ONE_HALF_TOKEN}), "TIER 2");
            await time.increase(time.duration.minutes(5));
            await expectRevert(presale.collectFundsRaised({from: account_one}), "ONCE/TIME/SOFT");
            await presale.invest(ZERO, signature.signature, TIER1, timeForSign, {from: account_two, value: ONE_HALF_TOKEN});

            //TRY TO ADD LIQUIDITY WHEN IT'S OFF
            await time.increase(time.duration.minutes(5));
            await expectRevert(presale.addLiquidity({from: account_one}), "W.PARAMS");
            await expectRevert(presale.addLiquidity({from: deployer}), "W.PARAMS");

            //WITHDRAW EARNED ETH
            //await expectRevert(presale.collectFundsRaised({from: deployer}), "LA");
            console.log("BEFORE: ",(await web3.eth.getBalance(account_one)).toString());
            await presale.collectFundsRaised({from: account_one});
            console.log("AFTER: ",(await web3.eth.getBalance(account_one)).toString());

            //CLAIM TOKENS
            await expectRevert(presale.claimTokens({from: account_three}), "NOCLAIM");
            await time.increase(time.duration.minutes(5));
            //ONE MONTH
            console.log("3: ", (await ritaToken.balanceOf(account_three)).toString());
            await presale.claimTokens({from: account_three});
            console.log("3: ",(await ritaToken.balanceOf(account_three)).toString());
            //let investment = await presale.investments.call(account_three);
            //console.log("3: ",investment.amountTokens.toString());
            await time.increase(time.duration.minutes(5));
            //TWO MONTH
            await presale.claimTokens({from: account_three});
            console.log("3: ",(await ritaToken.balanceOf(account_three)).toString());
            await time.increase(time.duration.minutes(1));
            console.log("2: ", (await ritaToken.balanceOf(account_two)).toString());
            await presale.claimTokens({from: account_two});
            console.log("2: ", (await ritaToken.balanceOf(account_two)).toString());
            await time.increase(time.duration.minutes(4));
            //THREE MONTH
            await presale.claimTokens({from: account_two});
            console.log("2: ", (await ritaToken.balanceOf(account_two)).toString());
            await presale.claimTokens({from: account_three});
            console.log("3: ",(await ritaToken.balanceOf(account_three)).toString());
            console.log("4: ",(await ritaToken.balanceOf(account_four)).toString());
            await presale.claimTokens({from: account_four});
            console.log("4: ",(await ritaToken.balanceOf(account_four)).toString());
            await expectRevert(presale.claimTokens({from: account_one}), "W.PARAMS");
            await expectRevert(presale.claimTokens({from: deployer}), "W.PARAMS");
            //FOUR MONTH
            await time.increase(time.duration.minutes(4));
            await expectRevert(presale.claimTokens({from: account_three}), "NOCLAIM");
            await time.increase(time.duration.minutes(1));
            await presale.claimTokens({from: account_two});
            console.log("2: ", (await ritaToken.balanceOf(account_two)).toString());
            await presale.claimTokens({from: account_three});
            console.log("3: ",(await ritaToken.balanceOf(account_three)).toString());
            await presale.claimTokens({from: account_four});
            console.log("4: ",(await ritaToken.balanceOf(account_four)).toString());
            //AFTER FOUR MONTH
            await time.increase(time.duration.minutes(4));
            await expectRevert(presale.claimTokens({from: account_three}), "W.PARAMS");
            console.log("5: ",(await ritaToken.balanceOf(account_five)).toString());
            await presale.claimTokens({from: account_five});
            console.log("5: ",(await ritaToken.balanceOf(account_five)).toString());
        }) */

        /* it("failed txn", async()=> {
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(MINUTE.mul(THREE).add(ONE));
            info.closeTime = info.openTime.add(MINUTE.mul(FIVE).mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(MINUTE);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            let timeForSign = await time.latest();
            info._tokenAmount = (ONE_THOUSAND_TOKENS.mul(TEN)).toString() ;
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            additionalInfo.nativeToken = usdc.address;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            //await expectRevert(factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("500000000")}), "TIME");
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("500000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);

            await presale.approvePresale({from: deployer});
            await usdc.mint(account_two, new BN("100000"));
            await usdc.approve(presale.address, new BN("100000"), {from:account_two});
            await time.increase(time.duration.minutes(4));
            const receipt1 = await presale.invest(new BN("100000"), signature.signature, TIER4, timeForSign, {from: account_two});
            console.log(receipt1);
            console.log((await usdc.balanceOf(presale.address)).toString());
        }) */

        it("test new cancelPresale() and collectFee()", async()=> {
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(MINUTE.mul(EIGHT).add(ONE));
            info.closeTime = info.openTime.add(MINUTE.mul(FIVE).mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(MINUTE);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            let timeForSign = await time.latest();
            info._tokenAmount = (ONE_THOUSAND_TOKENS.mul(TEN)).toString() ;
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            additionalInfo.nativeToken = ZERO_ADDRESS;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            //await expectRevert(factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")}), "Wrong liq param");
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);

            await presale.approvePresale();

            await expectRevert(presale.collectFee(), "W");
            await expectRevert(presale.cancelPresale({from: account_one}), "P.OWNER");
            let balBefore = await ritaToken.balanceOf(account_one);
            let contractBalance = await ritaToken.balanceOf(presale.address);
            await presale.cancelPresale();
            let balAfter = await ritaToken.balanceOf(account_one);
            expect(balAfter.sub(balBefore)).bignumber.equal(contractBalance);
            await time.increase(time.duration.minutes(8));
            //await expectRevert(presale.collectFee({from: account_one}));
            await expectRevert.unspecified(presale.collectFee({from: account_one}));
            console.log(await web3.eth.getBalance(deployer), await web3.eth.getBalance(account_one));
            await presale.collectFee();
            console.log(await web3.eth.getBalance(deployer), await web3.eth.getBalance(account_one));
        })

        /* it("private presale + vesting", async ()=>{
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(DAY.mul(FIVE));
            info.closeTime = info.openTime.add(DAY.mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(DAY);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            let timeForSign = await time.latest();
            info._tokenAmount = "0";
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            additionalInfo.nativeToken = ZERO_ADDRESS;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            //await expectRevert(factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")}), "Wrong liq param");
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);

            //try to register
            await expectRevert(presale.register(ZERO, FOUR, timeForSign, signature.signature, {from: account_two}), "N.REG");
            await time.increase(time.duration.days(4));
            await expectRevert(presale.register(ZERO, FOUR, timeForSign, signature.signature, {from: account_two}), "W.PARAMS");
            await presale.approvePresale({from: deployer});
            await expectRevert(presale.register(ZERO, FOUR, timeForSign, signature.signature, {from: account_two}), "W.PARAMS");

            //try to invest
            const genInfo = await presale.generalInfo.call();
            const collectedFee = genInfo[9];
            console.log("COLLECTED FEE : ", collectedFee.toString());
            await expectRevert(presale.invest(ZERO, signature.signature, TIER2, timeForSign, {from: account_two}), "N.OPEN");

            await time.increase(time.duration.days(1));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER2, timeForSign, {from: account_two, value: new BN("10000000000000000")}), "TIER4/5");
            await presale.invest(TIER1, signature.signature, TIER4, timeForSign, {from: account_three, value: ONE_TOKEN});
            expect(await web3.eth.getBalance(presale.address)).bignumber.equal(ONE_TOKEN.add(collectedFee));
            let investThree = await presale.investments.call(account_three);
            expect(investThree[0]).bignumber.equal(ONE_TOKEN);
            expect(investThree[1]).bignumber.equal(ONE_HUNDRED_TOKENS);

            await time.increase(time.duration.days(1));
            await presale.invest(ZERO, signature.signature, TIER4, timeForSign, {from: account_four, value: ONE_TOKEN});
            let investFour = await presale.investments.call(account_four);
            expect(investFour[0]).bignumber.equal(ONE_TOKEN);
            expect(investFour[1]).bignumber.equal(ONE_HUNDRED_TOKENS);
            expect(await web3.eth.getBalance(presale.address)).bignumber.equal(ONE_TOKEN.mul(TWO).add(collectedFee));

            await time.increase(time.duration.days(1));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER5, timeForSign, {from: account_five, value: THREE_TOKENS}), "(N)ENOUGH");
            await presale.invest(ZERO, signature.signature, TIER5, timeForSign, {from: account_five, value: TWO_TOKEN});
            let investFive = await presale.investments.call(account_five);
            expect(investFive[0]).bignumber.equal(TWO_TOKEN);
            expect(investFive[1]).bignumber.equal(ONE_HUNDRED_TOKENS.mul(TWO));
            expect(await web3.eth.getBalance(presale.address)).bignumber.equal(ONE_TOKEN.mul(FOUR).add(collectedFee));
            await expectRevert(presale.invest(ZERO, signature.signature, TIER5, timeForSign, {from: account_five, value: ONE}), "(N)ENOUGH");

            await time.increase(time.duration.days(3));
            let presaleRitaBalance = await ritaToken.balanceOf(presale.address);
            expect(presaleRitaBalance).bignumber.equal(ONE_HUNDRED_TOKENS.mul(FIVE).add(TEN_TOKENS.mul(FOUR)));
            //expect(presaleRitaBalance).bignumber.equal(ONE_HUNDRED_TOKENS.mul(SEVEN).add(TEN_TOKENS.mul(TWO)));
            console.log("PRESALE RITA BALANCE: ",presaleRitaBalance.toString());
            await expectRevert(presale.claimTokens({from: account_four}), "A.LIQ");
            //await expectRevert(presale.addLiquidity({from: account_one}), "DEV");
            await expectRevert(presale.addLiquidity({from: deployer}), "W.PARAMS");

            //add liquidity
            await time.increase(time.duration.days(1));
            await expectRevert(presale.addLiquidity({from: account_one}), "DEV");
            await presale.addLiquidity({from: deployer});
            presaleRitaBalance = await ritaToken.balanceOf(presale.address);
            expect(presaleRitaBalance).bignumber.equal(ONE_HUNDRED_TOKENS.mul(FOUR).add(TEN_TOKENS.mul(FOUR)));
            //pancakePairInstant = await PancakePair.at(await presale.lpAddress.call());
            await expectRevert(presale.withdrawInvestment(account_five, ONE_HALF_TOKEN, {from: account_five}),"AFTERCAP");
            let ritaBalanceThree = await ritaToken.balanceOf(account_three);
            expect(ritaBalanceThree).bignumber.equal(ZERO);
            await presale.claimTokens({from: account_three});
            ritaBalanceThree = await ritaToken.balanceOf(account_three);
            expect(ritaBalanceThree).bignumber.equal(TEN_TOKENS.mul(FOUR));
            await expectRevert(presale.claimTokens({from: account_two}), "W.PARAMS"); //not an investor
            let threeClaimObj = await presale.claimed.call(account_three);
            console.log("CLAIMED OBJ: ", threeClaimObj[0].toString(), threeClaimObj[1].toString());
            await expectRevert(presale.claimTokens({from: account_three}), "TIME"); //can't claim tokens twice
            ritaBalanceThree = await ritaToken.balanceOf(account_four);
            expect(ritaBalanceThree).bignumber.equal(ZERO);
            await presale.claimTokens({from: account_four});
            ritaBalanceThree = await ritaToken.balanceOf(account_four);
            expect(ritaBalanceThree).bignumber.equal(TEN_TOKENS.mul(FOUR));
            ritaBalanceThree = await ritaToken.balanceOf(account_five);
            expect(ritaBalanceThree).bignumber.equal(ZERO);
            await presale.claimTokens({from: account_five});
            ritaBalanceThree = await ritaToken.balanceOf(account_five);
            expect(ritaBalanceThree).bignumber.equal(TEN_TOKENS.mul(EIGHT));
            console.log((await web3.eth.getBalance(account_one)).toString());
            await presale.collectFundsRaised({from: account_one});
            console.log((await web3.eth.getBalance(account_one)).toString());
            console.log((await web3.eth.getBalance(presale.address)).toString());
            let balanceDev = await web3.eth.getBalance(deployer);
            console.log("BALANCE DEV: ", balanceDev.toString());
            await presale.collectFee({from: deployer});
            balanceDev = await web3.eth.getBalance(deployer);
            console.log("BALANCE DEV: ", balanceDev.toString());
            //console.log("LP TOKEN AMOUNT: ", (await pancakePairInstant.balanceOf(presale.address)).toString());
            await expectRevert(presale.refundLpTokens({from: account_one}),"EARLY");

            await time.increase(time.duration.days(30));
            await presale.refundLpTokens({from: account_one});
            await presale.claimTokens({from: account_three});
            expect(await ritaToken.balanceOf(account_three)).bignumber.equal(TEN_TOKENS.mul(EIGHT));
            await presale.claimTokens({from: account_four});
            expect(await ritaToken.balanceOf(account_four)).bignumber.equal(TEN_TOKENS.mul(EIGHT));
            await presale.claimTokens({from: account_five});
            expect(await ritaToken.balanceOf(account_five)).bignumber.equal(ONE_HUNDRED_TOKENS.add(TEN_TOKENS.mul(SIX)));

            await time.increase(time.duration.days(30));
            console.log("THREE BALANCE: ",(await ritaToken.balanceOf(account_three)).toString());
            await presale.claimTokens({from: account_three});
            console.log("THREE BALANCE: ",(await ritaToken.balanceOf(account_three)).toString());
            threeClaimObj = await presale.claimed.call(account_three);
            console.log("CLAIMED OBJ: ", threeClaimObj[0].toString(), threeClaimObj[1].toString());
            expect(await ritaToken.balanceOf(account_three)).bignumber.equal(ONE_HUNDRED_TOKENS);
            await presale.claimTokens({from: account_four});
            expect(await ritaToken.balanceOf(account_four)).bignumber.equal(ONE_HUNDRED_TOKENS);
            await presale.claimTokens({from: account_five});
            expect(await ritaToken.balanceOf(account_five)).bignumber.equal(ONE_HUNDRED_TOKENS.mul(TWO));
            //console.log("LP TOKEN AMOUNT: ", (await pancakePairInstant.balanceOf(account_one)).toString());
        }) */

        /* it("cancel, change time, else", async()=>{
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            let additionalInfo = require("./presaleCertifiedAddition.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(DAY.mul(FIVE));
            info.closeTime = info.openTime.add(DAY.mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(DAY);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            let timeForSign = await time.latest();
            info._tokenAmount = "0";
            info._timestamp = timeForSign.toString();
            let data = web3.utils.soliditySha3(info.tokenAddress, account_one, '0' , info._timestamp);
            let signature = await web3.eth.accounts.sign(data, "0x8d5fd3150e7d4fb26ab1439bad4d8027d912e90471dfbab871062ee64caee7be");
            info._signature = signature.signature.toString();
            additionalInfo.nativeToken = ZERO_ADDRESS;
            console.log("INFO: ", info, "\nADDITIONAL: ",additionalInfo, "\nLIQUIDITY: ", liquidityInfo,  "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await ritaToken.mint(account_one, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            console.log((await ritaToken.balanceOf(account_one)).toString());
            //await expectRevert(factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")}), "Wrong liq param");
            const receipt = await factory.createPresaleCertified(info, additionalInfo, liquidityInfo, stringInfo, {from: account_one, value: new BN("50000000000000000")});
            console.log(receipt);
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresaleCertified.at(presaleAddress);

            await expectRevert(presale.changePresaleTime(nowTime, nowTime.add(DAY.mul(FIVE)), {from: account_one}), "TIME");
            await presale.changePresaleTime(nowTime.add(TEN.mul(THREE)), nowTime.add(DAY.mul(FIVE)),{from: account_one});
            const balanceBefore = await ritaToken.balanceOf(account_one);
            await presale.cancelPresale({from: deployer});
            const balanceAfter = await ritaToken.balanceOf(account_one);
            expect(balanceAfter.sub(balanceBefore)).bignumber.equal(ONE_HUNDRED_TOKENS.mul(FIVE).add(TEN_TOKENS.mul(FOUR)));
            await time.increase(time.duration.minutes(35));
            await expectRevert(presale.invest(TIER1, signature.signature, TIER4, timeForSign, {from: account_three, value: ONE_TOKEN}), "lala");
        }) */

        /*it('should create presale', async()=> {
            let info = require("./presalePublicInfo.json");
            let liquidityInfo = require("./presalePublicLiq.json");
            let stringInfo = require("./PresalePublicString.json");
            info.tokenAddress = ritaToken.address;
            let nowTime = await time.latest();
            console.log(nowTime.toString());
            info.openTime = nowTime.add(DAY.mul(FIVE));
            info.closeTime = info.openTime.add(DAY.mul(FIVE));
            liquidityInfo.liquidityAllocationTime = info.closeTime.add(DAY);
            info.openTime = info.openTime.toString();
            info.closeTime = info.closeTime.toString();
            liquidityInfo.liquidityAllocationTime = liquidityInfo.liquidityAllocationTime.toString();
            console.log("INFO: ", info, "\nLIQUIDITY: ", liquidityInfo, "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await staking.stake((new BN(8000)).mul(ONE_TOKEN), {from: account_one});
            await staking.stake(new BN(500).mul(ONE_TOKEN), {from: account_two});
            await time.increase(time.duration.days(1));
            const receipt = await factory.createPresalePublic(info, liquidityInfo, stringInfo, {from: account_one, value: ONE_HALF_TOKEN});
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresalePublic.at(presaleAddress);
            await time.increase(time.duration.minutes(30));
            await presale.vote(true, {from: account_two});
            await time.increase(time.duration.minutes(5));
            await staking.stake(ONE_THOUSAND_TOKENS, {from: account_three});
            await expectRevert(presale.vote(true, {from: account_three}), "Not enough Less to vote");
            await time.increase(time.duration.days(1));
            await presale.vote(true, {from: account_three});
            await time.increase(time.duration.days(2));
            await expectRevert(presale.invest({from: account_three, value: ONE_HALF_TOKEN}), "Presale is not open yet or closed");
            await staking.stake(ONE_THOUSAND_TOKENS, {from: account_two});
            await time.increase(time.duration.days(1));
            await presale.collectFee({from: account_one});
            let genInfo = await presale.getGenInfo();
            console.log("FOR SALE: ",genInfo[0].toString(), "\nFOR LIQ: ", genInfo[1].toString());
            await presale.invest({from: account_three, value: ONE_HALF_TOKEN});
            genInfo = await presale.getGenInfo();
            console.log("FOR SALE: ",genInfo[0].toString(), "\nFOR LIQ: ", genInfo[1].toString());
            await expectRevert(presale.withdrawInvestment(account_three, ONE_HALF_TOKEN, {from: account_three}),"Couldn't withdraw investments after softCap collection");
            let balanceEthOTwo = await web3.eth.getBalance(account_two);
            console.log(balanceEthOTwo.toString());
            await expectRevert(presale.invest({from: account_two, value: ONE_TOKEN.sub(TWO_TOKEN.div(TEN))}),"Not enough tokens left");
            await presale.invest({from: account_two, value: ONE_HALF_TOKEN});
            await expectRevert(presale.invest({from: account_three, value: ONE_TOKEN.div(TEN)}), "Hard cap reached");

            await expectRevert(presale.addLiquidity(),"Too early to adding liquidity");
            await time.increase(time.duration.days(6));
            await expectRevert(presale.collectFundsRaised({from:account_one}), "Add liquidity");
            await presale.addLiquidity();
            const pairAddr = await pancakeFactoryInstant.getPair(wethInst.address, ritaToken.address);
            console.log("PAIR ADDRESS: ", pairAddr);
            pancakePairInstant = await PancakePair.at(pairAddr);
            const reserve = await pancakePairInstant.getReserves();
            console.log("RESERVES: ", reserve._reserve0.toString(), " ", reserve._reserve1.toString()); //норм работает

            const ritaBalanceOneBefore = await ritaToken.balanceOf(account_two);
            const ritaBalanceTwoBefore = await ritaToken.balanceOf(account_three);
            await presale.claimTokens({from:account_two});
            await presale.claimTokens({from:account_three});
            const ritaBalanceOneAfetr = await ritaToken.balanceOf(account_two);
            const ritaBalanceTwoAfetr = await ritaToken.balanceOf(account_three);
            expect(ritaBalanceOneAfetr.sub(ritaBalanceOneBefore)).bignumber.equal(ONE_THOUSAND_TOKENS.mul(FIVE));
            expect(ritaBalanceTwoAfetr.sub(ritaBalanceTwoBefore)).bignumber.equal(ONE_THOUSAND_TOKENS.mul(FIVE));
            let ritaContractBalance = await ritaToken.balanceOf(presale.address);
            expect(ritaContractBalance).bignumber.equal(ONE_THOUSAND_TOKENS);

            const vaultBalanceBefore = await web3.eth.getBalance(vault);
            const creatorBalanceBefore = await web3.eth.getBalance(account_one);
            console.log("VAULT BEFORE: ", vaultBalanceBefore.toString(), "\nCREATOR BEFORE: ", creatorBalanceBefore.toString());
            await presale.collectFundsRaised({from:account_one});
            const vaultBalanceAfter = await web3.eth.getBalance(vault);
            const creatorBalanceAfter = await web3.eth.getBalance(account_one);
            console.log("VAULT AFTER: ", vaultBalanceAfter, "\nCREATOR AFTER: ", creatorBalanceAfter); //норм
            await expectRevert(presale.refundLpTokens({from:account_one}), "Too early");
            const lpToken = await ERC20.at(pairAddr);
            let lpContractBalance = await lpToken.balanceOf(presale.address);
            console.log("LP CONSTRCT BALANCE: ", lpContractBalance.toString());
            await time.increase(time.duration.days(10));
            await presale.refundLpTokens({from:account_one});
            lpContractBalance = await lpToken.balanceOf(presale.address);
            expect(lpContractBalance).bignumber.equal(ZERO);
            await presale.getUnsoldTokens({from: account_one});
            ritaContractBalance = await ritaToken.balanceOf(presale.address);
            expect(ritaContractBalance).bignumber.equal(ZERO);
        })*/

        /*it('Stake unlocked and locked tokens', async () => {

            await staking.stakeStart(ONE_HALF_TOKEN, ONE_HALF_TOKEN, {from: account_one});
            await time.increase(time.duration.minutes(30));
            await staking.stakeStart(ONE_TOKEN, ONE_TOKEN, {from: account_two});
            await time.increase(time.duration.minutes(30));
            await staking.rewardTokenDonation(ONE_TOKEN);
            //const balanceRewardBefore = await reward.balanceOf(account_one);
            //expect(balanceRewardBefore).bignumber.equal(ZERO);
            //await staking.withdrawRewardAll({from: account_one});
            //await staking.stakeStart(ONE_TOKEN, ZERO, {from: account_two});
            //const balanceRewardAfter = await reward.balanceOf(account_one);
            //expect(balanceRewardAfter).bignumber.equal(ZERO);

            await time.increase(time.duration.days(1));
            await staking.stakeStart(TWO_TOKEN, TWO_TOKEN, {from: account_three});
            await time.increase(time.duration.minutes(30));
            await staking.rewardTokenDonation(FIVE_TOKENS);

            await time.increase(time.duration.days(1));
            await staking.rewardTokenDonation(SEVEN_TOKENS);

            await time.increase(time.duration.days(1));
            await staking.rewardTokenDonation(SIX_TOKENS);
            await time.increase(time.duration.minutes(30));
            await staking.stakeEnd({from:account_one});
            //await staking.withdrawRewardAll({from:account_two});
            //await staking.withdrawRewardAll({from:account_three});

            await time.increase(time.duration.days(1));
            await staking.rewardTokenDonation(SEVEN_TOKENS);

            await time.increase(time.duration.days(1));
            await staking.stakeEnd({from: account_two});
            await time.increase(time.duration.minutes(30));
            await staking.stakeEnd({from: account_three});

            await time.increase(time.duration.days(1));

            const balanceOne = await reward.balanceOf(account_one);
            const balanceTwo = await reward.balanceOf(account_two);
            const balanceThree = await reward.balanceOf(account_three);
            console.log("ONE: ", parseFloat(balanceOne), "\nTWO: ", parseFloat(balanceTwo), "\nTHREE: ", parseFloat(balanceThree));
            const contractBalance = await reward.balanceOf(staking.address);
            console.log("CONTRACT: ", parseFloat(contractBalance));
        })*/
    }
)