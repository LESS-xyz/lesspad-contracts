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
    address private tokenAddress;
    address private WETHAddress;
    address private bnbAddress = address(0);

    //constants for unique signatures
    uint256 private tier12Investconst = 120006;
    uint256 private tier35Investconst = 3453014;
    uint256 private tier12Registerconst = 126660;
    uint256 private tier35Registerconst = 462104;
    uint256 private lotteryConst = 135384;
    uint256 private votingConst = 203833;

    mapping(address => uint256) public voters;
    mapping(address => bool) public claimed; // if true, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address
    
    mapping(address => bool) public whitelist; //for tiers 3-5

    mapping(address => bool) public whitelistTierOne;
    mapping(address => bool) public whitelistTierTwo;
    address[] public whitelistTierOneArr;
    address[] public whitelistTierTwoArr;
    mapping(bytes32 => bool) public usedSignature;

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
            "Only for owners"
        );
        _;
    }

    modifier notCreator() {
        require(msg.sender != generalInfo.creator, "Have no permition");
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
                nowTime <= generalInfo.closeTimePresale, "Presale is not open yet or closed"
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
        require(block.timestamp >= generalInfo.openTimePresale - 86400 && block.timestamp < generalInfo.openTimePresale, "Register is closed or not open yet");
        _;
    }

    modifier inWhitelist() {
        require(whitelist[msg.sender], "You're not in whitelist");
        _;
    }

    modifier inWhitelistTierOneTwo() {
        require(whitelistTierOne[msg.sender] || whitelistTierTwo[msg.sender], "You're not in whitelist");
        _;
    }

    constructor(
        address payable _factory,
        address _library,
        address _platformOwner,
        address _devAddress,
        address _tokenAddress,
        address _WETHAddress
    )  {
        require(_factory != address(0));
        require(_library != address(0));
        require(_platformOwner != address(0));
        require(_devAddress != address(0));
        lessLib = LessLibrary(_library);
        factoryAddress = _factory;
        platformOwner = _platformOwner;
        devAddress = _devAddress;
        tokenAddress = _tokenAddress;
        WETHAddress = _WETHAddress;
        //generalInfo.closeTimeVoting = block.timestamp + lessLib.getVotingTime();
    }

    function init(
        address[2] memory _creatorToken,
        uint256[9] memory _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee
    ) external onlyFabric {
        require(
            _creatorToken[0] != address(0) && _creatorToken[1] != address(0),
            "Wrong addresses"
        );
        require(!initiate, "Function can work only once");
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[0] > 0,
            "Price should be more then zero"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[7] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] <
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[7],
            "Wrong time presale interval"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[3] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[4] > 0,
            "Wron soft or hard cup values"
        );
        require(_priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5] >= block.timestamp + 86400, "Wrong open voting time");
        uint256 closeVoting = _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[5] + lessLib.getVotingTime();
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[6] >= closeVoting,
            "Voting and investment should not overlap"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[1] != 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenOpenCloseFee[2] != 0,
            "Not null tokens amount"
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
                allocationTime > generalInfo.closeTimePresale,
            "Wrong arguments"
        );
        require(duration >= 30, "Duration should be at least 30 days");
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

    function isWhitelisting() public view returns(bool) {
        return block.timestamp <= generalInfo.openTimePresale;
    }

    function getWhitelistTierOneLength() 
        public
        view
    returns (uint256) {
        return whitelistTierOneArr.length;     
    }

    function getWhitelistTierTwoLength() 
        public
        view
    returns (uint256) {
        return whitelistTierTwoArr.length;     
    }

    function registerTierOneTwo(uint256 _tokenAmount, bytes memory _signature) external openRegister {
        require(!usedSignature[keccak256(_signature)]);
        require(
            _verifySigner(abi.encodePacked(_tokenAmount, msg.sender, address(this), tier12Registerconst), _signature),
            "Register: invalid signature"
        );
        tickets.push(TicketsInfo(msg.sender, _tokenAmount/500));
        if (_tokenAmount >= 1000 * tokenMagnitude &&  _tokenAmount < 5000 * tokenMagnitude) {
            require(!whitelistTierOne[msg.sender], "You're already in whitelist");
            whitelistTierOne[msg.sender] = true;
            whitelistTierOneArr.push(msg.sender);
        } else if (_tokenAmount >= 5000 * tokenMagnitude) {
            require(!whitelistTierTwo[msg.sender], "You're already in whitelist");
            whitelistTierTwo[msg.sender] = true;
            whitelistTierTwoArr.push(msg.sender);
        }
        usedSignature[keccak256(_signature)] = true;
    }

    function register(uint256 _tokenAmount, bytes memory _signature) external openRegister {
        require(!usedSignature[keccak256(_signature)]);
        require(
            _verifySigner(abi.encodePacked(_tokenAmount, msg.sender, address(this), tier35Registerconst), _signature),
            "Register: invalid signature"
        );
        require(!whitelist[msg.sender], "You're already in whitelist");
        whitelist[msg.sender] = true;
        usedSignature[keccak256(_signature)] = true;
    }

    function vote(bool _yes, uint256 _stakingAmount, bytes memory _signature) external onlyWhenOpenVoting presaleIsNotCancelled notCreator{
        require(_verifySigner(abi.encodePacked(_stakingAmount, msg.sender, address(this), votingConst), _signature));
        uint256 safeBalance = _stakingAmount;

        require(
            safeBalance >= lessLib.getMinVoterBalance(),
            "Not enough Less to vote"
        );
        require(voters[msg.sender] == 0, "Vote already casted");

        voters[msg.sender] = safeBalance;
        if (_yes) {
            intermediate.yesVotes = intermediate.yesVotes + safeBalance;
        } else {
            intermediate.noVotes = intermediate.noVotes + safeBalance;
        }
    }

    
    function _isLotteryWinner(uint256 _tokenAmount, bytes memory _signature) 
    public 
    view
    returns(bool) 
    {
        return _verifySigner(abi.encodePacked(_tokenAmount, msg.sender, address(this), lotteryConst), _signature);
    }

    // _tokenAmount only for non bnb tokens
    function invest(uint256 _tokenAmount, bytes memory _signature, uint256 _stakedAmount, bool _isTierOneTwo)
        public
        payable
        presaleIsNotCancelled
        onlyWhenOpenPresale
        votesPassed
        nonReentrant
        notCreator
    {
        require(!usedSignature[keccak256(_signature)]);
        if (_isTierOneTwo) {
            require(_verifySigner(abi.encodePacked(_stakedAmount, msg.sender, address(this), tier12Investconst), _signature), "Invest: Invalid signature");
            require(_isLotteryWinner(_stakedAmount, _signature), "Invest: you aren't a lottery winner");
        } else {
            require(_verifySigner(abi.encodePacked(_stakedAmount, msg.sender, address(this), tier35Investconst), _signature), "Invest: Invalid signature");
        }

        uint256 amount;
        if (tokenAddress == bnbAddress) {
            amount = msg.value;
        } else {
            amount = _tokenAmount;
        }

        address sender = msg.sender;
        uint256 tokensLeft;
        uint256 nowTime = block.timestamp;
        if(nowTime < generalInfo.openTimePresale + 3600){
            require(_stakedAmount >= 200000*tokenMagnitude, "You have no invest permition");
            tokensLeft = intermediate.beginingAmount * 30 / 100;
        }
        else if(nowTime < generalInfo.openTimePresale + 5400){
            require(_stakedAmount < 200000*tokenMagnitude && _stakedAmount >= 50000*tokenMagnitude, "You have no invest permition");
            tokensLeft = (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) + (intermediate.beginingAmount * 20 / 100);
        }
        else if(nowTime < generalInfo.openTimePresale + 6300){
            require(_stakedAmount < 50000*tokenMagnitude && _stakedAmount >= 20000*tokenMagnitude, "You have no invest permition");
            tokensLeft = (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) + (intermediate.beginingAmount * 15 / 100);
        }
        else if(nowTime < generalInfo.openTimePresale + 6900){
            require(_stakedAmount < 20000*tokenMagnitude && _stakedAmount >= 5000*tokenMagnitude, "You have no invest permition");
            tokensLeft = (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) + (intermediate.beginingAmount * 25 / 100);
        }
        else {
            tokensLeft = generalInfo.tokensForSaleLeft;
        }
        uint256 reservedTokens = getTokenAmount(amount);
        //tokensLeft = generalInfo.tokensForSaleLeft;
        require(
            intermediate.raisedAmount < generalInfo.hardCapInWei,
            "Hard cap reached"
        );
        require(tokensLeft >= reservedTokens, "Not enough tokens left");
        require(amount > 0, "Not null invest, please");
        uint256 safeBalance = _stakedAmount;
        /*require(
            msg.value <=
                (tokensLeft * generalInfo.tokenPriceInWei) / tokenMagnitude,
            "Not enough tokens left"
        );*/
        uint256 totalInvestmentInWei =
            investments[sender].amountEth + amount;
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

        if (investments[sender].amountEth == 0) {
            intermediate.participants += 1;
        }

        intermediate.raisedAmount += amount;
        investments[sender].amountEth = totalInvestmentInWei;
        investments[sender].amountTokens += reservedTokens;
        generalInfo.tokensForSaleLeft = tokensLeft - reservedTokens;

        usedSignature[keccak256(_signature)] = true;
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        votesPassed
        nonReentrant
    {
        require(
            block.timestamp >= generalInfo.openTimePresale,
            "Not yet opened"
        );
        require(
            investments[msg.sender].amountEth != 0,
            "You are not an invesor"
        );
        require(
            investments[msg.sender].amountEth >= amount,
            "You have not invest so much"
        );
        require(amount > 0, "Enter not zero amount");
        if (!intermediate.cancelled) {
            require(
                intermediate.raisedAmount < generalInfo.softCapInWei,
                "Couldn't withdraw investments after softCap collection"
            );
        }
        require(to != address(0), "Enter not a zero address");
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
            block.timestamp >= generalInfo.closeTimePresale,
            "Wait presale close time"
        );
        require(
            investments[msg.sender].amountEth != 0,
            "You are not an invesor"
        );
        require(
            !claimed[msg.sender],
            "You've already claimed your tokens"
        );
        claimed[msg.sender] = true; // make sure this goes first before transfer to prevent reentrancy
        generalInfo.token.transfer(
            msg.sender,
            investments[msg.sender].amountTokens
        );
    }

    function addLiquidity() external presaleIsNotCancelled nonReentrant {
        require(msg.sender == devAddress, "Function is only for backend");
        require(
            uniswapInfo.liquidityAllocationTime <= block.timestamp,
            "Too early to adding liquidity"
        );

        require(
            block.timestamp >= generalInfo.closeTimePresale,
            "Wait for presale closing"
        );
        require(
            !intermediate.liquidityAdded,
            "Liquidity has been already added"
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
            "Error liquidity"
        );

        IUniswapV2Router02 uniswapRouter =
            IUniswapV2Router02(address(lessLib.getUniswapRouter()));

        IERC20 token = generalInfo.token;

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        IWETH wETH = IWETH(WETHAddress);
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
        require(!withdrawedFunds, "Function works only once");
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
        require(lpAmount != 0, "LP Tokens has been already claimed");
        require(block.timestamp >= uniswapInfo.unlockTime, "Too early");
        require(
            IERC20(lpAddress).transfer(generalInfo.creator, lpAmount),
            "Couldn't get your tokens"
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
        require(generalInfo.collectedFee != 0, "Fee has already withdrawn");
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
            block.timestamp < openTimePresale,
            "Presale has already beginning"
        );
        require(
            _newCloseTime <= openTimePresale,
            "Voting and investment should not overlap"
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
            "Presale has already beginning"
        );
        require(
            generalInfo.closeTimeVoting < _newOpenTime,
            "Wrong new open presale time"
        );
        require(_newCloseTime > _newOpenTime, "Wrong new parameters");
        require(
            _newCloseTime < uniswapInfo.liquidityAllocationTime,
            "Wrong new close presale time"
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
            require(id != _id, "Wrong parameter");
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

    function _verifySigner(bytes memory data, bytes memory signature)
        public
        view
        returns (bool)
    {
        IPresaleFactory presaleFactory = IPresaleFactory(factoryAddress);
        address messageSigner =
            ECDSA.recover(keccak256(data), signature);
        require(
            presaleFactory.isSigner(messageSigner),
            "Signer is not authorised"
        );
        return true;
    }
}

