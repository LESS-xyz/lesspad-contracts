// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LessLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interface.sol";

contract PresaleCertified is ReentrancyGuard {
    //initial values
    address payable presaleCreator;
    address platformOwner;
    address private devAddress;
    IERC20 public token;
    uint8 public tokenDecimals;
    uint256 public pricePerToken;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public openTimePresale;
    uint256 public closeTimePresale;
    uint8 public liquidityAllocation;
    uint256 public listingPrice;
    uint256 public liquidityLockDuration;
    uint256 public liquidityAllocationTime;
    //uint256 public minEthPerWallet;
    uint256 public unlockEthTime; // time when presale creator can collect funds raise
    //uint256 public headStart;
    uint256 public tokenMagnitude = 1e18;
    uint256 public minInvestInWei; // minimum wei amount that can be invested per wallet address
    uint256 public maxInvestInWei; // maximum wei amount that can be invested per wallet address
    uint256 private presaleId;
    uint256 private _creationTime;

    //bools variables
    bool liquidity;
    bool automatically;
    bool whitelisted;
    bool vesting;

    mapping(address => bool) whitelist;

    //presale values
    bool cancelled;
    bool liquidityAdded;
    uint256 public raisedAmount;
    uint256 public participants;
    address factoryAddress;
    uint256 public tokensLeft; // available tokens to be sold
    uint256 public tokensForLiquidity;
    address private lpAddress;
    uint256 private lpAmount;
    uint256 private counter;
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

    //other contracts
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

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(nowTime >= openTimePresale && nowTime <= closeTimePresale);
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!cancelled);
        _;
    }

    constructor(
        address _factory,
        address _library,
        address _platformOwner,
        address _devAddress
    ) {
        require(_factory != address(0));
        require(_library != address(0));
        require(_platformOwner != address(0));
        require(_devAddress != address(0));
        factoryAddress = _factory;
        lessLib = LessLibrary(_library);
        platformOwner = _platformOwner;
        devAddress = _devAddress;
        counter = 0;
        raisedAmount = 0;
        participants = 0;
        lpAmount = 0;
        cancelled = false;
        liquidityAdded = false;
        _creationTime = block.timestamp;
    }

    function init(
        address[2] memory _presaleCreatorAndToken,
        uint256[5] memory _priceTokensForSaleForLiqSoftHard,
        uint8 _liquidityAlloc,
        uint256[5] memory _listPriceDurationAllockTimeOpenCloseTime,
        address[] memory _whitelist,
        bool[3] memory _liquidityAutoPrivate
    )
        external
        //bool _vesting
        onlyFabric
    {
        require(_presaleCreatorAndToken[0] != address(0) && _presaleCreatorAndToken[1] != address(0));
        require(counter == 0, "Function can work only once");
        require(_priceTokensForSaleForLiqSoftHard[0] > 0, "Price should be more then zero");
        require(
            _listPriceDurationAllockTimeOpenCloseTime[3] > 0 && _listPriceDurationAllockTimeOpenCloseTime[4] > 0,
            "Wrong time presale interval"
        );
        require(_priceTokensForSaleForLiqSoftHard[3] > 0 && _priceTokensForSaleForLiqSoftHard[4] > 0, "Wron soft or hard cup values");
        require(
            _listPriceDurationAllockTimeOpenCloseTime[3] >= lessLib.getVotingTime() + block.timestamp,
            "Investment and check-in should not overlap"
        );
        require(_priceTokensForSaleForLiqSoftHard[1] != 0, "Not null tokens for sale amount");
        if (_liquidityAutoPrivate[0]) {
            require(
                _liquidityAlloc != 0 &&
                    _listPriceDurationAllockTimeOpenCloseTime[1] != 0 &&
                    _listPriceDurationAllockTimeOpenCloseTime[0] != 0 &&
                    _listPriceDurationAllockTimeOpenCloseTime[2] != 0,
                "Not null liquidity vars"
            );
            require(
                _listPriceDurationAllockTimeOpenCloseTime[2] > _listPriceDurationAllockTimeOpenCloseTime[4],
                "Wrong liquidity allocation time"
            );
            liquidity = _liquidityAutoPrivate[0];
            tokensForLiquidity = _priceTokensForSaleForLiqSoftHard[2];
            liquidityAllocation = _liquidityAlloc;
            listingPrice = _listPriceDurationAllockTimeOpenCloseTime[0];
            liquidityLockDuration = _listPriceDurationAllockTimeOpenCloseTime[1];
            liquidityAllocationTime = _listPriceDurationAllockTimeOpenCloseTime[2];
            automatically = _liquidityAutoPrivate[1];
        } else {
            liquidity = false;
            tokensForLiquidity = 0;
            liquidityAllocation = 0;
            listingPrice = 0;
            liquidityLockDuration = 0;
            liquidityAllocationTime = 0;
            automatically = false;
        }
        if (_liquidityAutoPrivate[2]) {
            for (uint256 i = 0; i < _whitelist.length; i++) {
                whitelisted = true;
                whitelist[_whitelist[i]] = true;
            }
        }
        presaleCreator = payable(_presaleCreatorAndToken[0]);
        token = IERC20(_presaleCreatorAndToken[1]);
        tokenDecimals = ERC20(_presaleCreatorAndToken[1]).decimals();
        pricePerToken = _priceTokensForSaleForLiqSoftHard[0];
        softCap = _priceTokensForSaleForLiqSoftHard[3];
        hardCap = _priceTokensForSaleForLiqSoftHard[4];
        tokensLeft = _priceTokensForSaleForLiqSoftHard[1];
        openTimePresale = _listPriceDurationAllockTimeOpenCloseTime[3];
        closeTimePresale = _listPriceDurationAllockTimeOpenCloseTime[4];
        tokenMagnitude = uint256(10)**uint256(tokenDecimals);
        counter++;
    }

    function invest() public payable presaleIsNotCancelled onlyWhenOpenPresale {
        if(whitelisted){
            require(whitelist[msg.sender], "You're not permit to invest");
        }
        uint256 reservedTokens = getTokenAmount(msg.value);
        require(raisedAmount < hardCap, "Hard cap reached");
        require(tokensLeft >= reservedTokens);
        require(msg.value > 0);
        uint256 safeBalance = lessLib.getStakedSafeBalance(msg.sender);
        require(
            msg.value <= (tokensLeft * pricePerToken) / tokenMagnitude,
            "Not enough tokens left"
        );
        uint256 totalInvestmentInWei =
            investments[msg.sender].amountEth + msg.value;
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

    function withdrawInvestment(address payable to, uint256 amount) external {
        if(whitelisted){
            require(whitelist[msg.sender], "You're not permit to invest");
        }
        require(block.timestamp >= openTimePresale, "Not yet opened");
        require(
            investments[msg.sender].amountEth != 0,
            "You are not an invesor"
        );
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

    function claimTokens() external nonReentrant presaleIsNotCancelled{
        if(whitelisted){
            require(whitelist[msg.sender], "You're not permit to invest");
        }
        require(liquidityAdded, "Liquidity is not provided");
        require(block.timestamp >= closeTimePresale, "Wait presale close time");
        require(
            investments[msg.sender].amountEth != 0,
            "You are not an invesor"
        );
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

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime)
        external
        presaleIsNotCancelled
    {
        require(msg.sender == platformOwner || msg.sender == presaleCreator);
        require(
            block.timestamp < openTimePresale,
            "Presale has already beginning"
        );
        require(
            _creationTime + lessLib.getVotingTime() < _newOpenTime,
            "Wrong new open presale time"
        );
        require(_newCloseTime > _newOpenTime, "Wrong new parameters");
        require(
            _newCloseTime < liquidityAllocationTime,
            "Wrong new close presale time"
        );
        openTimePresale = _newOpenTime;
        closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator || msg.sender == platformOwner);
        cancelled = true;
    }

    function getPresaleId() external view returns (uint256) {
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

    function addInWhitelist(address who) external {
        require(whitelisted, "No whitelist here");
        require(msg.sender == presaleCreator, "Function is only for presale creator");
        require(who != address(0), "Invalid address");
        whitelist[who] = true;
    }

    function removeFromWhitelist(address who) external {
        require(whitelisted, "No whitelist here");
        require(msg.sender == presaleCreator, "Function is only for presale creator");
        require(who != address(0) && whitelist[who], "Invalid address");
        whitelist[who] = false;
    }

    function addLiquidity() external presaleIsNotCancelled {
        require(liquidity, "No IDO presale");
        if (automatically) {
            require(msg.sender == devAddress, "Function is only for backend");
        } else {
            require(
                msg.sender == presaleCreator,
                "Function is only for presale creator"
            );
        }
        require(
            liquidityAllocationTime <= block.timestamp,
            "Too early to adding liquidity"
        );

        require(
            block.timestamp >= closeTimePresale,
            "Wait for presale closing"
        );
        require(!liquidityAdded, "Liquidity has been already added");
        require(raisedAmount > 0, "Have not raised amount");

        uint256 liqPoolEthAmount = (raisedAmount * liquidityAllocation) / 100;
        uint256 liqPoolTokenAmount =
            (liqPoolEthAmount * tokenMagnitude) / listingPrice;

        require(tokensForLiquidity >= liqPoolTokenAmount, "Error liquidity");

        IUniswapV2Router02 uniswapRouter =
            IUniswapV2Router02(address(lessLib.getUniswapRouter()));

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        ( , ,lpAmount) = uniswapRouter.addLiquidityETH{value: liqPoolEthAmount}(
            address(token),
            liqPoolTokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 15 minutes
        );

        require(lpAmount != 0, "lpAmount not null");

        IUniswapV2Factory02 uniswapFactory = IUniswapV2Factory02(uniswapRouter.factory());
        lpAddress = uniswapFactory.getPair(uniswapRouter.WETH(), address(token));

        tokensForLiquidity -= liqPoolTokenAmount;
        liquidityAdded = true;
        unlockEthTime =
            block.timestamp +
            (liquidityLockDuration * 24 * 60 * 60);
    }

    function collectFundsRaised() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator, "Function for presale creator");
        if (liquidity){
            require(liquidityAdded, "Add liquidity to get raised funds");
            //require(block.timestamp >= unlockEthTime);
        }

        uint256 collectedBalance = address(this).balance;

        if (collectedBalance > 0) {
            //uint256 fee = lessLib.calculateFee(collectedBalance);
            //address payable vault = lessLib.getVaultAddress();
            //lessLib.getVaultAddress().transfer(fee);
            presaleCreator.transfer(collectedBalance);
        }
    }

    function refundLpTokens() external presaleIsNotCancelled {
        require(msg.sender == presaleCreator, "Function for presale creator");
        if (liquidity){
            require(liquidityAdded, "Add liquidity to get raised funds");
            require(block.timestamp >= unlockEthTime, "Too early");
        }
        require(IERC20(lpAddress).transfer(presaleCreator, lpAmount), "Couldn't get your tokens");
    }

    function getUnsoldTokens() external presaleIsNotCancelled {
        require(liquidityAdded);
        require(
            msg.sender == presaleCreator || msg.sender == platformOwner,
            "Only for owners"
        );

        uint256 unsoldTokensAmount = tokensLeft + tokensForLiquidity;
        if (unsoldTokensAmount > 0) {
            token.transfer(presaleCreator, unsoldTokensAmount);
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
}
