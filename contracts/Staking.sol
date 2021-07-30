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
        uint256 lessBalance;
        uint256 lpBalance;
        uint256 overallBalance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
    }

    struct StakeItem {
        uint256 startTime;
        uint256 stakedLp;
        uint256 stakedLess;
    }

    struct UserStakes {
        uint256[] ids;
        mapping(uint256 => uint256) indexes; 
    }

    //for "Stack too deep" avoiding. Using in Unstaked event.
    struct Unstake {
        address staker;
        uint256 stakeId;
        uint256 unstakeTime;
        bool isUnstakedEarlier;
    }



    //FIELDS:----------------------------------------------------
    ERC20Burnable public lessToken;
    ERC20Burnable public lpToken;
    LessLibrary public safeLibrary;

    uint256 public minStakeTime;
    uint16 public penaltyDistributed = 5; //100% = PERCENT_FACTOR
    uint16 public penaltyBurned = 5; //100% = PERCENT_FACTOR
    uint256 constant private PERCENT_FACTOR = 1000;
    uint256 public lessPerLp = 300; //1 LP = 300 LESS

    uint256 public stakeIdLast;

    uint256 public allLp;
    uint256 public allLess;
    uint256 public totalLpRewards;
    uint256 public totalLessRewards;

    mapping(address => AccountInfo) private accountInfos;
    mapping(address => UserStakes) private userStakes;
    mapping(uint256 => StakeItem) public stakes;

    uint8[4] public poolPercentages;
    uint256[5] public stakingTiers;

    //CONSTRUCTOR-------------------------------------------------------
    constructor(
        ERC20Burnable _lp,
        ERC20Burnable _less,
        address _safeLibrary
    ) {
        lessToken = _less;
        lpToken = _lp;
        safeLibrary = LessLibrary(_safeLibrary);

        minStakeTime = safeLibrary.getMinUnstakeTime();

        poolPercentages[0] = 30; //tier 5
        poolPercentages[1] = 20; //tier 4
        poolPercentages[2] = 15; //tier 3
        poolPercentages[3] = 25; //tier 2

        stakingTiers[0] = 200000 ether; //tier 5
        stakingTiers[1] = 50000 ether; //tier 4
        stakingTiers[2] = 20000 ether; //tier 3
        stakingTiers[3] = 5000 ether; //tier 2
        stakingTiers[4] = 1000 ether; //tier 1

    }

    //EVENTS:-----------------------------------------------------------------
    event Staked(
        address staker,
        uint256 stakeId,
        uint256 startTime,
        uint256 stakedLp,
        uint256 stakedLess
    );

    event Unstaked(
        address staker,
        uint256 stakeId,
        uint256 unstakeTime,
        bool isUnstakedEarlier
    );

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

        account.lpBalance += lpAmount;
        account.lessBalance += lessAmount;
        account.overallBalance += lessAmount + getLpInLess(lpAmount);

        if (account.lastUnstakedTimestamp == 0) {
            account.lastUnstakedTimestamp = block.timestamp;
        }

        account.lastStakedTimestamp = block.timestamp;

        StakeItem memory newStake = StakeItem(block.timestamp, lpAmount, lessAmount);
        stakes[stakeIdLast] = newStake;
        userStakes[_msgSender()].ids.push(stakeIdLast);
        userStakes[_msgSender()].indexes[stakeIdLast] = userStakes[_msgSender()].ids.length;

        emit Staked(
            _msgSender(),
            stakeIdLast++,
            block.timestamp,
            lpAmount,
            lessAmount
        );
    }

    /**
     * @dev unstake all tokens and rewards
     * @param _stakeId id of the unstaked pool
     */

    function unstake(uint256 _stakeId) public {
        _unstake(_stakeId, false);
    }

    /**
     * @dev unstake all tokens and rewards without penalty. Only for owner
     * @param _stakeId id of the unstaked pool
     */

    function unstakeWithoutPenalty(uint256 _stakeId) external onlyOwner {
        _unstake(_stakeId, true);
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

    function setMinTimeToStake(uint256 _minTime) public onlyOwner {
        minStakeTime = _minTime;
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

    function setStakingTiresSums(uint256 tier1, uint256 tier2, uint256 tier3,uint256 tier4,uint256 tier5) external onlyOwner {
        stakingTiers[0] = tier5; //tier 5
        stakingTiers[1] = tier4; //tier 4
        stakingTiers[2] = tier3; //tier 3
        stakingTiers[3] = tier2; //tier 2
        stakingTiers[4] = tier1; //tier 1
    }

    function setPoolPercentages(uint8 tier2, uint8 tier3,uint8 tier4,uint8 tier5) external onlyOwner {
        require(tier2 + tier3 + tier4 + tier5 < 100, "Percents sum should be less 100");

        poolPercentages[0] = tier5; //tier 5
        poolPercentages[1] = tier4; //tier 4
        poolPercentages[2] = tier3; //tier 3
        poolPercentages[3] = tier2; //tier 2
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
            accountInfos[_sender].overallBalance,
            accountInfos[_sender].lastStakedTimestamp,
            accountInfos[_sender].lastUnstakedTimestamp
        );
    }

    function getUserTier(address user) external view returns(uint8){
        uint256 balance = accountInfos[user].overallBalance;
        for (uint8 i = 0; i < stakingTiers.length; i++) {
            if (balance >= stakingTiers[i]) return uint8(stakingTiers.length - i);
        }
        return 0;
    }

    function getLpRewradsAmount(uint256 id) external view returns(uint256 lpRewards) {
         (lpRewards, ) = _rewards(id);
    }

    function getLessRewradsAmount(uint256 id) external view returns(uint256 lessRewards) {
         (,lessRewards) = _rewards(id);
    }

    function getLpBalanceByAddress(address user) external view returns(uint256 lp) {
        lp = accountInfos[user].lpBalance;
    }

    function getLessBalanceByAddress(address user) external view returns(uint256 less) {
        less = accountInfos[user].lessBalance;
    }

    function getOverallBalanceInLessByAddress(address user) external view returns(uint256 overall) {
        overall = accountInfos[user].overallBalance;
    }

    /**
     * @dev return sum of LP converted in Less
     * @param _amount amount of converted LP
     */
    function getLpInLess(uint256 _amount) private view returns (uint256) {
        return _amount * lessPerLp;
    }

    /**
     * @dev return full contract balance converted in Less
     */
    function getOverallBalanceInLess() public view returns (uint256) {
        return allLess + allLp * lessPerLp;
    }

    function getAmountOfUsersStakes(address user)
        external
        view
        returns (uint256)
    {
        return userStakes[user].ids.length;
    }

    function getUserStakeIds(address user) external view returns(uint256[] memory) {
        return userStakes[user].ids;
    }

    function isMinTimePassed(uint256 id) external view returns(bool) {
        return block.timestamp - stakes[id].startTime >= minStakeTime;
    }



    //INTERNAL AND PRIVATE FUNCTIONS-------------------------------------------------------
    function _unstake(uint256 id, bool isWithoutPenalty) internal nonReentrant {
        address staker = _msgSender();
        require(userStakes[staker].ids.length > 0, "Error: you haven't stakes");

        bool isUnstakedEarlier = block.timestamp - stakes[id].startTime < minStakeTime;

        uint256 lpRewards = 0;
        uint256 lessRewards = 0;
        if (!isUnstakedEarlier) (lpRewards, lessRewards) = _rewards(id);

        uint256 lpAmount = stakes[id].stakedLp;
        uint256 lessAmount = stakes[id].stakedLess;

        allLp -= lpAmount;
        allLess -= lessAmount;
        AccountInfo storage account = accountInfos[staker];

        account.lpBalance -= lpAmount;
        account.lessBalance -= lessAmount;
        account.overallBalance -= lessAmount + getLpInLess(lpAmount);
        account.lastStakedTimestamp = block.timestamp;

        if (account.overallBalance == 0) {
            account.lastUnstakedTimestamp = 0;
            account.lastStakedTimestamp = 0;
        }

        

        

        if (isUnstakedEarlier && !isWithoutPenalty) {
            (lpAmount, lessAmount) = payPenalty(lpAmount, lessAmount);
        }

        require(
            lpToken.transfer(staker, lpAmount + lpRewards),
            "Error: LP transfer failed"
        );
        require(
            lessToken.transfer(staker, lessAmount + lessRewards),
            "Error: Less transfer failed"
        );

        totalLessRewards -= lessRewards;
        totalLpRewards -= lpRewards;

       
        removeStake(staker, id);

        emit Unstaked(
            staker,
            id,
            block.timestamp,
            isUnstakedEarlier
        );
    }

    function payPenalty(uint256 lpAmount, uint256 lessAmount) private returns(uint256, uint256) {
       uint256 lpToBurn =
            (lpAmount * penaltyBurned) /
            PERCENT_FACTOR;
        uint256 lessToBurn =
            (lessAmount * penaltyBurned) /
            PERCENT_FACTOR;
        uint256 lpToDist =
            (lpAmount * penaltyDistributed) /
            PERCENT_FACTOR;
        uint256 lessToDist =
            (lessAmount * penaltyDistributed) /
            PERCENT_FACTOR;

        burnPenalty(lpToBurn, lessToBurn);
        distributePenalty(lpToDist, lessToDist);

        uint256 lpDecrease = lpToBurn + lpToDist;
        uint256 lessDecrease = lessToBurn + lessToDist;

        return (lpAmount - lpDecrease, lessAmount - lessDecrease);
    }

    function _rewards(uint256 id)
        private
        view
        returns (uint256 lpRewards, uint256 lessRewards)
    {
        StakeItem storage deposit = stakes[id];

        lpRewards =
            (deposit.stakedLp * totalLpRewards) /
            allLp;

        lessRewards =
            (deposit.stakedLess * totalLessRewards) /
            allLess;
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
        if (lp > 0) {
            lpToken.transfer(owner(), lp);
        }
        if (less > 0) {
            lessToken.transfer(owner(), less);
        }
    }

    /**
     * @dev remove stake from stakeList by index
     * @param staker staker address
     * @param id id of stake pool
     */

    function removeStake(address staker, uint256 id) internal {
        delete stakes[id];

        require(userStakes[staker].ids.length != 0, "Error: whitelist is empty");
        
        if (userStakes[staker].ids.length > 1) {
            uint256 stakeIndex = userStakes[staker].indexes[id] - 1;
            uint256 lastIndex = userStakes[staker].ids.length - 1;
            uint256 lastStake = userStakes[staker].ids[lastIndex];
            userStakes[staker].ids[stakeIndex] = lastStake;
            userStakes[staker].indexes[id] = stakeIndex + 1;
        }
        userStakes[staker].ids.pop();
        userStakes[staker].indexes[id] = 0;
    }
}
