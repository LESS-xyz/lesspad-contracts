// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelincontracts\tokenERC20IERC20.sol";
import "@openzeppelincontractsaccessOwnable.sol";
import "./IUniswapV2Pair.sol";

/**
 *@dev Staking contract with penalty
 *
 */
contract LessStaking is Ownable {
    using SafeMath for uint256;

    uint24 public constant SEC_IN_DAY = 86400;

    IERC20 public lessToken;
    IUniswapV2Pair public lpToken;

    uint256 public minDaysStake = 7;
    uint16 public penaltyDistributed = 5; //100% = 1000
    uint16 public penaltyBurned = 5; //100% = 1000
    uint256 public lessPerLp = 300; //1 LP = 300 LESS

    uint256 public stakeIdLast;

    uint256 public allLp;
    uint256 public allLess;

    struct StakeItem {
        uint256 stakeId;
        uint256 startTime;
        uint256 stakedLp;
        uint256 stakedLess;
        uint256 lpEarned;
        uint256 lessEarned;
    }

    event Staked(
        address staker,
        uint256 stakeId,
        uint256 startTime,
        uint256 stakedLp,
        uint256 stakedLess
    );

    struct Unstake {
        address staker;
        uint256 stakeId;
        uint256 unstakeTime;
        uint256 unstakedLp;
        uint256 unstakedLess;
        uint256 lpRewards;
        uint256 lessRewards;
        bool isUnstakedEarlier;
        bool isUnstakedFully;
    }

    event Unstaked(Unstake);

    enum BalanceType {
        Less,
        Lp,
        Both
    }

    mapping(address => StakeItem[]) public stakeList;

    address[] stakers;

    constructor(IUniswapV2Pair _lp, IERC20 _less) {
        lessToken = _less;
        lpToken = _lp;
    }

    /**
     * @dev stake tokens
     * @param lpAmount Amount of staked LP tokens
     * @param lessAmount Amount of staked Less tokens
     */

    function stake(uint256 lpAmount, uint256 lessAmount) external {
        require(lpAmount > 0 || lessAmount > 0, "Error: zero staked tokens");
        if (lpAmount > 0) {
            require(
                lpToken.transferFrom(_msgSender(), address(this), lpAmount),
                "Error: LP token tranfer failed"
            );
        }
        if (lessAmount > 0) {
            require(
                lessToken.transferFrom(_msgSender(), address(this), lessAmount),
                "Error: Less token tranfer failed"
            );
        }
        allLp = allLp.add(lpAmount);
        allLess = allLess.add(lessAmount);
        if (stakeList[_msgSender()].length == 0) {
            stakers.push(_msgSender());
        }
        stakeList[_msgSender()].push(
            StakeItem(stakeIdLast, block.timestamp, lpAmount, lessAmount, 0, 0)
        );

        emit Staked(
            _msgSender(),
            stakeIdLast++,
            block.timestamp,
            lpAmount,
            lessAmount
        );
    }

    /**
     * @dev unstake tokens without penalty. Only for owner
     * @param lpAmount Amount of unstaked LP tokens
     * @param lessAmount Amount of unstaked Less tokens
     * @param lpRewards Amount of withdrawing rewards in LP
     * @param lessRewards Amount of withdrawing rewards in Less
     * @param _stakeId id of the unstaked pool
     */

    function unstakeWithoutPenalty(
        uint256 lpAmount,
        uint256 lessAmount,
        uint256 lpRewards,
        uint256 lessRewards,
        uint256 _stakeId
    ) external onlyOwner {
        _unstake(lpAmount, lessAmount, lpRewards, lessRewards, _stakeId, true);
    }

    /**
     * @dev unstake tokens
     * @param lpAmount Amount of unstaked LP tokens
     * @param lessAmount Amount of unstaked Less tokens
     * @param lpRewards Amount of withdrawing rewards in LP
     * @param lessRewards Amount of withdrawing rewards in Less
     * @param _stakeId id of the unstaked pool
     */

    function unstake(
        uint256 lpAmount,
        uint256 lessAmount,
        uint256 lpRewards,
        uint256 lessRewards,
        uint256 _stakeId
    ) external {
        _unstake(lpAmount, lessAmount, lpRewards, lessRewards, _stakeId, false);
    }

    function _unstake(
        uint256 lpAmount,
        uint256 lessAmount,
        uint256 lpRewardsAmount,
        uint256 lessRewardsAmount,
        uint256 _stakeId,
        bool isWithoutPenalty
    ) internal {
        address staker = _msgSender();
        require(stakeList[staker].length > 0, "Error: you haven't stakes");

        uint256 index = _getStakeIndexById(staker, _stakeId);
        require(index != ~uint256(0), "Error: no such stake");
        StakeItem memory deposit = stakeList[staker][index];
        require(lpAmount > 0 || lessAmount > 0, "Error: you unstake nothing");
        require(
            lpAmount <= deposit.stakedLp,
            "Error: insufficient LP token balance"
        );
        require(
            lessAmount <= deposit.stakedLess,
            "Error: insufficient Less token balance"
        );
        require(
            lpRewardsAmount <= deposit.lpEarned,
            "Error: insufficient LP token rewards"
        );
        require(
            lessRewardsAmount <= deposit.lessEarned,
            "Error: insufficient Less token rewards"
        );

        uint256 unstakedLp = lpAmount;
        uint256 unstakedLess = lessAmount;
        bool isUnstakedEarlier = block.timestamp.sub(deposit.startTime) <
            minDaysStake.mul(SEC_IN_DAY);
        if (isUnstakedEarlier && !isWithoutPenalty) {
            uint256 lpToBurn = unstakedLp.mul(penaltyBurned).div(1000);
            uint256 lessToBurn = unstakedLess.mul(penaltyBurned).div(1000);
            uint256 lpToDist = unstakedLp.mul(penaltyDistributed).div(1000);
            uint256 lessToDist = unstakedLess.mul(penaltyDistributed).div(1000);

            unstakedLp = unstakedLp.sub(lpToBurn.add(lpToDist));
            unstakedLess = unstakedLess.sub(lessToBurn.add(lessToDist));

            burnPenalty(lpToBurn, lessToBurn);
            distributePenalty(lpToDist, lessToDist);
        }
        allLp = allLp.sub(unstakedLp);
        allLess = allLess.sub(unstakedLess);
        deposit.stakedLp = deposit.stakedLp.sub(lpAmount);
        deposit.stakedLess = deposit.stakedLess.sub(lessAmount);
        deposit.lpEarned = deposit.lpEarned.sub(lpRewardsAmount);
        deposit.lessEarned = deposit.lessEarned.sub(lessRewardsAmount);

        uint256 tranferedLp = unstakedLp.add(lpRewardsAmount);
        uint256 tranferedLess = unstakedLess.add(lessRewardsAmount);

        require(
            lpToken.transfer(staker, tranferedLp),
            "Error: LP transfer failed"
        );
        require(
            lessToken.transfer(staker, tranferedLess),
            "Error: Less transfer failed"
        );

        bool isStakeEmpty = deposit.stakedLp == 0 &&
            deposit.stakedLess == 0 &&
            deposit.lpEarned == 0 &&
            deposit.lessEarned == 0;

        if (isStakeEmpty) {
            removeStake(staker, index);
        }

        if (stakeList[staker].length == 0) {
            deleteStaker(staker);
        }

        emit Unstaked(
            Unstake(
                staker,
                deposit.stakeId,
                block.timestamp,
                unstakedLp,
                unstakedLess,
                lpRewardsAmount,
                lessRewardsAmount,
                isUnstakedEarlier,
                isStakeEmpty
            )
        );
    }

    /**
     * @dev destribute penalty among all stakers proportional their stake sum.
     * @param lp LP token penalty
     * @param less Less token penalty
     */

    function distributePenalty(uint256 lp, uint256 less) internal view {
        require(lp > 0 || less > 0, "Error: zero penalty");
        for (uint256 i = 0; i < stakers.length; i++) {
            StakeItem[] memory stakes = stakeList[stakers[i]];
            for (uint256 j = 0; j < stakes.length; j++) {
                uint256 lpBalance = stakes[j].stakedLp;
                uint256 lessBalance = stakes[j].stakedLess;
                uint256 shareLp = lpBalance.mul(lp).div(allLp);
                uint256 shareLess = lessBalance.mul(less).div(allLess);

                stakes[j].lpEarned = stakes[j].lpEarned.add(shareLp);
                stakes[j].lessEarned = stakes[j].lessEarned.add(shareLess);
            }
        }
    }

    /**
     * @dev burn penalty.
     * @param lp LP token penalty
     * @param less Less token penalty
     */

    function burnPenalty(uint256 lp, uint256 less) internal {
        require(lp > 0 || less > 0, "Error: zero penalty");
        if (lp > 0) {
            lpToken.transfer(address(0), lp);
            allLp = allLp.sub(lp);
        }
        if (less > 0) {
            lessToken.transfer(address(0), less);
            allLess = allLess.sub(less);
        }
    }

    /**
     * @dev return full LP balance of staker.
     * @param staker staker address
     */

    function getLpBalanceByAddress(address staker)
        public
        view
        returns (uint256)
    {
        return _getBalanceByAddress(staker, BalanceType.Lp);
    }

    /**
     * @dev return full Less balance of staker.
     * @param staker staker address
     */
    function getLessBalanceByAddress(address staker)
        public
        view
        returns (uint256)
    {
        return _getBalanceByAddress(staker, BalanceType.Less);
    }

    /**
     * @dev return full balance of staker converted to Less.
     * @param staker staker address
     */
    function getOverallBalanceInLessByAddress(address staker)
        public
        view
        returns (uint256)
    {
        return _getBalanceByAddress(staker, BalanceType.Both);
    }

    /**
     * @dev return sum of LP converted in Less
     * @param _amount amount of converted LP
     */
    function getLpInLess(uint256 _amount) public view returns (uint256) {
        return _amount.mul(lessPerLp);
    }

    /**
     * @dev return num of all LP on the contract
     */
    function getOverallLP() public view returns (uint256) {
        return allLp;
    }

    /**
     * @dev return num of all Less on the contract
     */
    function getOverallLess() public view returns (uint256) {
        return allLess;
    }

    /**
     * @dev return full contract balance converted in Less
     */
    function getOverallBalanceInLess() public view returns (uint256) {
        return allLess.add(allLp.mul(lessPerLp));
    }

    /**
     * @dev set num of Less per one LP
     */

    function setLessInLP(uint256 amount) public onlyOwner {
        lessPerLp = amount;
    }

    /**
     * @dev set minimum days of stake for unstake without penalty
     */

    function setMinDaysStake(uint256 _minDaysStake) public onlyOwner {
        minDaysStake = _minDaysStake;
    }

    /**
     * @dev set penalty percent
     */
    function setPenalty(uint16 distributed, uint16 burned) public onlyOwner {
        penaltyDistributed = distributed;
        penaltyBurned = burned;
    }

    /**
     * @dev return index of stake by id
     * @param staker staker address
     * @param stakeId of stake pool
     */

    function _getStakeIndexById(address staker, uint256 stakeId)
        internal
        view
        returns (uint256)
    {
        StakeItem[] memory stakes = stakeList[staker];
        require(stakes.length > 0, "Error: user havn't stakes");
        for (uint256 i = 0; i < stakes.length; i++) {
            if (stakes[i].stakeId == stakeId) return i;
        }
        return ~uint256(0);
    }

    /**
     * @dev support function for get balance of address
     * @param staker staker address
     * @param balanceType type of balance
     */

    function _getBalanceByAddress(address staker, BalanceType balanceType)
        internal
        view
        returns (uint256 balance)
    {
        StakeItem[] memory deposits = stakeList[staker];
        if (deposits.length > 0) {
            for (uint256 i = 0; i < deposits.length; i++) {
                if (balanceType == BalanceType.Lp)
                    balance = balance.add(deposits[i].stakedLp);
                else if (balanceType == BalanceType.Less)
                    balance = balance.add(deposits[i].stakedLess);
                else
                    balance = balance.add(deposits[i].stakedLess).add(
                        getLpInLess(deposits[i].stakedLp)
                    );
            }
        }
    }

    /**
     * @dev remove stake from stakeList by index
     * @param staker staker address
     * @param index of stake pool
     */

    function removeStake(address staker, uint256 index) internal {
        require(stakeList[staker].length != 0);
        if (stakeList[staker].length == 1) {
            stakeList[staker].pop();
        } else {
            stakeList[staker][index] = stakeList[staker][
                stakeList[staker].length
            ];
            stakeList[staker].pop();
        }
    }

    function deleteStaker(address staker) internal {
        require(stakers.length != 0);
        if (stakers.length == 1) {
            stakers.pop();
        } else {
            uint256 index;
            for (uint256 i = 0; i < stakers.length; i++) {
                if (stakers[i] == staker) {
                    index = i;
                    break;
                }
            }
            stakers[index] = stakers[stakers.length];
            stakers.pop();
        }
    }
}
