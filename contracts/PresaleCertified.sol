// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/Calculations.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PresaleCertified is ReentrancyGuard {
    uint256 public id;

    address payable public factoryAddress;
    address public platformOwner;
    LessLibrary public lessLib;

    PresaleInfo public generalInfo;
    CertifiedAddition public certifiedAddition;
    PresaleUniswapInfo public uniswapInfo;
    PresaleStringInfo public stringInfo;
    IntermediateVariables public intermediate;

    bool private initiate;
    bool private withdrawedFunds;
    address private lpAddress;
    uint256 private lpAmount;
    address private devAddress;
    uint256 private tokenMagnitude;

    mapping(address => uint256) public claimed; // if true, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address

    mapping(address => bool) private whitelistTier;

    address[][5] public whitelist; //for backend

    mapping(bytes32 => uint256) public usedSignature;

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
        uint256 openTimePresale;
        uint256 closeTimePresale;
        uint256 collectedFee;
    }

    struct CertifiedAddition {
        bool liquidity;
        bool automatically;
        uint8 vesting;
        address[] whitelist;
        address nativeToken;
    }

    struct IntermediateVariables {
        bool approved;
        bool cancelled;
        bool liquidityAdded;
        uint256 beginingAmount;
        uint256 raisedAmount;
        uint256 participants;
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

    modifier liquidityAdded() {
        if(certifiedAddition.liquidity) {
            require(intermediate.liquidityAdded, "Add liquidity");
        }
        //require(intermediate.liquidityAdded, "Add liquidity");
        _;
    }

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(
            nowTime >= generalInfo.openTimePresale &&
                nowTime <= generalInfo.closeTimePresale,
            "Presale not open"
        );
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!intermediate.cancelled);
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
    }

    receive() external payable {}

    function init(
        address[2] memory _creatorToken,
        uint256[8] memory _priceTokensForSaleLiquiditySoftHardOpenCloseFee
    ) external onlyFabric {
        require(
            _creatorToken[0] != address(0) && _creatorToken[1] != address(0),
            "0 addr"
        );
        require(!initiate, "already inited");
        require(
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[0] > 0,
            "0 price"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[5] >
                block.timestamp + 86400 &&
                _priceTokensForSaleLiquiditySoftHardOpenCloseFee[5] <
                _priceTokensForSaleLiquiditySoftHardOpenCloseFee[6],
            "Wrong time"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[3] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenCloseFee[4] > 0 &&
                _priceTokensForSaleLiquiditySoftHardOpenCloseFee[4] >
                _priceTokensForSaleLiquiditySoftHardOpenCloseFee[3],
            "Wrong caps"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[1] + _priceTokensForSaleLiquiditySoftHardOpenCloseFee[2] > 0 ,
            "0 tokens"
        );
        require(
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[7] > 0,
            "No fee"
        );
        generalInfo = PresaleInfo(
            payable(_creatorToken[0]),
            _creatorToken[1],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[0],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[4],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[3],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[1],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[2],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[5],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[6],
            _priceTokensForSaleLiquiditySoftHardOpenCloseFee[7]
        );

        uint256 tokenDecimals = ERC20(_creatorToken[1]).decimals();
        tokenMagnitude = uint256(10)**uint256(tokenDecimals);
        intermediate
        .beginingAmount = _priceTokensForSaleLiquiditySoftHardOpenCloseFee[1];
        initiate = true;
    }

    function setCertifiedAddition(
        bool _liquidity,
        bool _automatically,
        uint8 _vesting,
        address[] memory _whitelist,
        address _nativeToken
    ) external onlyFabric {
        /*if (_liquidity) {
            require(generalInfo.tokensForLiquidityLeft > 0, "Wrong liquidity token amount param");
        }*/
        /*if(_liquidity){
            require(generalInfo.tokensForLiquidityLeft > 0, "Wrong liquidity token amount");
        }*/
        uint256 len = _whitelist.length;
        if (len != 0) {
            //require(_whitelisted, "Wrong whitelist param");
            for (uint256 i = 0; i < len; i++) {
                whitelistTier[_whitelist[i]] = true;
            }
        }
        certifiedAddition = CertifiedAddition(
            _liquidity,
            _automatically,
            _vesting,
            _whitelist,
            _nativeToken
        );
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
            "Wronh liquidity parameters"
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

    function approvePresale() external onlyPlatformOwner {
        intermediate.approved = true;
    }

    function getWhitelist(uint256 _tier)
        external
        view
        returns (address[] memory)
    {
        if(certifiedAddition.whitelist.length > 0){
            return certifiedAddition.whitelist;
        } else{
            return whitelist[5-_tier];
        }
    }

    function isWhitelisting() external view returns (bool) {
        return
            block.timestamp <= generalInfo.openTimePresale &&
            block.timestamp >= generalInfo.openTimePresale - 86400;
    }

    function register(
        uint256 _tokenAmount,
        uint256 _tier,
        uint256 _timestamp,
        bytes memory _signature
    ) external openRegister {
        require(intermediate.approved, "Presale is not approved");
        require(certifiedAddition.whitelist.length == 0, "There won't be registration");
        require(_tier > 0 && _tier<6, "wr tier");
        require(msg.sender != generalInfo.creator, "No permition");
        require(!lessLib.getSignUsed(_signature), "used sign");
        bytes memory encoded = abi.encodePacked(
                    _tokenAmount,
                    msg.sender,
                    address(this),
                    _timestamp
                );
        /*require(
            lessLib._verifySigner(
                keccak256(encoded),
                _signature,
                1
            ),
            "w sign"
        );*/
        if (_tier < 3) {
            tickets.push(TicketsInfo(msg.sender, _tokenAmount / (500*tokenMagnitude)));
        }
        require(!whitelistTier[msg.sender], "al. whitelisted");
        whitelistTier[msg.sender] = true;
        whitelist[5-_tier].push(msg.sender);
        //lessLib.setSingUsed(_signature, address(this));
    }

    /* function addInWhitelist(address addr) external onlyPresaleCreator {
        require(addr != address(0) && addr != msg.sender, "Wrong address");
        require(
            block.timestamp < generalInfo.openTimePresale,
            "Presale is running"
        );
        require(!whitelistTier[addr], "al. whitelisted");
        whitelistTier[addr] = true;
    } */

    // _tokenAmount only for non bnb tokens
    // poolPercentages starts from 5th to 2nd teirs
    // Staking tiers also starts from 5th to 2nd tiers
    function invest(
        uint256 _tokenAmount,
        bytes memory _signature,
        uint256 _stakedAmount,
        uint256 _timestamp,
        uint8[4] memory poolPercentages,
        uint256[5] memory stakingTiers
    ) public payable presaleIsNotCancelled onlyWhenOpenPresale nonReentrant {
        require(whitelistTier[msg.sender], "not in whitelist");
        //require(msg.sender != generalInfo.creator, "No permition");
        require(!lessLib.getSignUsed(_signature), "used sign");
        bytes memory encoded = abi.encodePacked(
                    _stakedAmount,
                    msg.sender,
                    address(this),
                    _timestamp
                );
        /*require(
            lessLib._verifySigner(
                keccak256(encoded),
                _signature,
                1
            ),
            "wrong sign"
        );*/
        require(intermediate.approved, "Presale is not approved");

        IUniswapV2Router02 uniswap = IUniswapV2Router02(
            lessLib.getUniswapRouter()
        );
        uint256 amount = (address(certifiedAddition.nativeToken) ==
            uniswap.WETH())
            ? msg.value
            : _tokenAmount;
        require(amount > 0, "can't invest zero");

        uint256 tokensLeft;
        uint256 nowTime = block.timestamp;
        if(certifiedAddition.whitelist.length > 0){
            require(_stakedAmount >= stakingTiers[1],
                "u cant vote");
            tokensLeft = generalInfo.tokensForSaleLeft;
        }
        else {
            if (nowTime < generalInfo.openTimePresale + 3600) {
                require(
                    _stakedAmount >= stakingTiers[0],
                    "u cant vote"
                );
                tokensLeft =
                    (intermediate.beginingAmount * poolPercentages[0]) /
                    100;
            } else if (nowTime < generalInfo.openTimePresale + 5400) {
                require(
                    _stakedAmount < stakingTiers[0] &&
                        _stakedAmount >= stakingTiers[1],
                    "u cant vote"
                );
                tokensLeft =
                    (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) +
                    ((intermediate.beginingAmount * poolPercentages[1]) / 100);
            } else if (nowTime < generalInfo.openTimePresale + 6300) {
                require(
                    _stakedAmount < stakingTiers[1] &&
                        _stakedAmount >= stakingTiers[2],
                    "u cant vote"
                );
                tokensLeft =
                    (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) +
                    ((intermediate.beginingAmount * poolPercentages[2]) / 100);
            } else if (nowTime < generalInfo.openTimePresale + 6900) {
                require(
                    _stakedAmount < stakingTiers[2] &&
                        _stakedAmount >= stakingTiers[3],
                    "u cant vote"
                );
                tokensLeft =
                    (intermediate.beginingAmount - generalInfo.tokensForSaleLeft) +
                    ((intermediate.beginingAmount * poolPercentages[3]) / 100);
            } else {
                require(_stakedAmount >= stakingTiers[4],
                    "u cant vote");
                tokensLeft = generalInfo.tokensForSaleLeft;
            }
        }
        uint256 reservedTokens = getTokenAmount(amount);
        require(intermediate.raisedAmount < generalInfo.hardCapInWei, "H cap");
        require(tokensLeft >= reservedTokens, "Not enough tokens in pool");
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

        //lessLib.setSingUsed(_signature, address(this));
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        nonReentrant
    {
        require(block.timestamp >= generalInfo.openTimePresale, "early");
        //require(investments[msg.sender].amountEth != 0, "n investor");
        require(investments[msg.sender].amountEth >= amount, "not enough amt");
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
                claimed[msg.sender] < investments[msg.sender].amountTokens &&
                investments[msg.sender].amountEth != 0
        );
        if (certifiedAddition.vesting == 0) {
            claimed[msg.sender] = investments[msg.sender].amountTokens; // make sure this goes first before transfer to prevent reentrancy
            require(
                IERC20(generalInfo.token).transfer(
                    msg.sender,
                    investments[msg.sender].amountTokens
                ),
                "Can't get your tokens"
            );
        } else {
            uint256 part = (investments[msg.sender].amountTokens *
                certifiedAddition.vesting) / 100;
            if (
                part <=
                investments[msg.sender].amountTokens - claimed[msg.sender]
            ) {
                require(
                    IERC20(generalInfo.token).transfer(msg.sender, part),
                    "Can't get your tokens"
                );
                claimed[msg.sender] += part;
            } else {
                require(
                    IERC20(generalInfo.token).transfer(
                        msg.sender,
                        investments[msg.sender].amountTokens -
                            claimed[msg.sender]
                    ),
                    "Can't get your tokens"
                );
                claimed[msg.sender] += investments[msg.sender].amountTokens;
            }
        }
    }

    function addLiquidity() external presaleIsNotCancelled nonReentrant {
        require(certifiedAddition.liquidity, "Liquidity not provided");
        if (certifiedAddition.automatically) {
            require(msg.sender == devAddress, "only dev");
        } else {
            require(msg.sender == generalInfo.creator, "only creator");
        }
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

        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            address(lessLib.getUniswapRouter())
        );

        uint256 liqPoolEthAmount = (raisedAmount *
            uniswapInfo.liquidityPercentageAllocation) / 100;

        if (certifiedAddition.nativeToken != uniswapRouter.WETH()) {
            liqPoolEthAmount = Calculations.swapNativeToEth(
                address(this),
                address(lessLib),
                certifiedAddition.nativeToken,
                liqPoolEthAmount
            );
        }

        uint256 liqPoolTokenAmount = (liqPoolEthAmount * tokenMagnitude) /
            uniswapInfo.listingPriceInWei;

        require(
            generalInfo.tokensForLiquidityLeft >= liqPoolTokenAmount,
            "no liquidity"
        );

        IERC20 token = IERC20(generalInfo.token);

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        uint256 amountEth;

        (, amountEth, lpAmount) = uniswapRouter.addLiquidityETH{
            value: liqPoolEthAmount
        }(
            address(token),
            liqPoolTokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 15 minutes
        );

        intermediate.raisedAmount -= amountEth;

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
        require(!withdrawedFunds, "only once");
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            address(lessLib.getUniswapRouter())
        );
        if (uniswapRouter.WETH() == certifiedAddition.nativeToken) {
            uint256 collectedBalance = payable(address(this)).balance;
            if (collectedBalance > 0) {
                /*uint256 fee = lessLib.calculateFee(collectedBalance);
                lessLib.getVaultAddress().transfer(fee);*/
                payable(generalInfo.creator).transfer(
                    payable(address(this)).balance - generalInfo.collectedFee
                );
            }
        } else {
            uint256 collectedBalance = IERC20(certifiedAddition.nativeToken)
            .balanceOf(address(this));
            if (collectedBalance > 0) {
                //uint256 fee = lessLib.calculateFee(collectedBalance);
                //lessLib.getVaultAddress().transfer(fee);
                require(
                    IERC20(certifiedAddition.nativeToken).transfer(
                        generalInfo.creator,
                        collectedBalance
                    ),
                    "Can not get your tokens"
                );
                /*generalInfo.creator.transfer(
                    payable(address(this)).balance - generalInfo.collectedFee
                );*/
            }
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

    function collectFee() external nonReentrant {
        require(generalInfo.collectedFee != 0, "already withdrawn");
        if (intermediate.approved && !intermediate.cancelled && block.timestamp < generalInfo.openTimePresale) {
            payable(platformOwner).transfer(generalInfo.collectedFee);
        } else {
            payable(generalInfo.creator).transfer(generalInfo.collectedFee);
            intermediate.cancelled = true;
        }
        //payable(platformOwner).transfer(generalInfo.collectedFee);
        generalInfo.collectedFee = 0;
    }

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime)
        external
        presaleIsNotCancelled
        onlyPresaleCreator
    {
        require(block.timestamp < generalInfo.openTimePresale, "started");
        if (certifiedAddition.whitelist.length > 0) {
            require(_newOpenTime > block.timestamp + 86400, "wrong param");
        }
        require(
            _newCloseTime - _newOpenTime > 6900 &&
                _newCloseTime < uniswapInfo.liquidityAllocationTime
        );
        generalInfo.openTimePresale = _newOpenTime;
        generalInfo.closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled onlyPlatformOwner {
        _withdrawUnsoldTokens();
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

    function _withdrawUnsoldTokens() internal nonReentrant {
        uint256 unsoldTokensAmount = generalInfo.tokensForSaleLeft +
            generalInfo.tokensForLiquidityLeft;
        if (unsoldTokensAmount > 0) {
            require(
                IERC20(generalInfo.token).transfer(
                    generalInfo.creator,
                    unsoldTokensAmount
                ),
                "can't send tokens"
            );
        }
    }
}
