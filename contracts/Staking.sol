// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LessLibrary.sol";
import "./interface.sol";

contract Staking is Ownable, ReentrancyGuard {
    //STRUCTURES:--------------------------------------------------------
    struct AccountInfo {
        uint256 balance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
    }

    struct StakeItem {
        uint256 stakeId;
        uint256 startTime;
        uint256 stakedLp;
        uint256 stakedLess;
        uint256 lpRewardsWithdrawn;
        uint256 lessRewardsWithdrawn;
    }

    //for "Stack too deep" avoiding. Using in Unstaked event.
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

    //for "Stack too deep" avoiding
    struct UnstakeItem {
        uint256 unstakedLp;
        uint256 unstakedLess;
        uint256 lpRewardsAmount;
        uint256 lessRewardsAmount;
    }
    //for "Stack too deep" avoiding
    struct PenaltyItem {
        uint256 lpToBurn;
        uint256 lessToBurn;
        uint256 lpToDist;
        uint256 lessToDist;
    }
    //for "Stack too deep" avoiding
    struct AmountItem {
        uint256 lpAmount;
        uint256 lessAmount;
        uint256 lpRewardsAmount;
        uint256 lessRewardsAmount;
    }

    //FIELDS:----------------------------------------------------
    ERC20Burnable public lessToken;
    ERC20Burnable public lpToken;
    LessLibrary public safeLibrary;

    uint256 public minDaysStake;
    uint16 public penaltyDistributed = 5; //100% = 1000
    uint16 public penaltyBurned = 5; //100% = 1000
    uint256 public lessPerLp = 300; //1 LP = 300 LESS

    uint256 public stakeIdLast;

    uint256 public allLp;
    uint256 public allLess;
    uint256 public totalLpRewards;
    uint256 public totalLessRewards;

    mapping(address => AccountInfo) private accountInfos;
    mapping(address => StakeItem[]) public stakeList;

    //CONSTRUCTOR-------------------------------------------------------
    constructor(
        ERC20Burnable _lp,
        ERC20Burnable _less,
        address _safeLibrary
    ) {
        lessToken = _less;
        lpToken = _lp;
        safeLibrary = LessLibrary(_safeLibrary);

        minDaysStake = safeLibrary.getMinUnstakeTime();
    }

    //EVENTS:-----------------------------------------------------------------
    event Staked(
        address staker,
        uint256 stakeId,
        uint256 startTime,
        uint256 stakedLp,
        uint256 stakedLess
    );

    event Unstaked(Unstake);
    //ENUMS:--------------------------------------------------
    enum BalanceType {
        Less,
        Lp,
        Both
    }

    //MODIFIERS:---------------------------------------------------
    modifier onlyDev() {
        require(
            msg.sender == safeLibrary.getFactoryAddress() ||
                msg.sender == safeLibrary.owner() ||
                msg.sender == safeLibrary.getDev(),
            "Only Dev"
        );
        _;
    }

    //EXTERNAL AND PUBLIC WRITE FUNCTIONS:---------------------------------------------------

    /**
     * @dev stake tokens
     * @param lpAmount Amount of staked LP tokens
     * @param lessAmount Amount of staked Less tokens
     */

    function stake(uint256 lpAmount, uint256 lessAmount) external nonReentrant {
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
        allLp += lpAmount;
        allLess += lessAmount;
        AccountInfo storage account = accountInfos[_msgSender()];

        account.balance += lessAmount + getLpInLess(lpAmount);

        if (account.lastUnstakedTimestamp == 0) {
            account.lastUnstakedTimestamp = block.timestamp;
        }

        account.lastStakedTimestamp = block.timestamp;

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

    function setLibraryAddress(address _newInfo) external onlyDev {
        safeLibrary = LessLibrary(_newInfo);
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

    function setLp(address _lp) external onlyOwner {
        lpToken = ERC20Burnable(_lp);
    }

    function setLess(address _less) external onlyOwner {
        lessToken = ERC20Burnable(_less);
    }



//EXTERNAL AND PUBLIC READ FUNCTIONS:--------------------------------------------------

    /**
     * @dev return info about user's staking balance.
     * @param _sender staker address
     */
    function getStakedInfo(address _sender)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            accountInfos[_sender].balance,
            accountInfos[_sender].lastStakedTimestamp,
            accountInfos[_sender].lastUnstakedTimestamp
        );
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
        return _amount * lessPerLp;
    }
    /**
     * @dev return full contract balance converted in Less
     */
    function getOverallBalanceInLess() public view returns (uint256) {
        return allLess + allLp * lessPerLp;
    }

    function getAmountOfUsersStakes(address user) external view returns(uint256) {
        return stakeList[user].length;
    }

    //INTERNAL AND PRIVATE FUNCTIONS-------------------------------------------------------
    function _unstake(
        uint256 lpAmount,
        uint256 lessAmount,
        uint256 lpRewardsAmount,
        uint256 lessRewardsAmount,
        uint256 _stakeId,
        bool isWithoutPenalty
    ) internal nonReentrant {
        address staker = _msgSender();
        require(stakeList[staker].length > 0, "Error: you haven't stakes");

        AmountItem memory amountItem = AmountItem(
            lpAmount,
            lessAmount,
            lpRewardsAmount,
            lessRewardsAmount
        );

        uint256 index = _getStakeIndexById(staker, _stakeId);
        require(index != ~uint256(0), "Error: no such stake");
        StakeItem storage deposit = stakeList[staker][index];

        uint256 stakeLessRewards = (deposit.stakedLess *
            amountItem.lessRewardsAmount) / allLess;
        uint256 stakeLpRewards = (deposit.stakedLp *
            amountItem.lpRewardsAmount) / allLp;

        require(
            amountItem.lpAmount > 0 || amountItem.lessAmount > 0,
            "Error: you unstake nothing"
        );
        require(
            amountItem.lpAmount <= deposit.stakedLp,
            "Error: insufficient LP token balance"
        );
        require(
            amountItem.lessAmount <= deposit.stakedLess,
            "Error: insufficient Less token balance"
        );
        require(
            amountItem.lpRewardsAmount <=
                (stakeLpRewards - deposit.lpRewardsWithdrawn),
            "Error: insufficient LP token rewards"
        );
        require(
            amountItem.lessRewardsAmount <=
                (stakeLessRewards - deposit.lessRewardsWithdrawn),
            "Error: insufficient Less token rewards"
        );

        UnstakeItem memory unstakeItem = UnstakeItem(
            amountItem.lpAmount,
            amountItem.lessAmount,
            amountItem.lpRewardsAmount,
            amountItem.lessRewardsAmount
        );

        bool isUnstakedEarlier = block.timestamp - deposit.startTime <
            minDaysStake;
        if (isUnstakedEarlier && !isWithoutPenalty) {
            PenaltyItem memory penaltyItem = PenaltyItem(0, 0, 0, 0);
            penaltyItem.lpToBurn =
                (unstakeItem.unstakedLp * penaltyBurned) /
                1000;
            penaltyItem.lessToBurn =
                (unstakeItem.unstakedLess * penaltyBurned) /
                1000;
            penaltyItem.lpToDist =
                (unstakeItem.unstakedLp * penaltyDistributed) /
                1000;
            penaltyItem.lessToDist =
                (unstakeItem.unstakedLess * penaltyDistributed) /
                1000;

            unstakeItem.unstakedLp -=
                penaltyItem.lpToBurn +
                penaltyItem.lpToDist;
            unstakeItem.unstakedLess -=
                penaltyItem.lessToBurn +
                penaltyItem.lessToDist;

            burnPenalty(penaltyItem.lpToBurn, penaltyItem.lessToBurn);
            distributePenalty(penaltyItem.lpToDist, penaltyItem.lessToDist);
        }
        uint256 tranferedLp = unstakeItem.unstakedLp +
            unstakeItem.lpRewardsAmount;
        uint256 tranferedLess = unstakeItem.unstakedLess +
            unstakeItem.lessRewardsAmount;

        require(
            lpToken.transfer(staker, tranferedLp),
            "Error: LP transfer failed"
        );
        require(
            lessToken.transfer(staker, tranferedLess),
            "Error: Less transfer failed"
        );

        allLp -= unstakeItem.unstakedLp;
        allLess -= unstakeItem.unstakedLess;
        deposit.stakedLp -= amountItem.lpAmount;
        deposit.stakedLess -= amountItem.lessAmount;
        deposit.lpRewardsWithdrawn += unstakeItem.lpRewardsAmount;
        deposit.lessRewardsWithdrawn += unstakeItem.lessRewardsAmount;
        totalLessRewards -= unstakeItem.lessRewardsAmount;
        totalLpRewards -= unstakeItem.lpRewardsAmount;

        AccountInfo storage account = accountInfos[_msgSender()];

        account.balance -=
            amountItem.lessAmount +
            getLpInLess(amountItem.lpAmount);

        account.lastStakedTimestamp = block.timestamp;

        if (account.balance == 0) {
            account.lastUnstakedTimestamp = 0;
            account.lastStakedTimestamp = 0;
        }

        bool isStakeEmpty = deposit.stakedLp == 0 &&
            deposit.stakedLess == 0 &&
            deposit.lpRewardsWithdrawn == stakeLpRewards &&
            deposit.lessRewardsWithdrawn == stakeLessRewards;

        if (isStakeEmpty) {
            removeStake(staker, index);
        }

        emit Unstaked(
            Unstake(
                staker,
                deposit.stakeId,
                block.timestamp,
                unstakeItem.unstakedLp,
                unstakeItem.unstakedLess,
                unstakeItem.lpRewardsAmount,
                unstakeItem.lessRewardsAmount,
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

    function distributePenalty(uint256 lp, uint256 less) internal {
        totalLessRewards += less;
        totalLpRewards += lp;
    }

    /**
     * @dev burn penalty.
     * @param lp LP token penalty
     * @param less Less token penalty
     */

    function burnPenalty(uint256 lp, uint256 less) internal {
        // if (lp > 0) {
        //     lpToken.burn(lp);
        //     allLp -= lp;
        // }
        // if (less > 0) {
        //     lessToken.burn(less);
        //     allLess -= less;
        // }

        if (lp > 0) {
            lpToken.transfer(owner(), lp);
            allLp -= lp;
        }
        if (less > 0) {
            lessToken.transfer(owner(), less);
            allLess -= less;
        }
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
                    balance += deposits[i].stakedLp;
                else if (balanceType == BalanceType.Less)
                    balance += deposits[i].stakedLess;
                else
                    balance +=
                        deposits[i].stakedLess +
                        getLpInLess(deposits[i].stakedLp);
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
                stakeList[staker].length - 1
            ];
            stakeList[staker].pop();
        }
    }
    
}
