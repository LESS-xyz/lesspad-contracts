const { expect } = require("chai");

const LessStaking = artifacts.require('Staking');
const LP = artifacts.require("TestToken");
const Less = artifacts.require("TestTokenTwo");
const Lib = artifacts.require("LessLibrary");

const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { BN } = require('@openzeppelin/test-helpers');

const ZERO = new BN(0);
const ONE = new BN(1);
const TWO = new BN(2);
const THREE = new BN(3);
const FOUR = new BN(4);
const FIVE = new BN(5);

const TEN = new BN(10);

const PERCENT_FACTOR = new BN(1000);
const DECIMALS = new BN(18);
const ONE_ETH = TEN.pow(DECIMALS);
const APPROVE_SUM = ONE_ETH.mul(TEN);
const stakedLP = ONE_ETH;
const stakedLess = ONE_ETH;
const TIER_1 = new BN(1000);
const TIER_2 = new BN(5000);
const TIER_3 = new BN(20000);
const TIER_4 = new BN(50000);
const TIER_5 = new BN(200000);

contract('Staking', ([deployer, user1, user2, user3, user4, user5]) => {
    let staking, lp, less, lib, timestamp, stakingAddress, lessAddress, lpAddress, libAddress;

    beforeEach(async () => {
        lp = await LP.new("Less LP Token", "LESSLP");
        lpAddress = lp.address;

        less = await Less.new("Less Token", "LESS");
        lessAddress = less.address;

        lib = await Lib.new("0x110a13FC3efE6A245B50102D2d79B3E76125Ae83", "0x110a13FC3efE6A245B50102D2d79B3E76125Ae83","0x110a13FC3efE6A245B50102D2d79B3E76125Ae83","0x110a13FC3efE6A245B50102D2d79B3E76125Ae83");
        libAddress = lib.address;

        staking = await LessStaking.new(lpAddress, lessAddress, libAddress, { from: deployer });
        stakingAddress = staking.address;

        const block = await web3.eth.getBlock("latest");
        timestamp = await block['timestamp'];

        await lp.approve(stakingAddress, APPROVE_SUM, { from: deployer });
        await less.approve(stakingAddress, APPROVE_SUM, { from: deployer });

        await lp.approve(stakingAddress, APPROVE_SUM, { from: user1 });
        await less.approve(stakingAddress, APPROVE_SUM, { from: user1 });

        await lp.transfer(user1, stakedLP, { from: deployer });
        await less.transfer(user1, stakedLess, { from: deployer });
    });

    it("is stake correct", async () => {
        const allLpBefore = await staking.allLp();
        const allLessBefore = await staking.allLess();
        const lessBalanceBefore = await less.balanceOf(stakingAddress);
        const lpBalanceBefore = await lp.balanceOf(stakingAddress);

        await staking.stake(stakedLP, stakedLess, { from: deployer });

        const allLessAfter = await staking.allLess();
        const allLpAfter = await staking.allLp();
        const lessBalanceaAfter = await less.balanceOf(stakingAddress);
        const lpBalanceAfter = await lp.balanceOf(stakingAddress);

        expect(allLpAfter.sub(allLpBefore)).bignumber.equal(stakedLP);
        expect(allLessAfter.sub(allLessBefore)).bignumber.equal(stakedLess);
        expect(lessBalanceaAfter.sub(lessBalanceBefore)).bignumber.equal(stakedLess);
        expect(lpBalanceAfter.sub(lpBalanceBefore)).bignumber.equal(stakedLP);

        //is stake item changed
        const userStakes = await staking.getUserStakeIds.call(deployer);
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

    });

    
    
});