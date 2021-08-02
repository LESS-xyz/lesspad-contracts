// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/Calculations.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
//import "./interface.sol";

contract PresalePublic is ReentrancyGuard {
    uint256 public id;

    address payable public factoryAddress;
    address public platformOwner;
    LessLibrary public lessLib;

    PresaleInfo public generalInfo;
    PresaleUniswapInfo public uniswapInfo;
    PresaleStringInfo public stringInfo;
    IntermediateVariables public intermediate;

    bool private initiate;
    bool private withdrawedFunds;
    address private lpAddress;
    uint256 private lpAmount;
    address private devAddress;
    uint256 private tokenMagnitude;
    address private WETHAddress;

    mapping(address => uint256) public voters;
    mapping(address => bool) public claimed; // if 1, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address

    mapping(address => bool) private whitelistMap;

    address[][5] public whitelist; //for backend

    uint8[4] public poolPercentages;
    uint256[5] public stakingTiers;

    TicketsInfo[] public tickets;

    struct TicketsInfo {
        address user;
        uint256 ticketAmount;
    }

    struct PresaleInfo {
        address creator;
        address token;
        uint256 tokenPriceInWei;
        uint256 hardCapInWei;
        uint256 softCapInWei;
        uint256 tokensForSaleLeft;
        uint256 tokensForLiquidityLeft;
        uint256 openTimeVoting;
        uint256 closeTimeVoting;
        uint256 openTimePresale;
        uint256 closeTimePresale;
        uint256 collectedFee;
    }

    struct IntermediateVariables {
        bool cancelled;
        bool liquidityAdded;
        uint256 beginingAmount;
        uint256 raisedAmount;
        uint256 participants;
        uint256 yesVotes;
        uint256 noVotes;
    }

    struct PresaleUniswapInfo {
        uint256 listingPriceInWei;
        uint256 lpTokensLockDurationInDays;
        uint8 liquidityPercentageAllocation;
        uint256 liquidityAllocationTime;
        uint256 unlockTime;
    }

    struct PresaleStringInfo {
        bytes32 saleTitle;
        bytes32 linkTelegram;
        bytes32 linkGithub;
        bytes32 linkTwitter;
        bytes32 linkWebsite;
        string linkLogo;
        string description;
        string whitepaper;
    }

    struct Investment {
        uint256 amountEth;
        uint256 amountTokens;
    }

    modifier onlyFabric() {
        require(factoryAddress == msg.sender);
        _;
    }

    modifier onlyPlatformOwner() {
        require(platformOwner == msg.sender);
        _;
    }

    modifier onlyPresaleCreator() {
        require(msg.sender == generalInfo.creator);
        _;
    }

    modifier onlyOwners() {
        require(
            msg.sender == generalInfo.creator || msg.sender == platformOwner,
            "Only owner"
        );
        _;
    }

    modifier notCreator() {
        require(msg.sender != generalInfo.creator, "No permition");
        _;
    }

    modifier liquidityAdded() {
        require(intermediate.liquidityAdded, "Add liquidity");
        _;
    }

    modifier onlyWhenOpenVoting() {
        require(
            block.timestamp >= generalInfo.openTimeVoting &&
            block.timestamp <= generalInfo.closeTimeVoting,
            "Voting closed"
        );
        _;
    }

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(
            nowTime >= generalInfo.openTimePresale &&
                nowTime <= generalInfo.closeTimePresale,
            "No presales"
        );
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!intermediate.cancelled);
        _;
    }

    modifier votesPassed(uint256 totalStakedAmount) {
        require(
            intermediate.yesVotes >= intermediate.noVotes &&
                intermediate.yesVotes >=
                lessLib.getMinYesVotesThreshold(totalStakedAmount) &&
                block.timestamp >= generalInfo.closeTimeVoting,
            "Votes not passed"
        );
        _;
    }

    modifier openRegister() {
        require(
            block.timestamp >= generalInfo.openTimePresale - 86400 &&
                block.timestamp < generalInfo.openTimePresale,
            "Not registration time"
        );
        _;
    }

    receive() external payable {}

    constructor(
        address payable _factory,
        address _library,
        address _platformOwner,
        address _devAddress
    ) {
        require(
            _factory != address(0) &&
                _library != address(0) &&
                _platformOwner != address(0) &&
                _devAddress != address(0)
        );
        lessLib = LessLibrary(_library);
        factoryAddress = _factory;
        platformOwner = _platformOwner;
        devAddress = _devAddress;
        //generalInfo.closeTimeVoting = block.timestamp + lessLib.getVotingTime();
    }

    function init(
        address[2] memory _creatorToken,
        uint256[9] memory _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee
    ) external onlyFabric {
        require(
            _creatorToken[0] != address(0) && _creatorToken[1] != address(0),
            "0 addr"
        );
        require(!initiate, "already inited");
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[0] > 0,
            "0 price"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[7] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] <
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[7],
            "Wrong time"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[3] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[4] > 0,
            "Wrong caps"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5] >=
                block.timestamp,
            "not voting"
        );

        uint256 closeVoting
         = _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5] +
            lessLib.getVotingTime();
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] >=
                closeVoting,
            "Voting&invest overlap"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[1] != 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[2] != 0,
            "0 tokens"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[8] > 0,
            "No fee"
        );
        generalInfo = PresaleInfo(
            _creatorToken[0],
            _creatorToken[1],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[0],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[4],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[3],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[1],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[2],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5],
            closeVoting,
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[7],
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[8]
        );

        uint256 tokenDecimals = ERC20(_creatorToken[1]).decimals();
        tokenMagnitude = uint256(10)**uint256(tokenDecimals);
        intermediate
        .beginingAmount = _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[
            1
        ];
        initiate = true;
    }

    function setUniswapInfo(
        uint256 price,
        uint256 duration,
        uint8 percent,
        uint256 allocationTime
    ) external onlyFabric {
        require(
            price != 0 &&
                percent != 0 &&
                allocationTime > generalInfo.closeTimePresale &&
                duration >= 30,
            "Wrong parameters to set for liquidity"
        );
        uniswapInfo = PresaleUniswapInfo(
            price,
            duration,
            percent,
            allocationTime,
            0
        );
    }

    function setStringInfo(
        bytes32 _saleTitle,
        bytes32 _linkTelegram,
        bytes32 _linkGithub,
        bytes32 _linkTwitter,
        bytes32 _linkWebsite,
        string calldata _linkLogo,
        string calldata _description,
        string calldata _whitepaper
    ) external onlyFabric {
        stringInfo = PresaleStringInfo(
            _saleTitle,
            _linkTelegram,
            _linkGithub,
            _linkTwitter,
            _linkWebsite,
            _linkLogo,
            _description,
            _whitepaper
        );
    }

    function setArrays(
        uint8[4] memory _poolPercentages,
        uint256[5] memory _stakingTiers
    ) external onlyFabric {
        poolPercentages = _poolPercentages;
        stakingTiers = _stakingTiers;
    }

    function getWhitelist(uint256 _tier)
        external
        view
        returns (address[] memory)
    {
        return whitelist[5 - _tier];
    }

    function isWhitelisting() external view returns (bool) {
        return block.timestamp <= generalInfo.openTimePresale;
    }

    function register(
        uint256 _tokenAmount,
        uint256 _tier,
        uint256 _timestamp,
        uint256 _totalStakedAmount,
        bytes memory _signature
    ) external openRegister votesPassed(_totalStakedAmount){
        require(!lessLib.getSignUsed(_signature), "used sign");
        require(
            lessLib._verifySigner(
                keccak256(
                    abi.encodePacked(
                        _tokenAmount,
                        msg.sender,
                        address(this),
                        _timestamp
                    )
                ),
                _signature,
                0
            ),
            "invalid signature"
        );
        require(_tier > 0 && _tier < 6);
        require(!whitelistMap[msg.sender], "al. whitelisted");
        if (_tier < 3)
            tickets.push(
                TicketsInfo(msg.sender, _tokenAmount / (500 * tokenMagnitude))
            );
        whitelistMap[msg.sender] = true;
        whitelist[5 - _tier].push(msg.sender);
        lessLib.setSingUsed(_signature, address(this));
    }

    function vote(
        bool _yes,
        uint256 _stakingAmount,
        uint256 _timestamp,
        bytes memory _signature
    ) external onlyWhenOpenVoting presaleIsNotCancelled notCreator {
        require(!lessLib.getSignUsed(_signature), "used sign");
        require(
            lessLib._verifySigner(
                keccak256(
                    abi.encodePacked(
                        _stakingAmount,
                        msg.sender,
                        address(this),
                        _timestamp
                    )
                ),
                _signature,
                0
            )
        );
        require(whitelistMap[msg.sender], "not whitelisted");
        //uint256 safeBalance = _stakingAmount;

        require(_stakingAmount >= lessLib.getMinVoterBalance(), "scant bal");
        require(voters[msg.sender] == 0, "a.voted");

        voters[msg.sender] = _stakingAmount;
        if (_yes) {
            intermediate.yesVotes = intermediate.yesVotes + _stakingAmount;
        } else {
            intermediate.noVotes = intermediate.noVotes + _stakingAmount;
        }
        lessLib.setSingUsed(_signature, address(this));
    }

    // _tokenAmount only for non bnb tokens
    // poolPercentages starts from 5th to 2nd teirs
    // Staking tiers also starts from 5th to 2nd tiers
    function invest(
        uint256 amount,
        bytes memory _signature,
        uint256 _stakedAmount,
        uint256 _totalStakedAmount,
        uint256 _timestamp /* ,
        uint8[4] memory poolPercentages,
        uint256[5] memory stakingTiers */
    )
        public
        payable
        presaleIsNotCancelled
        onlyWhenOpenPresale
        votesPassed(_totalStakedAmount)
        nonReentrant
        notCreator
    {
        require(!lessLib.getSignUsed(_signature), "used sign");
        require(
            lessLib._verifySigner(
                keccak256(
                    abi.encodePacked(
                        _stakedAmount,
                        msg.sender,
                        address(this),
                        _timestamp
                    )
                ),
                _signature,
                0
            )
        );
        require(whitelistMap[msg.sender], "not whitelisted");
        //uint256 amount = _tokenAmount;

        uint256 tokensLeft;
        if (block.timestamp < generalInfo.openTimePresale + 3600) {
            require(_stakedAmount >= stakingTiers[0], "u cant vote");
            tokensLeft =
                (intermediate.beginingAmount * poolPercentages[0]) /
                100;
        } else if (block.timestamp < generalInfo.openTimePresale + 5400) {
            require(
                _stakedAmount < stakingTiers[0] &&
                    _stakedAmount >= stakingTiers[1],
                "u cant vote"
            );
            tokensLeft =
                (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) +
                ((intermediate.beginingAmount * poolPercentages[1]) / 100);
        } else if (block.timestamp < generalInfo.openTimePresale + 6300) {
            require(
                _stakedAmount < stakingTiers[1] &&
                    _stakedAmount >= stakingTiers[2],
                "u cant vote"
            );
            tokensLeft =
                (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) +
                ((intermediate.beginingAmount * poolPercentages[2]) / 100);
        } else if (block.timestamp < generalInfo.openTimePresale + 6900) {
            require(
                _stakedAmount < stakingTiers[2] &&
                    _stakedAmount >= stakingTiers[3],
                "u cant vote"
            );
            tokensLeft =
                (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) +
                ((intermediate.beginingAmount * poolPercentages[3]) / 100);
        } else {
            require(_stakedAmount >= stakingTiers[4], "u cant vote");
            tokensLeft = generalInfo.tokensForSaleLeft;
        }
        uint256 reservedTokens = getTokenAmount(amount);
        require(intermediate.raisedAmount < generalInfo.hardCapInWei, "H cap");
        require(tokensLeft >= reservedTokens, "not enogh tkns in pool");
        require(amount > 0, "<0");
        uint256 totalInvestmentInWei = investments[msg.sender].amountEth +
            amount;

        if (investments[msg.sender].amountEth == 0) {
            intermediate.participants += 1;
        }

        intermediate.raisedAmount += amount;
        investments[msg.sender].amountEth = totalInvestmentInWei;
        investments[msg.sender].amountTokens += reservedTokens;
        generalInfo.tokensForSaleLeft -= reservedTokens;
        lessLib.setSingUsed(_signature, address(this));
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        nonReentrant
    {
        require(block.timestamp >= generalInfo.openTimePresale, "early");
        //require(investments[msg.sender].amountEth != 0, "n investor");
        require(investments[msg.sender].amountEth >= amount, "w amount");
        require(amount > 0, "0 amt");
        if (!intermediate.cancelled) {
            require(
                intermediate.raisedAmount < generalInfo.softCapInWei,
                "afterCap withdraw"
            );
        }
        require(to != address(0), "0 addr");
        if (investments[msg.sender].amountEth - amount == 0) {
            intermediate.participants -= 1;
        }
        to.transfer(amount);
        uint256 reservedTokens = getTokenAmount(amount);
        intermediate.raisedAmount -= amount;
        investments[msg.sender].amountEth -= amount;
        investments[msg.sender].amountTokens -= reservedTokens;
        generalInfo.tokensForSaleLeft += reservedTokens;
    }

    function claimTokens() external nonReentrant liquidityAdded {
        require(
            block.timestamp >= generalInfo.closeTimePresale &&
                claimed[msg.sender] &&
                investments[msg.sender].amountEth > 0
        );
        claimed[msg.sender] = true; // make sure this goes first before transfer to prevent reentrancy
        IERC20(generalInfo.token).transfer(
            msg.sender,
            investments[msg.sender].amountTokens
        );
    }

    function addLiquidity() external presaleIsNotCancelled nonReentrant {
        require(msg.sender == devAddress, "only dev");
        require(
            uniswapInfo.liquidityAllocationTime <= block.timestamp,
            "early"
        );

        require(block.timestamp >= generalInfo.closeTimePresale, "n closed");
        require(!intermediate.liquidityAdded, "already added");
        uint256 raisedAmount = intermediate.raisedAmount;
        if (raisedAmount == 0) {
            intermediate.liquidityAdded = true;
            return;
        }

        uint256 liqPoolEthAmount = (raisedAmount *
            uniswapInfo.liquidityPercentageAllocation) / 100;
        uint256 liqPoolTokenAmount = (liqPoolEthAmount * tokenMagnitude) /
            uniswapInfo.listingPriceInWei;

        require(
            generalInfo.tokensForLiquidityLeft >= liqPoolTokenAmount,
            "no liquidity"
        );

        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            address(lessLib.getUniswapRouter())
        );

        IERC20 token = IERC20(generalInfo.token);

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        (, , lpAmount) = uniswapRouter.addLiquidityETH{value: liqPoolEthAmount}(
            address(token),
            liqPoolTokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 15 minutes
        );

        //require(lpAmount != 0, "lpAmount not null");

        IUniswapV2Factory02 uniswapFactory = IUniswapV2Factory02(
            uniswapRouter.factory()
        );
        lpAddress = uniswapFactory.getPair(
            uniswapRouter.WETH(),
            address(token)
        );

        generalInfo.tokensForLiquidityLeft -= liqPoolTokenAmount;
        intermediate.liquidityAdded = true;
        uniswapInfo.unlockTime =
            block.timestamp +
            (uniswapInfo.lpTokensLockDurationInDays * 24 * 60 * 60);
    }

    function collectFundsRaised()
        external
        presaleIsNotCancelled
        nonReentrant
        onlyPresaleCreator
        liquidityAdded
    {
        require(
            intermediate.raisedAmount >= generalInfo.softCapInWei,
            "sCap n riched"
        );
        require(!withdrawedFunds, "only once");
        uint256 collectedBalance = payable(address(this)).balance;
        if (collectedBalance > 0) {
            uint256 fee = lessLib.calculateFee(collectedBalance);
            lessLib.getVaultAddress().transfer(fee);
            payable(generalInfo.creator).transfer(
                payable(address(this)).balance - generalInfo.collectedFee
            );
        }
        _withdrawUnsoldTokens();
        withdrawedFunds = true;
    }

    function refundLpTokens()
        external
        presaleIsNotCancelled
        nonReentrant
        onlyPresaleCreator
        liquidityAdded
    {
        require(lpAmount != 0 && block.timestamp >= uniswapInfo.unlockTime);
        require(
            IERC20(lpAddress).transfer(generalInfo.creator, lpAmount),
            "transf.fail"
        );
        lpAmount = 0;
    }

    function collectFee(uint256 _totalStakedAmount) external nonReentrant {
        require(generalInfo.collectedFee != 0, "already withdrawn");
        if (
            intermediate.yesVotes >= intermediate.noVotes &&
            intermediate.yesVotes >=
            lessLib.getMinYesVotesThreshold(_totalStakedAmount) &&
            block.timestamp >= generalInfo.closeTimeVoting &&
            !intermediate.cancelled
        ) {
            payable(platformOwner).transfer(generalInfo.collectedFee);
        } else {
            payable(generalInfo.creator).transfer(generalInfo.collectedFee);
            uint256 bal = IERC20(generalInfo.token).balanceOf(address(this));
            require(IERC20(generalInfo.token).transfer(generalInfo.creator, bal), "con't get ur tkns");
            intermediate.cancelled = true;
        }
        generalInfo.collectedFee = 0;
    }

    function changeCloseTimeVoting(uint256 _newCloseTime)
        external
        presaleIsNotCancelled
        onlyOwners
    {
        //uint256 openTimePresale = generalInfo.openTimePresale;
        require(
            block.timestamp < _newCloseTime &&
                _newCloseTime + 86400 <= generalInfo.openTimePresale
        );
        generalInfo.closeTimeVoting = _newCloseTime;
    }

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime)
        external
        presaleIsNotCancelled
        onlyOwners
    {
        require(block.timestamp < generalInfo.openTimePresale, "started");
        require(
            generalInfo.closeTimeVoting + 86400 < _newOpenTime &&
                _newCloseTime - _newOpenTime > 6900 &&
                _newCloseTime < uniswapInfo.liquidityAllocationTime
        );
        generalInfo.openTimePresale = _newOpenTime;
        generalInfo.closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled {
        if(intermediate.raisedAmount < generalInfo.softCapInWei && block.timestamp >= generalInfo.closeTimePresale) {
            require(msg.sender == generalInfo.creator, "only pres creator");
        }
        else {
            require(msg.sender == platformOwner, "only platf own");
        }
        uint256 bal = IERC20(generalInfo.token).balanceOf(address(this));
        require(IERC20(generalInfo.token).transfer(generalInfo.creator, bal), "con't get ur tkns");
        intermediate.cancelled = true;
    }

    function getPresaleId() external view returns (uint256) {
        return id;
    }

    function setPresaleId(uint256 _id) external onlyFabric {
        if (id != 0) {
            require(id != _id);
        }
        id = _id;
    }

    function getMyVote() external view returns (uint256) {
        return voters[msg.sender];
    }

    function getGenInfo()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            generalInfo.tokensForSaleLeft,
            generalInfo.tokensForLiquidityLeft,
            generalInfo.collectedFee
        );
    }

    function getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        return (_weiAmount * tokenMagnitude) / generalInfo.tokenPriceInWei;
    }

    function _withdrawUnsoldTokens() internal {
        uint256 unsoldTokensAmount = generalInfo.tokensForSaleLeft +
            generalInfo.tokensForLiquidityLeft;
        if (unsoldTokensAmount > 0) {
            IERC20(generalInfo.token).transfer(
                generalInfo.creator,
                unsoldTokensAmount
            );
        }
    }
}
