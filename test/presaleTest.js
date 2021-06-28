const { expect } = require('chai');
const { BN, expectEvent, expectRevert, makeInterfaceId, time } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');
//const { exitCode } = require('process');
const ERC20 = artifacts.require("ERC20");
const TestToken = artifacts.require('TestToken');
const TestTokenTwo = artifacts.require('TestTokenTwo');
const LessLibrary = artifacts.require('LessLibrary');
const PresaleFactory = artifacts.require('PresaleFactory');
const PresalePublic = artifacts.require('PresalePublic');
const Staking = artifacts.require('Staking');
//pancake artifacts
const WETH = artifacts.require('WETH');
let wethInst;
const PancakeFactory = artifacts.require('PancakeFactory');
let pancakeFactoryInstant;
const PancakeRouter = artifacts.require('PancakeRouter');
let pancakeRouterInstant;
const PancakePair = artifacts.require('PancakePair');
let pancakePairInstant;
//let pancakePairInst = [];*/

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

contract (
    'Presale',
    ([
        deployer,
        vault,
        account_one,
        account_two,
        account_three
    ]) => {
        before(async function () {
            // Advance to the next block to correctly read time in the solidity "now" function interpreted by ganache
            await time.advanceBlock();
        });

        //contracts
        let library, staking, factory, lessToken, ritaToken;

        beforeEach(async()=>{
            lessToken = await TestToken.deployed();
            ritaToken = await TestTokenTwo.deployed();
            library = await LessLibrary.deployed();
            staking = await Staking.deployed();
            factory = await PresaleFactory.deployed();
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
            library.setUniswapRouter(pancakeRouterInstant.address);
        })

        it("Approve", async()=> {
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
        })

        it('should mint less tokens to accs', async function() {
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
        })

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

        it('should create presale', async()=> {
            /*let balanceOne = await ritaToken.balanceOf(account_one);
            expect(balanceOne).bignumber.equal(ONE_THOUSAND_TOKENS.mul(TEN));*/
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
            /*stringInfo.saleTitle = web3.utils.asciiToHex(stringInfo.saleTitle);*/
            console.log("INFO: ", info, "\nLIQUIDITY: ", liquidityInfo, "\nSTRING INFO: ", stringInfo);
            await ritaToken.approve(factory.address, ONE_THOUSAND_TOKENS.mul(ONE_HUNDRED), {from:account_one});
            await staking.stake((new BN(8000)).mul(ONE_TOKEN), {from: account_one});
            await staking.stake(new BN(500).mul(ONE_TOKEN), {from: account_two});
            await time.increase(time.duration.days(1));
            const receipt = await factory.createPresalePublic(info, liquidityInfo, stringInfo, {from: account_one, value: ONE_HALF_TOKEN});
            const presaleAddress = await library.getPresaleAddress(ZERO);
            const presale = await PresalePublic.at(presaleAddress);
            /*let presaleEthBalance = await web3.eth.getBalance(presale.address);
            console.log("ETH BALANCE: ",presaleEthBalance.toString());*/
            await time.increase(time.duration.minutes(30));
            await presale.vote(true, {from: account_two});
            await time.increase(time.duration.minutes(5));
            await staking.stake(ONE_THOUSAND_TOKENS, {from: account_three});
            await expectRevert(presale.vote(true, {from: account_three}), "Not enough Less to vote");
            await time.increase(time.duration.days(1));
            await presale.vote(true, {from: account_three});
            //const voteTwo = await presale.getMyVote({from: account_two});
            //const voteThree = await presale.getMyVote({from: account_three});
            //console.log("TWO: ", voteTwo.toString(), "\nTHREE: ", voteThree.toString());
            await time.increase(time.duration.days(2));
            await expectRevert(presale.invest({from: account_three, value: ONE_HALF_TOKEN}), "Presale is not open yet or closed");
            await staking.stake(ONE_THOUSAND_TOKENS, {from: account_two});
            await time.increase(time.duration.days(1));
            await presale.collectFee({from: account_one});
            //await lessToken.mint(account_three, (new BN(15)).mul(ONE_THOUSAND_TOKENS));
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
            //expect(vaultBalanceAfter.sub(vaultBalanceBefore)).bignumber.equal(ONE_TOKEN.mul(TWO).div(ONE_HUNDRED));
            //expect(creatorBalanceAfter.sub(creatorBalanceBefore)).bignumber.equal(ONE_TOKEN.sub(ONE_TOKEN.mul(TWO).div(ONE_HUNDRED)));
            //await expectRevert(presale.addLiquidity(),"Too early to adding liquidity");
            /*await expectRevert(presale.vote(true, {from: account_three}), "Voting closed");
            await time.increase(time.duration.days(2));
            await expectRevert(presale.invest({from: account_three, value: new BN(1624755600)}), "Votes not passed");*/
            /*const genInfo = await presale.id;
            console.log("GEN INFO: ", genInfo);*/
            //await expectRevert(factory.createPresalePublic(info, liquidityInfo, stringInfo, {from: account_one}), "Not enough ETH");
        })

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