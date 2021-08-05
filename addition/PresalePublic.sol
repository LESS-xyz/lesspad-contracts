// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LessLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface.sol";

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
    address private bnbAddress = address(0);

    mapping(address => uint256) public voters;
    mapping(address => uint256) public claimed; // if 1, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address

    mapping(address => bool) private whitelistTierThreeFive;
    mapping(address => bool) private whitelistTierOne;
    mapping(address => bool) private whitelistTierTwo;
 
    address[][5] public whitelist; //for backend

    TicketsInfo[] public tickets;

    struct TicketsInfo {
        address user;
        uint256 ticketAmount;
    }

    struct PresaleInfo {
        address payable creator;
        IERC20 token;
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
        /*bool cancelled;
        bool liquidityAdded;
        uint256 raisedAmount;
        uint256 participants;
        uint256 yesVotes;
        uint256 noVotes;*/
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
        require(block.timestamp <= generalInfo.closeTimeVoting, "Voting closed");
        _;
    }

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(
            nowTime >= generalInfo.openTimePresale &&
                nowTime <= generalInfo.closeTimePresale, "No presales"
        );
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!intermediate.cancelled);
        _;
    }

    modifier votesPassed() {
        require(
            intermediate.yesVotes >= intermediate.noVotes &&
                intermediate.yesVotes >= lessLib.getMinYesVotesThreshold() && block.timestamp >= generalInfo.closeTimeVoting,
            "Votes not passed"
        );
        _;
    }

    modifier openRegister() {
        require(block.timestamp >= generalInfo.openTimePresale - 86400 && block.timestamp < generalInfo.openTimePresale, "Not registration time");
        _;
    }

    modifier inWhitelist() {
        require(whitelistTierThreeFive[msg.sender], "not in whitelist");
        _;
    }

    modifier inWhitelistTierOneTwo() {
        require(whitelistTierOne[msg.sender] || whitelistTierTwo[msg.sender], "not in whitelist");
        _;
    }

    receive() external payable {}

    constructor(
        address payable _factory,
        address _library,
        address _platformOwner,
        address _devAddress
    )  {
        require(_factory != address(0) && _library != address(0) && _platformOwner != address(0) && _devAddress != address(0));
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
        require(_priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5] >= block.timestamp + 86400, "not voting");
        uint256 closeVoting = _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5] + lessLib.getVotingTime();
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] >= closeVoting,
            "Voting&invest overlap"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[1] != 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[2] != 0,
            "0 tokens"
        );
        require(_priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[8]>0, "No fee");
        generalInfo = PresaleInfo(
            payable(_creatorToken[0]),
            IERC20(_creatorToken[1]),
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
        intermediate.beginingAmount = _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[1];
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
            duration >= 30
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

    function getWhitelist(uint256 _tier) public view returns(address[] memory) {
        return whitelist[_tier];
    }

    function isWhitelisting() public view returns(bool) {
        return block.timestamp <= generalInfo.openTimePresale;
    }

    // function getWhitelistLength(uint256 _tier) 
    //     public
    //     view
    // returns (uint256) {
    //     return whitelist[_tier].length;     
    // }

    function registerTierOneTwo(uint256 _tokenAmount, uint256 _tier, uint256 _timestamp, bytes memory _signature) external openRegister {
        require(!lessLib.usedSignature[_signature], "used sign");
        require(
            lessLib._verifySigner(abi.encodePacked(_tokenAmount, msg.sender, address(this), _timestamp), _signature),
            "w sign"
        );
        tickets.push(TicketsInfo(msg.sender, _tokenAmount/500));
        if (_tokenAmount >= 1000 * tokenMagnitude &&  _tokenAmount < 5000 * tokenMagnitude) {
            require(!whitelistTierOne[msg.sender], "al. whitelisted");
            whitelistTierOne[msg.sender] = true;
            whitelist[_tier].push(msg.sender);
        } else if (_tokenAmount >= 5000 * tokenMagnitude) {
            require(!whitelistTierTwo[msg.sender], "al. whitelisted");
            whitelistTierTwo[msg.sender] = true;
            whitelist[_tier].push(msg.sender);
        }
        lessLib.usedSignature[_signature] = true;
    }

    function register(uint256 _tokenAmount, uint256 _tier, uint256 _timestamp, bytes memory _signature) external openRegister {
        require(!lessLib.usedSignature[_signature], "used sign");
        require(
           lessLib._verifySigner(abi.encodePacked(_tokenAmount, msg.sender, address(this), _timestamp), _signature),
           "invalid signature"
        );
        require(!whitelistTierThreeFive[msg.sender], "al. whitelisted");
        whitelistTierThreeFive[msg.sender] = true;
        whitelist[_tier].push(msg.sender);
        lessLib.usedSignature[_signature] = true;
    }

    function vote(bool _yes, uint256 _stakingAmount, uint256 _timestamp, bytes memory _signature) external onlyWhenOpenVoting presaleIsNotCancelled notCreator{
        require(!lessLib.usedSignature[_signature], "used sign");
        require(lessLib._verifySigner(abi.encodePacked(_stakingAmount, msg.sender, address(this), _timestamp), _signature));
        uint256 safeBalance = _stakingAmount;

        require(
            safeBalance >= lessLib.getMinVoterBalance(),
            "scant bal"
        );
        require(voters[msg.sender] == 0, "a.voted");

        voters[msg.sender] = safeBalance;
        if (_yes) {
            intermediate.yesVotes = intermediate.yesVotes + safeBalance;
        } else {
            intermediate.noVotes = intermediate.noVotes + safeBalance;
        }
        lessLib.usedSignature[_signature] = true;
    }

    // _tokenAmount only for non bnb tokens
    // poolPercentages starts from 5th to 2nd teirs
    // Staking tiers also starts from 5th to 2nd tiers
    function invest(
        uint256 _tokenAmount, 
        bytes memory _signature, 
        uint256 _stakedAmount,
        uint256 _timestamp,
        uint256[4] memory poolPercentages,
        uint256[4] memory stakingTiers
    )
        public
        payable
        presaleIsNotCancelled
        onlyWhenOpenPresale
        votesPassed
        nonReentrant
        notCreator
    {
        require(!lessLib.usedSignature[_signature], "used sign");
        require(lessLib._verifySigner(abi.encodePacked(_stakedAmount, msg.sender, address(this), _timestamp), _signature));
        

        uint256 amount = _tokenAmount;

        uint256 tokensLeft;
        if(block.timestamp < generalInfo.openTimePresale + 3600){
            require(_stakedAmount >= stakingTiers[0]*tokenMagnitude, "u cant vote");
            tokensLeft = intermediate.beginingAmount * poolPercentages[0] / 100;
        }
        else if(block.timestamp < generalInfo.openTimePresale + 5400){
            require(_stakedAmount < stakingTiers[0]*tokenMagnitude && _stakedAmount >= stakingTiers[1]*tokenMagnitude, "u cant vote");
            tokensLeft = (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) + (intermediate.beginingAmount * poolPercentages[1] / 100);
        }
        else if(block.timestamp < generalInfo.openTimePresale + 6300){
            require(_stakedAmount < stakingTiers[1]*tokenMagnitude && _stakedAmount >= stakingTiers[2]*tokenMagnitude, "u cant vote");
            tokensLeft = (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) + (intermediate.beginingAmount * poolPercentages[2] / 100);
        }
        else if(block.timestamp < generalInfo.openTimePresale + 6900){
            require(_stakedAmount < stakingTiers[2]*tokenMagnitude && _stakedAmount >= stakingTiers[3]*tokenMagnitude, "u cant vote");
            tokensLeft = (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) + (intermediate.beginingAmount * poolPercentages[3] / 100);
        }
        else {
            tokensLeft = generalInfo.tokensForSaleLeft;
        }
        uint256 reservedTokens = getTokenAmount(amount);
        //tokensLeft = generalInfo.tokensForSaleLeft;
        require(
            intermediate.raisedAmount < generalInfo.hardCapInWei,
            "H cap"
        );
        require(tokensLeft >= reservedTokens, "No tkns");
        require(amount > 0, "<0");
        uint256 safeBalance = _stakedAmount;
        /*require(
            msg.value <=
                (tokensLeft * generalInfo.tokenPriceInWei) / tokenMagnitude,
            "Not enough tokens left"
        );*/
        uint256 totalInvestmentInWei =
            investments[msg.sender].amountEth + amount;
        /*require(
            totalInvestmentInWei >= minInvestInWei ||
                raisedAmount >= hardCap - 1 ether,
            "Min investment not reached"
        );
        require(
            maxInvestInWei == 0 || totalInvestmentInWei <= maxInvestInWei,
            "Max investment reached"
        );*/

        uint256 minInvestorBalance = lessLib.getMinInvestorBalance();
        require(
            minInvestorBalance == 0 || safeBalance >= minInvestorBalance,
            "Stake LessTokens"
        );

        if (investments[msg.sender].amountEth == 0) {
            intermediate.participants += 1;
        }

        intermediate.raisedAmount += amount;
        investments[msg.sender].amountEth = totalInvestmentInWei;
        investments[msg.sender].amountTokens += reservedTokens;
        generalInfo.tokensForSaleLeft = tokensLeft - reservedTokens;
        lessLib.usedSignature[_signature] = true;
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        votesPassed
        nonReentrant
    {
        require(
            block.timestamp >= generalInfo.openTimePresale,
            "early"
        );
        require(
            investments[msg.sender].amountEth != 0,
            "n investor"
        );
        require(
            investments[msg.sender].amountEth >= amount,
            "w amount"
        );
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
            claimed[msg.sender] == 0 && 
            investments[msg.sender].amountEth != 0
        );
        claimed[msg.sender] = 1; // make sure this goes first before transfer to prevent reentrancy
        generalInfo.token.transfer(
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

        require(
            block.timestamp >= generalInfo.closeTimePresale,
            "n closed"
        );
        require(
            !intermediate.liquidityAdded,
            "already added"
        );
        uint256 raisedAmount = intermediate.raisedAmount;
        if (raisedAmount == 0) {
            intermediate.liquidityAdded = true;
            return;
        }

        uint256 liqPoolEthAmount =
            (raisedAmount * uniswapInfo.liquidityPercentageAllocation) / 100;
        uint256 liqPoolTokenAmount =
            (liqPoolEthAmount * tokenMagnitude) / uniswapInfo.listingPriceInWei;

        require(
            generalInfo.tokensForLiquidityLeft >= liqPoolTokenAmount,
            "no liquidity"
        );

        IUniswapV2Router02 uniswapRouter =
            IUniswapV2Router02(address(lessLib.getUniswapRouter()));

        IERC20 token = generalInfo.token;

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        IWETH wETH = IWETH(uniswapRouter.WETH());
        wETH.deposit{value: liqPoolEthAmount}();

        wETH.approve(WETHAddress, liqPoolEthAmount);

        (, , lpAmount) = uniswapRouter.addLiquidity(
            address(token),
            WETHAddress,
            liqPoolTokenAmount,
            liqPoolEthAmount,
            0,
            0,
            payable(address(this)),
            block.timestamp + 15 minutes
        );

        //require(lpAmount != 0, "lpAmount not null");

        IUniswapV2Factory02 uniswapFactory =
            IUniswapV2Factory02(uniswapRouter.factory());
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
        require(!withdrawedFunds, "only once");
        uint256 collectedBalance = payable(address(this)).balance;
        if (collectedBalance > 0) {
            uint256 fee = lessLib.calculateFee(collectedBalance);
            lessLib.getVaultAddress().transfer(fee);
            generalInfo.creator.transfer(payable(address(this)).balance - generalInfo.collectedFee);
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

    /*function getUnsoldTokens()
        external
        presaleIsNotCancelled
        nonReentrant
        liquidityAdded
        onlyOwners
    {
        uint256 unsoldTokensAmount =
            generalInfo.tokensForSaleLeft + generalInfo.tokensForLiquidityLeft;
        if (unsoldTokensAmount > 0) {
            generalInfo.token.transfer(generalInfo.creator, unsoldTokensAmount);
        }
    }*/

    function collectFee() external nonReentrant {
        require(generalInfo.collectedFee != 0, "already withdrawn");
        if (intermediate.yesVotes >= intermediate.noVotes &&
                intermediate.yesVotes >= lessLib.getMinYesVotesThreshold() && block.timestamp >= generalInfo.closeTimeVoting && !intermediate.cancelled) {
                    payable(platformOwner).transfer(generalInfo.collectedFee);
                }
        else {
            payable(generalInfo.creator).transfer(generalInfo.collectedFee);
            intermediate.cancelled = true;
        }
        //payable(platformOwner).transfer(generalInfo.collectedFee);
        generalInfo.collectedFee = 0;
    }

    function changeCloseTimeVoting(uint256 _newCloseTime)
        external
        presaleIsNotCancelled
        onlyOwners
    {
        uint256 openTimePresale = generalInfo.openTimePresale;
        require(
            block.timestamp < openTimePresale && 
            _newCloseTime <= openTimePresale
        );
        generalInfo.closeTimeVoting = _newCloseTime;
    }

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime)
        external
        presaleIsNotCancelled
        onlyOwners
    {
        require(
            block.timestamp < generalInfo.openTimePresale,
            "started"
        );
        require(
            generalInfo.closeTimeVoting < _newOpenTime &&
            _newCloseTime > _newOpenTime &&
            _newCloseTime < uniswapInfo.liquidityAllocationTime
        );
        generalInfo.openTimePresale = _newOpenTime;
        generalInfo.closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled onlyOwners {
        _withdrawUnsoldTokens();
        intermediate.cancelled = true;
    }

    function getPresaleId() external view returns (uint256) {
        return id;
    }

    function setPresaleId(uint256 _id) external onlyFabric {
        if(id != 0)
        {
            require(id != _id);
        }
        id = _id;
    }

    function getMyVote() external view returns(uint256) {
        return voters[msg.sender];
    }

    function getGenInfo() external view returns(uint256,uint256,uint256) {
        return (generalInfo.tokensForSaleLeft, generalInfo.tokensForLiquidityLeft, generalInfo.collectedFee);
    }

    function getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        /*uint256 amount = lessLib.getStakedSafeBalance(msg.sender);
        uint256 discount = 0;
        uint256 pricePerToken = generalInfo.tokenPriceInWei;
        if (amount < 15000) {
            return (_weiAmount * tokenMagnitude) / pricePerToken;
        } else if (amount >= 15000 && amount < 75000) {
            return (_weiAmount * tokenMagnitude) / pricePerToken;
        } else if (amount >= 75000 && amount < 150000) {
            discount = (pricePerToken * 5) / 100;
            return (_weiAmount * tokenMagnitude) / (pricePerToken - discount);
        } else if (amount >= 150000 && amount < 325000) {
            discount = (pricePerToken * 7) / 100;
            return (_weiAmount * tokenMagnitude) / (pricePerToken - discount);
        } else if (amount >= 700000) {
            discount = pricePerToken / 10;
            return (_weiAmount * tokenMagnitude) / (pricePerToken - discount);
        }

        return 0;*/

        return (_weiAmount * tokenMagnitude) / generalInfo.tokenPriceInWei;
    }

    function _withdrawUnsoldTokens() internal {
        uint256 unsoldTokensAmount =
            generalInfo.tokensForSaleLeft + generalInfo.tokensForLiquidityLeft;
        if (unsoldTokensAmount > 0) {
            generalInfo.token.transfer(generalInfo.creator, unsoldTokensAmount);
        }
    }
}

