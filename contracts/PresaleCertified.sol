// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./pancake-swap/libraries/TransferHelper.sol";
import "./libraries/Calculations.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    address private devAddress;
    uint256 private tokenMagnitude;

    //mapping(address => Claimed) public claimed; // if true, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address
    mapping(address => bool) public whitelistTier;

    address[][5] public whitelist; //for backend
    uint8[4] public poolPercentages;
    uint256[5] public stakingTiers;

    uint256[4] private tiersTimes = [6900, 6300, 5400, 3600]; // 1h55m-> 1h45m -> 1h30m -> 1h PROD: [6900, 6300, 5400, 3600]

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
        bool privatePresale;
        uint8 vesting;
        address[] whitelist;
        address nativeToken;
    }

    struct IntermediateVariables {
        bool initiate;
        bool withdrawedFunds;
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
        address lpAddress;
        uint256 lpAmount;
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
        uint256 amountClaimed;
    }

    modifier onlyFabric() {
        require(factoryAddress == msg.sender);
        _;
    }

    modifier onlyPresaleCreator() {
        require(msg.sender == generalInfo.creator);
        _;
    }

    modifier liquidityAdded() {
        if (certifiedAddition.liquidity) {
            require(intermediate.liquidityAdded, "A.LIQ");
        }
        _;
    }

    modifier presaleIsNotCancelled() {
        require(!intermediate.cancelled);
        _;
    }

    constructor(
        address payable _factory,
        address _library,
        address _devAddress
    ) {
        require(
            _factory != address(0) &&
                _library != address(0) &&
                _devAddress != address(0)
        );
        lessLib = LessLibrary(_library);
        factoryAddress = _factory;
        platformOwner = lessLib.owner();
        devAddress = _devAddress;
    }

    receive() external payable {}

    function init(
        address[2] memory _creatorToken,
        uint256[8] memory _priceTokensForSaleLiquiditySoftHardOpenCloseFee
    ) external onlyFabric {
        require(!intermediate.initiate);
        intermediate.initiate = true;
        require(
            _creatorToken[0] != address(0) && _creatorToken[1] != address(0)
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
            .beginingAmount = _priceTokensForSaleLiquiditySoftHardOpenCloseFee[
            1
        ];
    }

    function setCertifiedAddition(
        bool _liquidity,
        bool _automatically,
        uint8 _vesting,
        address[] memory _whitelist,
        address _nativeToken
    ) external onlyFabric {
        uint256 len = _whitelist.length;
        bool privatePres;
        if (len > 0) {
            privatePres = true;
            for (uint256 i = 0; i < len; i++) {
                if (
                    _whitelist[i] != generalInfo.creator 
                ) whitelistTier[_whitelist[i]] = true;
            }
        }
        certifiedAddition = CertifiedAddition(
            _liquidity,
            _automatically,
            privatePres,
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
        uniswapInfo = PresaleUniswapInfo(
            price,
            duration,
            percent,
            allocationTime,
            0,
            address(0),
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

    function setPresaleId(uint256 _id) external onlyFabric {
        if (id != 0) {
            require(id != _id);
        }
        id = _id;
    }

    function approvePresale() external {
        uint256 regTime;
        if (!certifiedAddition.privatePresale)
            regTime = lessLib.getRegistrationTime();
        require(
            !intermediate.approved &&
                block.timestamp < generalInfo.openTimePresale - regTime &&
                platformOwner == msg.sender
        );
        intermediate.approved = true;
    }

    function register(
        uint256 _tokenAmount,
        uint256 _tier,
        uint256 _timestamp,
        bytes memory _signature
    ) external presaleIsNotCancelled {
        require(
            block.timestamp >=
                generalInfo.openTimePresale - lessLib.getRegistrationTime() &&
                block.timestamp < generalInfo.openTimePresale &&
                intermediate.approved &&
                certifiedAddition.whitelist.length == 0 &&
                _tier > 0 &&
                _tier < 6 &&
                msg.sender != generalInfo.creator &&
                !lessLib.getSignUsed(_signature) &&
                !whitelistTier[msg.sender] &&
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
                    1
                ),
            "W"
        );
        lessLib.setSingUsed(_signature, address(this));
        whitelistTier[msg.sender] = true;
        if (_tier < 3) {
            tickets.push(
                TicketsInfo(msg.sender, _tokenAmount / (500 * tokenMagnitude))
            );
        }
        whitelist[5 - _tier].push(msg.sender);
    }

    // _tokenAmount only for non bnb tokens
    // poolPercentages starts from 5th to 2nd teirs
    // Staking tiers also starts from 5th to 2nd tiers
    function invest(
        uint256 _tokenAmount,
        bytes memory _signature,
        uint256 _stakedAmount,
        uint256 _timestamp
    ) public payable presaleIsNotCancelled nonReentrant {
        require(
            block.timestamp >= generalInfo.openTimePresale &&
                block.timestamp <= generalInfo.closeTimePresale &&
                whitelistTier[msg.sender] &&
                !lessLib.getSignUsed(_signature) &&
                intermediate.approved &&
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
                    1
                ),
            "S.R."
        );
        lessLib.setSingUsed(_signature, address(this));

        uint256 amount = (address(certifiedAddition.nativeToken) == address(0))
            ? msg.value
            : _tokenAmount;
        require(amount > 0, "O");

        uint256 tokensLeft;
        uint256 tokensSold = intermediate.beginingAmount -
            generalInfo.tokensForSaleLeft;
        uint256 nowTime = block.timestamp;
        uint256[5] memory poolAmounts;
        uint256 prevPoolsTotalAmount;
        for (uint256 i = 0; i < 4; i++) {
            poolAmounts[i] =
                (intermediate.beginingAmount * poolPercentages[i]) /
                100;
        }
        if (certifiedAddition.whitelist.length > 0) {
            require(_stakedAmount >= stakingTiers[1], "4/5");
            tokensLeft = generalInfo.tokensForSaleLeft;
        } else {
            if (nowTime < generalInfo.openTimePresale + tiersTimes[3]) {
                require(_stakedAmount >= stakingTiers[0], "5");
                tokensLeft = poolAmounts[0] - tokensSold;
            } else if (nowTime < generalInfo.openTimePresale + tiersTimes[2]) {
                require(_stakedAmount >= stakingTiers[1], "4");
                prevPoolsTotalAmount = poolAmounts[0];
                tokensLeft = poolAmounts[1] + prevPoolsTotalAmount - tokensSold;
            } else if (nowTime < generalInfo.openTimePresale + tiersTimes[1]) {
                require(_stakedAmount >= stakingTiers[2], "3");
                prevPoolsTotalAmount = poolAmounts[0] + poolAmounts[1];
                tokensLeft = poolAmounts[2] + prevPoolsTotalAmount - tokensSold;
            } else if (nowTime < generalInfo.openTimePresale + tiersTimes[0]) {
                require(_stakedAmount >= stakingTiers[3], "2");
                prevPoolsTotalAmount =
                    poolAmounts[0] +
                    poolAmounts[1] +
                    poolAmounts[2];
                tokensLeft = poolAmounts[3] + prevPoolsTotalAmount - tokensSold;
            } else {
                require(_stakedAmount >= stakingTiers[4], "1");
                tokensLeft = generalInfo.tokensForSaleLeft;
            }
        }
        uint256 reservedTokens = getTokenAmount(amount);
        require(
            intermediate.raisedAmount < generalInfo.hardCapInWei &&
                tokensLeft >= reservedTokens,
            "N.E."
        );
        uint256 totalInvestmentInWei = investments[msg.sender].amountEth +
            amount;

        if (investments[msg.sender].amountEth == 0) {
            intermediate.participants += 1;
        }

        intermediate.raisedAmount += amount;
        investments[msg.sender].amountEth = totalInvestmentInWei;
        investments[msg.sender].amountTokens += reservedTokens;
        generalInfo.tokensForSaleLeft -= reservedTokens;

        if (address(certifiedAddition.nativeToken) != address(0))
            TransferHelper.safeTransferFrom(
                certifiedAddition.nativeToken,
                msg.sender,
                address(this),
                amount
            );
    }

    function withdrawInvestment(address payable to, uint256 amount)
        external
        nonReentrant
    {
        require(
            to != address(0) &&
                block.timestamp >= generalInfo.openTimePresale &&
                investments[msg.sender].amountEth >= amount &&
                amount > 0,
            "W"
        );
        if (!intermediate.cancelled) {
            require(
                intermediate.raisedAmount < generalInfo.softCapInWei &&
                    !intermediate.liquidityAdded,
                "S.L"
            );
        }
        if (investments[msg.sender].amountEth - amount == 0) {
            intermediate.participants -= 1;
        }
        uint256 reservedTokens = getTokenAmount(amount);
        intermediate.raisedAmount -= amount;
        investments[msg.sender].amountEth -= amount;
        investments[msg.sender].amountTokens -= reservedTokens;
        generalInfo.tokensForSaleLeft += reservedTokens;

        if (certifiedAddition.nativeToken == address(0)) {
            to.transfer(amount);
        } else {
            TransferHelper.safeTransfer(
                certifiedAddition.nativeToken,
                to,
                amount
            );
        }
    }

    function claimTokens()
        external
        nonReentrant
        liquidityAdded
        presaleIsNotCancelled
    {
        require(
            block.timestamp >= generalInfo.closeTimePresale &&
                investments[msg.sender].amountClaimed <
                investments[msg.sender].amountTokens &&
                investments[msg.sender].amountEth > 0,
            "W"
        );
        if (certifiedAddition.vesting == 0) {
            investments[msg.sender].amountClaimed = investments[msg.sender]
                .amountTokens; // make sure this goes first before transfer to prevent reentrancy
            require(
                IERC20(generalInfo.token).transfer(
                    msg.sender,
                    investments[msg.sender].amountTokens
                ),
                "T"
            );
        } else {
            uint256 beginingTime;
            if (certifiedAddition.liquidity) {
                beginingTime =
                    uniswapInfo.unlockTime -
                    uniswapInfo.lpTokensLockDurationInDays *
                    1 days; //PROD: 24*60*60
            } else {
                beginingTime = generalInfo.closeTimePresale;
            }
            uint256 numOfParts = (block.timestamp - beginingTime) / 2592000; //PROD: 2592000
            uint256 part = (investments[msg.sender].amountTokens *
                certifiedAddition.vesting) / 100;
            uint256 earnedTokens = numOfParts *
                part -
                investments[msg.sender].amountClaimed;
            require(earnedTokens > 0, "0");
            if (
                earnedTokens <=
                investments[msg.sender].amountTokens -
                    investments[msg.sender].amountClaimed
            ) {
                investments[msg.sender].amountClaimed += earnedTokens;
            } else {
                earnedTokens =
                    investments[msg.sender].amountTokens -
                    investments[msg.sender].amountClaimed;
                investments[msg.sender].amountClaimed = investments[msg.sender]
                    .amountTokens;
            }
            require(
                IERC20(generalInfo.token).transfer(
                    msg.sender,
                    earnedTokens
                ),
                "T"
            );
        }
    }

    function addLiquidity() external presaleIsNotCancelled nonReentrant {
        require(
            certifiedAddition.liquidity &&
                intermediate.raisedAmount >= generalInfo.softCapInWei &&
                uniswapInfo.liquidityAllocationTime <= block.timestamp &&
                !intermediate.liquidityAdded,
            "W"
        );
        if (certifiedAddition.automatically) {
            require(msg.sender == devAddress, "DEV");
        } else {
            require(msg.sender == generalInfo.creator, "CREATOR");
        }

        intermediate.liquidityAdded = true;
        uniswapInfo.unlockTime =
            block.timestamp +
            (uniswapInfo.lpTokensLockDurationInDays * 1 days); //PROD: 60*24*60

        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            address(lessLib.getUniswapRouter())
        );

        uint256 liqPoolEthAmount = (intermediate.raisedAmount *
            uniswapInfo.liquidityPercentageAllocation) / 100;

        if (certifiedAddition.nativeToken != address(0)) {
            TransferHelper.safeApprove(
                certifiedAddition.nativeToken,
                address(uniswapRouter),
                liqPoolEthAmount
            );
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
            "N.E."
        );

        generalInfo.tokensForLiquidityLeft -= liqPoolTokenAmount;

        IERC20 token = IERC20(generalInfo.token);

        token.approve(address(uniswapRouter), liqPoolTokenAmount);

        uint256 amountEth;

        (, amountEth, uniswapInfo.lpAmount) = uniswapRouter.addLiquidityETH{
            value: liqPoolEthAmount
        }(
            address(token),
            liqPoolTokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 15 minutes
        );

        IUniswapV2Factory02 uniswapFactory = IUniswapV2Factory02(
            uniswapRouter.factory()
        );
        uniswapInfo.lpAddress = uniswapFactory.getPair(
            uniswapRouter.WETH(),
            generalInfo.token
        );
    }

    function collectFundsRaised()
        external
        presaleIsNotCancelled
        nonReentrant
        onlyPresaleCreator
        liquidityAdded
    {
        require(
            !intermediate.withdrawedFunds &&
                block.timestamp >= generalInfo.closeTimePresale &&
                intermediate.raisedAmount >= generalInfo.softCapInWei,
            "OTS"
        );
        intermediate.withdrawedFunds = true;
        uint256 collectedBalance;
        if (address(0) == certifiedAddition.nativeToken) {
            collectedBalance = address(this).balance;
            if(generalInfo.collectedFee > 0){
                collectedBalance -= generalInfo.collectedFee;
            }
            payable(generalInfo.creator).transfer(collectedBalance);
        } else {
            collectedBalance = IERC20(certifiedAddition.nativeToken).balanceOf(
                address(this)
            );
            TransferHelper.safeTransfer(
                certifiedAddition.nativeToken,
                generalInfo.creator,
                collectedBalance
            );
        }
        uint256 unsoldTokensAmount = generalInfo.tokensForSaleLeft +
            generalInfo.tokensForLiquidityLeft;
        if (unsoldTokensAmount > 0) {
            require(
                IERC20(generalInfo.token).transfer(
                    generalInfo.creator,
                    unsoldTokensAmount
                ),
                "T"
            );
        }
    }

    function refundLpTokens()
        external
        presaleIsNotCancelled
        nonReentrant
        onlyPresaleCreator
        liquidityAdded
    {
        require(
            uniswapInfo.lpAmount > 0 &&
                block.timestamp >= uniswapInfo.unlockTime,
            "EARLY"
        );
        require(
            IERC20(uniswapInfo.lpAddress).transfer(
                generalInfo.creator,
                uniswapInfo.lpAmount
            ),
            "LP.T"
        );
        uniswapInfo.lpAmount = 0;
    }

    function collectFee() external nonReentrant {
        uint256 collectedFee = generalInfo.collectedFee;
        uint256 openTime = (certifiedAddition.privatePresale) ? generalInfo.openTimePresale : generalInfo.openTimePresale - lessLib.getRegistrationTime();
        require(collectedFee > 0 && openTime <= block.timestamp, "W");
        generalInfo.collectedFee = 0;
        if (intermediate.approved /* && !intermediate.cancelled */) {
            require(msg.sender == platformOwner);
            payable(platformOwner).transfer(collectedFee);
        } else {
            require(msg.sender == generalInfo.creator);
            if(!intermediate.cancelled){
                _cancelPresale();
            }
            payable(generalInfo.creator).transfer(collectedFee);
        }
    }

    function cancelPresale() public {
        if (
            intermediate.raisedAmount < generalInfo.softCapInWei &&
            block.timestamp >= generalInfo.closeTimePresale
        ) {
            require(
                msg.sender == generalInfo.creator ||
                    msg.sender == platformOwner,
                "OWNERS"
            );
        } else {
            require(msg.sender == platformOwner, "P.OWNER");
        }
        _cancelPresale();
    }

    function getWhitelist(uint256 _tier)
        external
        view
        returns (address[] memory)
    {
        if (certifiedAddition.whitelist.length > 0) {
            return certifiedAddition.whitelist;
        } else {
            return whitelist[5 - _tier];
        }
    }

    function isWhitelisting() external view returns (bool) {
        return
            block.timestamp <= generalInfo.openTimePresale &&
            block.timestamp >=
            generalInfo.openTimePresale - lessLib.getRegistrationTime();
    }

    function getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        return (_weiAmount * tokenMagnitude) / generalInfo.tokenPriceInWei;
    }

    function _cancelPresale() private presaleIsNotCancelled {
        intermediate.cancelled = true;
        uint256 bal = IERC20(generalInfo.token).balanceOf(address(this));
        if (bal > 0) {
            require(
                IERC20(generalInfo.token).transfer(generalInfo.creator, bal),
                "T"
            );
        }
    }
}
