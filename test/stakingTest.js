const { expect } = require("chai");

const LessStaking = artifacts.require('Staking');
const LP = artifacts.require("TestToken");
const Less = artifacts.require("TestTokenTwo");

const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { BN, expectEvent, expectRevert, makeInterfaceId, time } = require('@openzeppelin/test-helpers');
const { inTransaction } = require("@openzeppelin/test-helpers/src/expectEvent");

const ZERO = new BN(0);
const ONE = new BN(1);
const TWO = new BN(2);
const THREE = new BN(3);
const FOUR = new BN(4);
const FIVE = new BN(5);
const SIX = new BN(6);
const NINE = new BN(9);

const TEN = new BN(10);
const ONE_HUNDRED = TEN.mul(TEN);
const ONE_THOUSAND = ONE_HUNDRED.mul(TEN);

const PERCENT_FACTOR = new BN(1000);
const DECIMALS = new BN(18);
const ONE_ETH = TEN.pow(DECIMALS);
const APPROVE_SUM = ONE_ETH.mul(ONE_THOUSAND);
const stakedLP = ONE_ETH;
const stakedLess = ONE_ETH;
const TIER_1 = new BN(1000);
const TIER_2 = new BN(5000);
const TIER_3 = new BN(20000);
const TIER_4 = new BN(50000);
const TIER_5 = new BN(200000);

contract('Staking', ([deployer, user1, user2, user3, user4, user5]) => {
    before(async function () {
        // Advance to the next block to correctly read time in the solidity "now" function interpreted by ganache
        await time.advanceBlock();
    });

    let staking, lp, less, stakingAddress, lessAddress, lpAddress;

    beforeEach(async () => {
        lp = await LP.new("Less LP Token", "LESSLP");
        lpAddress = lp.address;

        less = await Less.new("Less Token", "LESS");
        lessAddress = less.address;

        staking = await LessStaking.new(lpAddress, lessAddress, new BN("86400"), await time.latest(), { from: deployer });
        stakingAddress = staking.address;

        /* const block = await web3.eth.getBlock("latest");
        timestamp = await block['timestamp']; */
        await lp.mint(user1, TIER_5.mul(ONE_ETH), {from: user1});
        await lp.mint(user2, TIER_5.mul(ONE_ETH), {from: user2});
        await lp.mint(user3, TIER_5.mul(ONE_ETH), {from: user3});
        await lp.mint(user4, TIER_5.mul(ONE_ETH), {from: user4});
        await lp.mint(user5, TIER_5.mul(ONE_ETH), {from: user5});

        await less.mint(user1, TIER_5.mul(ONE_ETH), {from: user1});
        await less.mint(user2, TIER_5.mul(ONE_ETH), {from: user2});
        await less.mint(user3, TIER_5.mul(ONE_ETH), {from: user3});
        await less.mint(user4, TIER_5.mul(ONE_ETH), {from: user4});
        await less.mint(user5, TIER_5.mul(ONE_ETH), {from: user5});

        await lp.approve(stakingAddress, APPROVE_SUM, { from: deployer });
        await less.approve(stakingAddress, APPROVE_SUM, { from: deployer });

        await lp.approve(stakingAddress, APPROVE_SUM, { from: user1 });
        await less.approve(stakingAddress, APPROVE_SUM, { from: user1 });

        await lp.approve(stakingAddress, APPROVE_SUM, { from: user2 });
        await less.approve(stakingAddress, APPROVE_SUM, { from: user2 });

        await lp.approve(stakingAddress, APPROVE_SUM, { from: user3 });
        await less.approve(stakingAddress, APPROVE_SUM, { from: user3 });

        await lp.approve(stakingAddress, APPROVE_SUM, { from: user4 });
        await less.approve(stakingAddress, APPROVE_SUM, { from: user4 });

        await lp.approve(stakingAddress, APPROVE_SUM, { from: user5 });
        await less.approve(stakingAddress, APPROVE_SUM, { from: user5 });
        /* await lp.transfer(user1, stakedLP, { from: deployer });
        await less.transfer(user1, stakedLess, { from: deployer }); */
    });

    /* it("stake correct", async () => {
        const allLpBefore = await staking.allLp();
        expect(allLpBefore).bignumber.equal(ZERO);
        const allLessBefore = await staking.allLess();
        expect(allLessBefore).bignumber.equal(ZERO);
        const lessBalanceBefore = await less.balanceOf(stakingAddress);
        expect(allLessBefore).bignumber.equal(lessBalanceBefore);
        const lpBalanceBefore = await lp.balanceOf(stakingAddress);
        expect(allLpBefore).bignumber.equal(lpBalanceBefore);

        await staking.stake(stakedLP, stakedLess, { from: user1 });

        const allLessAfter = await staking.allLess();
        const allLpAfter = await staking.allLp();
        const lessBalanceaAfter = await less.balanceOf(stakingAddress);
        const lpBalanceAfter = await lp.balanceOf(stakingAddress);

        expect(allLpAfter.sub(allLpBefore)).bignumber.equal(stakedLP);
        expect(allLessAfter.sub(allLessBefore)).bignumber.equal(stakedLess);
        expect(lessBalanceaAfter.sub(lessBalanceBefore)).bignumber.equal(stakedLess);
        expect(lpBalanceAfter.sub(lpBalanceBefore)).bignumber.equal(stakedLP);

        //is stake item changed
        const userStakes = await staking.getUserStakeIds.call(user1);
        const stakeItem = await staking.stakes(userStakes[0]);
        
        const _startTime = stakeItem.startTime;
        const _stakedLp = stakeItem.stakedLp;
        const _stakedLess = stakeItem.stakedLess;
        expect(_startTime).bignumber.gt(ZERO);
        expect(_stakedLp).bignumber.eq(stakedLP);
        expect(_stakedLess).bignumber.eq(stakedLess);
    });
    it("is unstaked correct", async () => {
        const lessBalanceBefore= await less.balanceOf(user1);
        const lpBalanceBefore = await lp.balanceOf(user1);

        await staking.stake(stakedLP, stakedLess, { from: user1 });

        await staking.unstake(0, { from: user1 });

        const allLessAfter = await staking.allLess();
        const allLpAfter = await staking.allLp();
        const lessBalanceAfter = await less.balanceOf(user1);
        const lpBalanceAfter = await lp.balanceOf(user1);
        
        const penaltyD = await staking.penaltyDistributed();
        const penaltyB = await staking.penaltyBurned();
        const penalty = penaltyD.add(penaltyB);
        const penaltyLP = stakedLP.mul(penalty).div(PERCENT_FACTOR);
        const penaltyLess = stakedLess.mul(penalty).div(PERCENT_FACTOR);

        expect(allLessAfter).bignumber.equal(ZERO);
        expect(allLpAfter).bignumber.equal(ZERO);
        expect(lessBalanceBefore.sub(lessBalanceAfter)).bignumber.equal(penaltyLess);
        expect(lpBalanceBefore.sub(lpBalanceAfter)).bignumber.equal(penaltyLP);

        //is stake item removed
        const userStakes = await staking.getUserStakeIds.call(deployer);
        expect(userStakes.length).eq(0);

        const stakeItem = await staking.stakes(0);
        
        const _startTime = stakeItem.startTime;
        const _stakedLp = stakeItem.stakedLp;
        const _stakedLess = stakeItem.stakedLess;
        expect(_startTime).bignumber.eq(ZERO);
        expect(_stakedLp).bignumber.eq(ZERO);
        expect(_stakedLess).bignumber.eq(ZERO);
        
    });
    it('is rewards takes correct', async () => {
        await staking.setMinTimeToStake(10);

        const b1b = await lp.balanceOf(user1);
        const b2b = await lp.balanceOf(user2);
        const b3b = await lp.balanceOf(user3);
        const b4b = await lp.balanceOf(user4);

        const standartPenalty = ONE_ETH.mul(TEN).div(PERCENT_FACTOR);
        const sum1 = ONE_ETH;
        await staking.stake(sum1, sum1, { from: user1 });

        const sum2 = ONE_ETH.mul(TWO);
        await lp.approve(stakingAddress, sum2, { from: user2 });
        await less.approve(stakingAddress, sum2, { from: user2 });
        await lp.transfer(user2, sum2, { from: deployer });
        await less.transfer(user2, sum2, { from: deployer });
        await staking.stake(sum2, sum2, { from: user2 });

        const sum3 = ONE_ETH.mul(THREE);
        await lp.approve(stakingAddress, sum3, { from: user3 });
        await less.approve(stakingAddress, sum3, { from: user3 });
        await lp.transfer(user3, sum3, { from: deployer });
        await less.transfer(user3, sum3, { from: deployer });
        await staking.stake(sum3, sum3, { from: user3 });

        const sum4 = ONE_ETH.mul(FOUR);
        await lp.approve(stakingAddress, sum4, { from: user4 });
        await less.approve(stakingAddress, sum4, { from: user4 });
        await lp.transfer(user4, sum4, { from: deployer });
        await less.transfer(user4, sum4, { from: deployer });
        await staking.stake(sum4, sum4, { from: user4 });

        
        await staking.unstake(0, { from: user1 })
        const b1a = await lp.balanceOf(user1);
        expect(b1b.sub(b1a)).bignumber.eq(standartPenalty);

        const rew2 = await staking.getLessRewradsAmount.call(1);
        const rew3 = await staking.getLessRewradsAmount.call(2);
        const rew4 = await staking.getLessRewradsAmount.call(3);

        // await setTimeout(async () => {
        //     expect(await staking.isMinTimePassed(1)).true;
        //     await staking.unstake(1, { from: user2 })
        //     const b2a = await lp.balanceOf(user2);
        //     expect(b2a.sub(b2b)).bignumber.eq(rew2);

            
        //     await staking.unstake(2, { from: user3 })
        //     const b3a = await lp.balanceOf(user3);
        //     expect(b3a.sub(b3b)).bignumber.eq(rew3);

            
        //     await staking.unstake(3, { from: user4 })
        //     const b4a = await lp.balanceOf(user4);
        //     expect(b4a.sub(b4b)).bignumber.eq(rew4);
        // }, 11 * 1000);
    });
    it("is tires works correct", async () => {
        const sum1 = ONE_ETH.mul(TIER_1);
        const sum2 = ONE_ETH.mul(TIER_2);
        const sum3 = ONE_ETH.mul(TIER_3);
        const sum4 = ONE_ETH.mul(TIER_4);
        const sum5 = ONE_ETH.mul(TIER_5);

        //await lp.approve(stakingAddress, ONE_ETH, { from: deployer });
        await less.approve(stakingAddress, ONE_ETH, { from: deployer });
       // await lp.mint(user1, ONE_ETH);
        await less.mint(user1, ONE_ETH);
        await staking.stake(0, ONE_ETH, { from: deployer });

        await lp.approve(stakingAddress, sum1, { from: user1 });
        await less.approve(stakingAddress, sum1, { from: user1 });
        //await lp.mint(user1, sum1);
        await less.mint(user1, sum1);
        await staking.stake(0, sum1, { from: user1 });

        
        await lp.approve(stakingAddress, sum2, { from: user2 });
        await less.approve(stakingAddress, sum2, { from: user2 });
       // await lp.mint(user2, sum2);
        await less.mint(user2, sum2);
        await staking.stake(0, sum2, { from: user2 });

        
        await lp.approve(stakingAddress, sum3, { from: user3 });
        await less.approve(stakingAddress, sum3, { from: user3 });
        //await lp.mint(user3, sum3);
        await less.mint(user3, sum3);
        await staking.stake(0, sum3, { from: user3 });

        
        await lp.approve(stakingAddress, sum4, { from: user4 });
        await less.approve(stakingAddress, sum4, { from: user4 });
        //await lp.mint(user4, sum4);
        await less.mint(user4, sum4);
        await staking.stake(0, sum4, { from: user4 });

        await lp.approve(stakingAddress, sum5, { from: user5 });
        await less.approve(stakingAddress, sum5, { from: user5 });
        //await lp.mint(user5, sum5);
        await less.mint(user5, sum5);
        await staking.stake(0, sum5, { from: user5 });

        const tier0 = await staking.getUserTier(deployer);
        const tier1 = await staking.getUserTier(user1);
        const tier2 = await staking.getUserTier(user2);
        const tier3 = await staking.getUserTier(user3);
        const tier4 = await staking.getUserTier(user4);
        const tier5 = await staking.getUserTier(user5);

        expect(tier0).bignumber.eq(ZERO);
        expect(tier1).bignumber.eq(ONE);
        expect(tier2).bignumber.eq(TWO);
        expect(tier3).bignumber.eq(THREE);
        expect(tier4).bignumber.eq(FOUR);
        expect(tier5).bignumber.eq(FIVE);

    }); */

    
    /* it('test', async()=>{
        await staking.stake(ONE_ETH, FIVE.mul(ONE_ETH), {from: user1});
        await staking.stake(ZERO, THREE.mul(ONE_ETH), {from: user2});
        await staking.stake(ONE_ETH, ZERO, {from: user3});
        await expectRevert(staking.stake(ZERO, ZERO, {from: user4}), "Error: zero staked tokens");
        await staking.stake(TWO.mul(ONE_ETH), TWO.mul(ONE_ETH), {from: user4});
        let lessBalance = await less.balanceOf(stakingAddress);
        let lpBalance = await lp.balanceOf(stakingAddress);
        expect(lessBalance).bignumber.equal(TEN.mul(ONE_ETH));
        expect(lpBalance).bignumber.equal(FOUR.mul(ONE_ETH));
        expect(await staking.getOverallBalanceInLess()).bignumber.equal(lessBalance.add(lpBalance.mul(ONE_HUNDRED.mul(THREE))));
        await time.increase(time.duration.days(4));

        await expectRevert(staking.unstake(ZERO, {from: user3}), "Not ur stake");
        await staking.unstake(ZERO, {from: user1});
        let lpRew = await staking.totalLpRewards.call();
        let lessRew = await staking.totalLessRewards.call();
        expect(lpRew).bignumber.equal(ONE_ETH.mul(new BN("25")).div(ONE_HUNDRED.mul(TEN)));
        expect(lessRew).bignumber.equal((new BN("125")).mul(ONE_ETH).div(ONE_THOUSAND));
        await expectRevert(staking.unstake(ZERO, {from: deployer}), "Error: you haven't stakes");
        await staking.stake(ZERO, ONE_ETH, {from: user1});
        await expectRevert(staking.unstake(ZERO, {from: user1}), "Not ur stake");
        await time.increase(time.duration.days(6));

        await staking.unstake(TWO, {from: user3});
        lpRew = await staking.totalLpRewards.call();
        lessRew = await staking.totalLessRewards.call();
        expect(lpRew).bignumber.equal(ONE_ETH.mul(FIVE).div(ONE_HUNDRED));
        expect(lessRew).bignumber.equal((new BN("125")).mul(ONE_ETH).div(ONE_THOUSAND));
        await time.increase(time.duration.days(24));

        const lessBeforeOne = await less.balanceOf(user1);
        console.log("BEFORE: ",lessBeforeOne.toString());
        const lpBeforeOne = await lp.balanceOf(user1);
        const lessRewards = await staking.getLessRewradsAmount(FOUR);
        console.log(lessRewards.toString());
        expect(await staking.getLpRewradsAmount(FOUR)).bignumber.equal(ZERO);
        const receipt = await staking.unstake(FOUR, {from: user1});
        console.log(receipt);
        const lessAfterOne = await less.balanceOf(user1);
        console.log("AFTER: ",lessAfterOne.toString());
        const lpAfterOne = await lp.balanceOf(user1);
        //console.log((await staking.allLess.call()).toString());
        expect(lessAfterOne.sub(lessBeforeOne)).bignumber.equal(ONE_ETH.add(lessRewards));
        expect(lpBeforeOne).bignumber.equal(lpAfterOne);
        await expectRevert(staking.unstakeWithoutPenalty(ZERO, {from: deployer}), "Error: you haven't stakes");
        const lessRewThree = await staking.getLessRewradsAmount(THREE);
        const lprewThree = await staking.getLpRewradsAmount(THREE);
        const lpThreeBefore = await lp.balanceOf(user4);
        const lessThreeBefore = await less.balanceOf(user4);
        const allLessrew = await staking.totalLessRewards.call();
        const allLprew = await staking.totalLpRewards.call();
        console.log("LESS REW: ", lessRewThree.toString(), " LP REW: ", lprewThree.toString());
        console.log("total less rew: ", allLessrew.toString(), "total lp rew: ", allLprew.toString());
        console.log("all less: ", (await staking.allLess.call()).toString(), " all lp: ", (await staking.allLp.call()).toString())
        await staking.unstake(THREE, {from: user4});
        const lpThreeAfetr = await lp.balanceOf(user4);
        const lessThreeAfter = await less.balanceOf(user4);
        expect(lessThreeAfter.sub(lessThreeBefore)).bignumber.equal(ONE_ETH.mul(TWO).add(lessRewThree));
        expect(lpThreeAfetr.sub(lpThreeBefore)).bignumber.equal(ONE_ETH.mul(TWO).add(lprewThree));
        await expectRevert(staking.unstake(THREE, {from: user4}), "Error: you haven't stakes");
        //console.log("all less: ", (await staking.allLess.call()).toString(), " all lp: ", (await staking.allLp.call()).toString())
        const lastRewLess = await staking.getLessRewradsAmount(ONE);
        const lastRewLp = await staking.getLpRewradsAmount(ONE);
        console.log(lastRewLess.toString(), lastRewLp.toString());
        const lastLessBal = await less.balanceOf(user2);
        const lastLpBal = await lp.balanceOf(user2);
        await staking.unstake(ONE, {from: user2});
        const lastLessAfetr = await less.balanceOf(user2);
        const lastLpAfter = await lp.balanceOf(user2);
        expect(lastLessAfetr.sub(lastLessBal)).bignumber.equal(ONE_ETH.mul(THREE).add(lastRewLess));
        expect(lastLpAfter.sub(lastLpBal)).bignumber.equal(lastRewLp);
    })

    it("staking twice", async()=>{
        await staking.stake(ZERO, ONE_ETH, {from:user1});
        await staking.stake(ZERO, THREE.mul(ONE_ETH), {from: user2});
        await staking.stake(ONE_ETH, ZERO, {from: user3});
        await staking.stake(ZERO, ONE_ETH, {from:user1});
        await time.increase(time.duration.days(24));
        await staking.stake(ZERO, ONE_ETH, {from:user1});
        await staking.unstake(ZERO, {from: user1});
        await time.increase(time.duration.days(1));
        await expectRevert(staking.unstake(ZERO, {from: user1}), "Not ur stake");
    }) */

    /* it("test2", async()=>{
        //DAY0
        await staking.stake(ONE_ETH, ONE_ETH, {from: user1});
        await staking.addRewards(TEN.mul(ONE_ETH), TEN.mul(ONE_ETH), {from: deployer});
        await time.increase(time.duration.days(1));
        //DAY1
        await staking.stake(ONE_ETH, ONE_ETH, {from: user2});
        let depositOne = await staking.getRewardDeposits(ZERO);
        for (let i=0; i<5; i++){
            console.log(depositOne[i].toString());
        }
        await time.increase(time.duration.days(1));
        await staking.addRewards(TEN.mul(ONE_ETH), TEN.mul(ONE_ETH), {from: deployer});
        await time.increase(time.duration.days(30));
        //DAY1
        let balanceBeforeLp = await lp.balanceOf(user1);
        let balanceBeforeLess = await less.balanceOf(user1);
        let ids = await staking.getUserStakeIds(user1);
        console.log("ID: ",ids.toString());
        await staking.unstake(ZERO, {from: user1});
        ids = await staking.getUserStakeIds(user1);
        console.log("ID: ",ids.toString());
        depositOne = await staking.getRewardDeposits(TWO);
        for (let i=0; i<5; i++){
            console.log(depositOne[i].toString());
        }
        let balanceAfetrLp = await lp.balanceOf(user1);
        let balanceAfetrLess = await less.balanceOf(user1);
        expect(balanceAfetrLp.sub(balanceBeforeLp)).bignumber.equal((new BN("15")).mul(ONE_ETH).add(ONE_ETH));
        expect(balanceAfetrLess.sub(balanceBeforeLess)).bignumber.equal((new BN("15")).mul(ONE_ETH).add(ONE_ETH));
        balanceBeforeLp = await lp.balanceOf(user2);
        balanceBeforeLess = await less.balanceOf(user2);
        await staking.unstake(ONE, {from: user2});
        balanceAfetrLp = await lp.balanceOf(user2);
        balanceAfetrLess = await less.balanceOf(user2);
        expect(balanceAfetrLp.sub(balanceBeforeLp)).bignumber.equal((new BN("5")).mul(ONE_ETH).add(ONE_ETH));
        expect(balanceAfetrLess.sub(balanceBeforeLess)).bignumber.equal((new BN("5")).mul(ONE_ETH).add(ONE_ETH));
    }) */

    it("test", async()=>{
        //DAY0
        await staking.stake(ONE_ETH, FIVE.mul(ONE_ETH), {from: user1});
        let stakeZero = await staking.getUserStakeIds(user1);
        console.log(stakeZero.toString());
        //console.log((await staking.currentDay()).toString());
        await time.increase(time.duration.days(1));
        //DAY1
        await staking.stake(ZERO, THREE.mul(ONE_ETH), {from: user2});
        await time.increase(time.duration.days(1));
        //DAY2
        await staking.stake(ONE_ETH, ZERO, {from: user3});
        await time.increase(time.duration.days(1));
        //DAY3
        await expectRevert(staking.stake(ZERO, ZERO, {from: user4}), "Error: zero staked tokens");
        await staking.stake(TWO.mul(ONE_ETH), TWO.mul(ONE_ETH), {from: user4});
        await time.increase(time.duration.days(1));
        //DAY4
        await staking.unstake(ZERO, {from: user1});
        let reward = await staking.getTodayPenalty();
        console.log(reward[0].toString(), reward[1].toString());
        let totalLpRew = await staking.totalLpRewards.call();
        let totalLessRew = await staking.totalLessRewards.call();
        console.log(totalLpRew.toString(), totalLessRew.toString());
        expect(totalLpRew).bignumber.equal(ONE_ETH.mul(new BN("25")).div(ONE_THOUSAND));
        expect(totalLessRew).bignumber.equal(ONE_ETH.mul(new BN("125")).div(ONE_THOUSAND));
        await time.increase(time.duration.days(1));
        //DAY5
        await staking.stake(ONE_ETH, ONE_ETH, {from: deployer});
        let deposit = await staking.getRewardDeposits(FOUR);
        console.log(deposit[4]);
        expect(deposit[2]).bignumber.equal(totalLpRew);
        expect(deposit[3]).bignumber.equal(totalLessRew);
        reward = await staking.getTodayPenalty();
        expect(reward[0]).bignumber.equal(ZERO);
        expect(reward[1]).bignumber.equal(ZERO);
        await staking.unstake(ONE, {from: user2});
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        expect(totalLpRew).bignumber.equal(ONE_ETH.mul(new BN("25")).div(ONE_THOUSAND));
        expect(totalLessRew).bignumber.equal(ONE_ETH.mul(TWO).div(TEN));
        deposit = await staking.getRewardDeposits(ONE);
        expect(new BN(deposit[4].length)).bignumber.equal(ONE);

        await time.increase(time.duration.days(5));
        //DAY10
        console.log("LP LESS: ", (await staking.allLp.call()).toString(), (await staking.allLess.call()).toString());
        deposit = await staking.getRewardDeposits(ONE);
        expect(new BN(deposit[4].length)).bignumber.equal(ONE);
        reward = await staking.getTodayPenalty();
        expect(reward[0]).bignumber.equal(ZERO);
        expect(reward[1]).bignumber.equal(ONE_ETH.mul(new BN("75")).mul(TWO).div(ONE_THOUSAND));
        await staking.stake(TEN.mul(ONE_ETH), ZERO, {from: user1});
        console.log("LP LESS: ", (await staking.allLp.call()).toString(), (await staking.allLess.call()).toString())
        deposit = await staking.getRewardDeposits(FIVE);
        expect(new BN(deposit[4].length)).bignumber.equal(TWO);
        expect(deposit[2]).bignumber.equal(ZERO);
        expect(deposit[3]).bignumber.equal(ONE_ETH.mul(new BN("75")).mul(TWO).div(ONE_THOUSAND));

        await time.increase(time.duration.days(20));
        //DAY30
        await staking.stake(ONE.mul(ONE_ETH), TWO.mul(ONE_ETH), {from: user3});
        console.log("LP LESS: ", (await staking.allLp.call()).toString(), (await staking.allLess.call()).toString())
        await expectRevert(staking.unstake(TWO, {from: user1}), "Not ur stake");
        let balanceBefore = await lp.balanceOf(user3);
        let lessReward = await staking.getLessRewradsAmount(TWO);
        expect(lessReward).bignumber.equal(ZERO);
        let lpReward = await staking.getLpRewradsAmount(TWO);
        expect(lpReward).bignumber.equal(ONE_ETH.mul(new BN("25")).div(ONE_THOUSAND.mul(THREE)));
        let stake = await staking.stakes.call(FOUR);
        console.log(stake.startTime.toString(), stake.stakedLp.toString(), stake.stakedLess.toString());
        await time.increase(time.duration.days(2));
        //DAY32
        const balBe = await less.balanceOf(user3);
        await staking.unstake(TWO, {from: user3});
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        //expect(totalLpRew).bignumber.equal(ONE_ETH.mul(new BN("25")).mul(TWO).div(ONE_THOUSAND.mul(THREE)));
        expect(totalLessRew).bignumber.equal(ONE_ETH.mul(TWO).div(TEN));
        console.log("LP LESS: ", (await staking.allLp.call()).toString(), (await staking.allLess.call()).toString())
        const balAf = await less.balanceOf(user3);
        expect(balAf.sub(balBe)).bignumber.equal(ZERO);
        let balanceAfter = await lp.balanceOf(user3);
        expect(balanceAfter.sub(balanceBefore)).bignumber.equal(ONE_ETH.add(ONE_ETH.mul(new BN("25")).div(ONE_THOUSAND.mul(THREE))));
        await staking.addRewards(ONE_ETH.mul(new BN("14")), FIVE.mul(ONE_ETH), {from: deployer});
        await time.increase(time.duration.days(4));
        //DAY36
        let balanceBeforeLp = await lp.balanceOf(deployer);
        let balanceBeforeLess = await less.balanceOf(deployer);
        lpReward = await staking.getLpRewradsAmount(FOUR);
        lessReward = await staking.getLessRewradsAmount(FOUR);
        console.log("FOUR's STAKE: ", lpReward.toString(), lessReward.toString());
        await staking.unstakeWithoutPenalty(FOUR, {from: deployer});
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        console.log("TOTAL REW: ", totalLpRew.toString(), totalLessRew.toString());
        expect(totalLpRew).bignumber.equal(new BN("13016666666666666667"));
        expect(totalLessRew).bignumber.equal(new BN("4150000000000000000"));
        let balanceAfterLp = await lp.balanceOf(deployer);
        let balanceAfterLess = await less.balanceOf(deployer);
        expect(balanceAfterLp.sub(balanceBeforeLp)).bignumber.equal(TWO.mul(ONE_ETH));
        expect(balanceAfterLess.sub(balanceBeforeLess)).bignumber.equal(ONE_ETH.mul(new BN("105")).div(ONE_HUNDRED).add(ONE_ETH));
        balanceBeforeLp = await lp.balanceOf(user4);
        balanceBeforeLess = await less.balanceOf(user4);
        await staking.unstake(THREE, {from: user4});
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        console.log("TOTAL REW: ", totalLpRew.toString(), totalLessRew.toString());
        balanceAfterLp = await lp.balanceOf(user4);
        balanceAfterLess = await less.balanceOf(user4);
        expect(balanceAfterLp.sub(balanceBeforeLp)).bignumber.equal(TWO.mul(ONE_ETH).add((new BN("25")).mul(TWO.mul(ONE_ETH)).div(ONE_THOUSAND.mul(THREE))).add(TWO.mul(ONE_ETH)));
        expect(balanceAfterLess.sub(balanceBeforeLess)).bignumber.equal(FIVE.mul(ONE_ETH).div(ONE_HUNDRED).add(ONE_ETH.div(TEN)).add(FOUR.mul(ONE_ETH)));
        expect(await staking.participants.call()).bignumber.equal(TWO);
        await time.increase(time.duration.days(4));
        //DAY40
        balanceBeforeLp = await lp.balanceOf(user1);
        balanceBeforeLess = await less.balanceOf(user1);
        let toadyPenalty = await staking.getTodayPenalty();
        expect(toadyPenalty[0]).bignumber.equal(ZERO);
        expect(toadyPenalty[1]).bignumber.equal(ZERO);
        await staking.unstake(FIVE, {from: user1});
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        console.log("TOTAL REW: ", totalLpRew.toString(), totalLessRew.toString());
        balanceAfterLp = await lp.balanceOf(user1);
        balanceAfterLess = await less.balanceOf(user1);
        expect(balanceAfterLp.sub(balanceBeforeLp)).bignumber.equal(TEN.mul(ONE_ETH).mul(TWO));
        expect(balanceAfterLess.sub(balanceBeforeLess)).bignumber.equal(ZERO);
        expect(await staking.participants.call()).bignumber.equal(ONE);
        await time.increase(time.duration.days(1));
        //DAY41
        lessReward = await staking.getLessRewradsAmount(SIX);
        expect(lessReward).bignumber.equal(ONE_ETH.mul(TWO));
        lpReward = await staking.getLpRewradsAmount(SIX);
        expect(lpReward).bignumber.equal(ONE_ETH);
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        expect(totalLessRew).bignumber.equal(TWO.mul(ONE_ETH));
        expect(totalLpRew).bignumber.equal(ONE_ETH.add(ONE));
        expect(await staking.participants.call()).bignumber.equal(ONE); 
        toadyPenalty = await staking.getTodayPenalty();
        expect(toadyPenalty[0]).bignumber.equal(ZERO);
        expect(toadyPenalty[1]).bignumber.equal(ZERO); 
        await staking.unstake(SIX, {from: user3});
        toadyPenalty = await staking.getTodayPenalty();
        expect(toadyPenalty[0]).bignumber.equal((new BN("25")).mul(ONE_ETH).div(ONE_THOUSAND).add(ONE_ETH));
        expect(toadyPenalty[1]).bignumber.equal(FIVE.mul(ONE_ETH).div(ONE_HUNDRED).add(ONE_ETH.mul(TWO))); 
        expect(await staking.participants.call()).bignumber.equal(ZERO);
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        console.log("TOTAL REW: ", totalLpRew.toString(), totalLessRew.toString());
        //expect(totalLessRew).bignumber.equal(new BN("2075000000000000000").add((new BN("25")).mul(ONE_ETH).div(ONE_THOUSAND)));
        //expect(totalLpRew).bignumber.equal(ONE_ETH.add(ONE).add(FIVE.mul(ONE_ETH).div(ONE_HUNDRED)));
        await staking.stake(ONE_ETH, ONE_ETH, {from: user1});
        let rewDep3 = await staking.getRewardDeposits(new BN("41"));
        for (let i=0; i<5; i++){
            console.log(rewDep3[i].toString());
        }
        await time.increase(time.duration.days(1));
        //DAY42
        await staking.stake(ONE_ETH, ONE_ETH, {from: user1});
        expect(await staking.participants.call()).bignumber.equal(ONE);
        await time.increase(time.duration.days(29));
        //DAY71
        balanceBeforeLp = await lp.balanceOf(user1);
        balanceBeforeLess = await less.balanceOf(user1);
        lessReward = await staking.getLessRewradsAmount(new BN("7"));
        //expect(lessReward).bignumber.equal(ONE_ETH.mul(TWO));
        lpReward = await staking.getLpRewradsAmount(new BN("7"));
        //expect(lpReward).bignumber.equal(ONE_ETH);
        console.log("REW: ",lpReward.toString(), lessReward.toString());
        const rewDep32 = await staking.getRewardDeposits(new BN("41"));
        for (let i=0; i<5; i++){
            console.log(rewDep32[i].toString());
        }
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        console.log("TOTAL REW: ", totalLpRew.toString(), totalLessRew.toString());
        await staking.unstake(new BN("7"), {from: user1});
        balanceAfterLp = await lp.balanceOf(user1);
        balanceAfterLess = await less.balanceOf(user1);
        expect(balanceAfterLp.sub(balanceBeforeLp)).bignumber.equal(lpReward.add(ONE_ETH));
        expect(balanceAfterLess.sub(balanceBeforeLess)).bignumber.equal(lessReward.add(ONE_ETH));
        await time.increase(time.duration.days(1));
        const rewDep41 = await staking.getRewardDeposits(new BN("41"));
        for (let i=0; i<5; i++){
            console.log(rewDep41[i].toString());
        }
        //DAY72
        balanceBeforeLp = await lp.balanceOf(user1);
        balanceBeforeLess = await less.balanceOf(user1);
        lessReward = await staking.getLessRewradsAmount(new BN("8"));
        //expect(lessReward).bignumber.equal(ONE_ETH.mul(TWO));
        lpReward = await staking.getLpRewradsAmount(new BN("8"));
        //expect(lpReward).bignumber.equal(ONE_ETH);
        console.log("REW: ",lpReward.toString(), lessReward.toString());
        stake = await staking.stakes.call(new BN("8"));
        console.log("STAKE8: ", stake.startTime.toString(), stake.stakedLp.toString(), stake.stakedLess.toString());
        await staking.unstake(new BN("8"), {from: user1});
        balanceAfterLp = await lp.balanceOf(user1);
        balanceAfterLess = await less.balanceOf(user1);
        expect(balanceAfterLp.sub(balanceBeforeLp)).bignumber.equal(ONE_ETH);
        expect(balanceAfterLess.sub(balanceBeforeLess)).bignumber.equal(ONE_ETH);
        totalLpRew = await staking.totalLpRewards.call();
        totalLessRew = await staking.totalLessRewards.call();
        console.log("TOTAL REW: ", totalLpRew.toString(), totalLessRew.toString());
    })

    /* it("test", async()=>{
        await staking.stake(ONE_ETH, FIVE.mul(ONE_ETH), {from: user1});
        let stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        for(let i=0; i<5; i++){
            await staking.stake(ONE_ETH, FIVE.mul(ONE_ETH), {from: user1});
            stakeIds = await staking.getUserStakeIds(user1);
            console.log(stakeIds.toString());
        }
        await staking.unstake(ZERO, {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        await staking.unstake(TWO, {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        await staking.stake(ONE_ETH, FIVE.mul(ONE_ETH), {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        await staking.unstake(FOUR, {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        await staking.unstake(ONE, {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        await staking.unstake(THREE, {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
        await staking.unstake(FIVE, {from: user1});
        stakeIds = await staking.getUserStakeIds(user1);
        console.log(stakeIds.toString());
    }) */
});