// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LessLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PresaleSale is ReentrancyGuard {
    address payable presaleCreator;
    address platformOwner;
    IERC20 public token;
    uint8 public tokenDecimals;
    uint256 public pricePerToken;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public closeTimeVoting;
    uint256 public openTimePresale;
    uint256 public closeTimePresale;
    uint256 public unlockEthTime; // time when presale creator can collect funds raise
    uint256 public tokenMagnitude = 1e18;
    uint256 public minInvestInWei; // minimum wei amount that can be invested per wallet address
    uint256 public maxInvestInWei; // maximum wei amount that can be invested per wallet address
    uint256 private presaleId;

    bool cancelled;
    uint256 public raisedAmount;
    uint256 public participants;
    address factoryAddress;
    uint256 public yesVotes;
    uint256 public noVotes;
    uint256 public tokensLeft; // available tokens to be sold
    uint256 private counter;
    mapping(address => uint256) public voters;
    mapping(address => bool) public claimed; // if true, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address

    //stringInfo
    bytes32 public saleTitle;
    bytes32 public linkTelegram;
    bytes32 public linkTwitter;
    bytes32 public linkGithub;
    bytes32 public linkWebsite;
    string public linkLogo;
    string public description;
    string public whitepaper;

    LessLibrary public lessLib;

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

    modifier onlyWhenOpenVoting() {
        require(block.timestamp <= closeTimeVoting);
        _;
    }

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(nowTime >= openTimePresale && nowTime <= closeTimePresale);
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!cancelled);
        _;
    }

    modifier votesPassed() {
        require(
            yesVotes >= noVotes &&
                yesVotes >= lessLib.getMinYesVotesThreshold(),
            "Votes not passed"
        );
        _;
    }

    constructor(
        address _factory,
        address _library,
        address _platformOwner
    ) {
        require(_factory != address(0));
        require(_library != address(0));
        require(_platformOwner != address(0));
        factoryAddress = _factory;
        lessLib = LessLibrary(_library);
        platformOwner = _platformOwner;
        counter = 0;
        yesVotes = 0;
        noVotes = 0;
        raisedAmount = 0;
        participants = 0;
        closeTimeVoting = block.timestamp + lessLib.getVotingTime();
        cancelled = false;
    }

    function init(
        address _presaleCreator,
        address _token,
        uint256 _price,
        uint256 _tokensForSale,
        uint256 _soft,
        uint256 _hard,
        uint256 _openPresale,
        uint256 _closePresale
    ) external onlyFabric {
        require(_presaleCreator != address(0));
        require(_token != address(0));
        require(counter == 0, "Function can work only once");
        require(_price > 0, "Price should be more then zero");
        require(
            _openPresale > 0 && _closePresale > 0,
            "Wrong time presale interval"
        );
        require(_soft > 0 && _hard > 0, "Wron soft or hard cup values");
        require(
            _openPresale >= closeTimeVoting,
            "Voting and investment should not overlap"
        );
        require(
            _tokensForSale != 0,
            "Not null tokens amount"
        );
        presaleCreator = payable(_presaleCreator);
        token = IERC20(_token);
        tokenDecimals = ERC20(_token).decimals();
        pricePerToken = _price;
        softCap = _soft;
        hardCap = _hard;
        tokensLeft = _tokensForSale;
        openTimePresale = _openPresale;
        closeTimePresale = _closePresale;
        tokenMagnitude = uint256(10)**uint256(tokenDecimals);
        counter++;
    }

    function vote(bool yes) external onlyWhenOpenVoting presaleIsNotCancelled {
        uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);

        require(
            safeBalance >= lessLib.getMinVoterBalance(),
            "Not enough Less to vote"
        );
        require(voters[msg.sender] == 0, "Vote already casted");

        voters[msg.sender] = safeBalance;
        if (yes) {
            yesVotes = yesVotes + safeBalance;
        } else {
            noVotes = noVotes + safeBalance;
        }
    }

    function getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        uint256 amount = lessLib.getStakedSafeBalance(msg.sender);
        uint256 discount = 0;
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

        return 0;

        //uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);

        /*if (safeBalance >= minRewardQualifyBal) {
            uint256 pctQualifyingDiscount =
                tokenPriceInWei.mul(minRewardQualifyPercentage).div(100);
            return
                _weiAmount.mul(tokenMagnitude).div(
                    tokenPriceInWei.sub(pctQualifyingDiscount)
                );
        } else {
            return _weiAmount.mul(tokenMagnitude).div(tokenPriceInWei);
        }*/

        //return (_weiAmount * tokenMagnitude) / pricePerToken;
    }

    function invest()
        public
        payable
        presaleIsNotCancelled
        onlyWhenOpenPresale
        votesPassed
    {
        uint256 reservedTokens = getTokenAmount(msg.value);
        require(raisedAmount < hardCap, "Hard cap reached");
        require(tokensLeft >= reservedTokens);
        require(msg.value > 0);
        uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);
        require(
            msg.value <= (tokensLeft * pricePerToken) / tokenMagnitude,
            "Not enough tokens left"
        );
        uint256 totalInvestmentInWei = investments[msg.sender].amountEth + msg.value;
        require(
            totalInvestmentInWei >= minInvestInWei ||
                raisedAmount >= hardCap - 1 ether,
            "Min investment not reached"
        );
        require(
            maxInvestInWei == 0 || totalInvestmentInWei <= maxInvestInWei,
            "Max investment reached"
        );

        uint256 minInvestorBalance = lessLib.getMinInvestorBalance();
        require(
            minInvestorBalance == 0 || safeBalance >= minInvestorBalance,
            "Stake LessTokens"
        );

        if (investments[msg.sender].amountEth == 0) {
            participants += 1;
        }

        raisedAmount += msg.value;
        investments[msg.sender].amountEth = totalInvestmentInWei;
        investments[msg.sender].amountTokens += reservedTokens;
        tokensLeft = tokensLeft - reservedTokens;
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        votesPassed
    {
        require(block.timestamp >= openTimePresale, "Not yet opened");
        require(investments[msg.sender].amountEth != 0, "You are not an invesor");
        require(
            investments[msg.sender].amountEth >= amount,
            "You have not invest so much"
        );
        require(amount > 0, "Enter not zero amount");
        if (!cancelled) {
            require(
                raisedAmount < softCap,
                "Couldn't withdraw investments after softCap collection"
            );
        }
        //require(raisedAmount < softCap, "Couldn't withdraw investments after softCap collection");
        require(to != address(0), "Enter not a zero address");
        if (investments[msg.sender].amountEth - amount == 0) {
            participants -= 1;
        }
        to.transfer(amount);
        uint256 reservedTokens = getTokenAmount(amount);
        raisedAmount -= amount;
        investments[msg.sender].amountEth -= amount;
        investments[msg.sender].amountTokens -= reservedTokens;
        tokensLeft += reservedTokens;
    }

    function claimTokens() external nonReentrant {
        /*require(
            raisedAmount >= hardCap,
            "You can claim tokens after collection a hardCap"
        );*/
        require(block.timestamp >= closeTimePresale, "Wait presale close time");
        require(investments[msg.sender].amountEth != 0, "You are not an invesor");
        require(
            !claimed[msg.sender],
            "You've been already claimed your tokens"
        );
        claimed[msg.sender] = true; // make sure this goes first before transfer to prevent reentrancy
        token.transfer(msg.sender, investments[msg.sender].amountTokens);
    }

    receive() external payable {
        invest();
    }

    function changeCloseTimeVoting(uint256 _newCloseTime) external presaleIsNotCancelled {
        require(msg.sender == platformOwner || msg.sender == presaleCreator);
        require(block.timestamp < openTimePresale, "Presale has already beginning");
        require(
            _newCloseTime <= openTimePresale,
            "Voting and investment should not overlap"
        );
        closeTimeVoting = _newCloseTime;
    }

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime) external presaleIsNotCancelled {
        require(msg.sender == platformOwner || msg.sender == presaleCreator);
        require(block.timestamp < openTimePresale, "Presale has already beginning");
        require(closeTimeVoting < _newOpenTime, "Wrong new open presale time");
        require(_newCloseTime > _newOpenTime, "Wrong new parameters");
        openTimePresale = _newOpenTime;
        closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator || msg.sender == platformOwner);
        cancelled = true;
    }

    function getPresaleId() external view onlyFabric returns (uint256) {
        return presaleId;
    }

    function setPresaleId(uint256 _id) external onlyFabric {
        presaleId = _id;
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
        saleTitle = _saleTitle;
        linkTelegram = _linkTelegram;
        linkGithub = _linkGithub;
        linkTwitter = _linkTwitter;
        linkWebsite = _linkWebsite;
        linkLogo = _linkLogo;
        description = _description;
        whitepaper = _whitepaper;
    }

    function collectFundsRaised() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator, "Function for presale creator");
        require(block.timestamp >= unlockEthTime);

        uint256 collectedBalance = address(this).balance;

        if (collectedBalance > 0) {
            uint256 fee = lessLib.calculateFee(collectedBalance);
            //address payable vault = lessLib.getVaultAddress();
            lessLib.getVaultAddress().transfer(fee);
            presaleCreator.transfer(address(this).balance);
        }
    }

    function getUnsoldTokens() external presaleIsNotCancelled{
        require(msg.sender == presaleCreator || msg.sender == platformOwner, "Only for owners");

        uint256 unsoldTokensAmount = tokensLeft;
        if (unsoldTokensAmount > 0) {
            token.transfer(presaleCreator, unsoldTokensAmount);
        }
    }
}