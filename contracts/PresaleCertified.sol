// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    mapping(address => Claimed) public claimed; // if true, it means investor already claimed the tokens or got a refund
    mapping(address => Investment) public investments; // total wei invested per address
    mapping(bytes32 => uint256) public usedSignature;
    mapping(address => bool) public whitelistTier;

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
    }

    struct Claimed {
        uint256 amountClaimed;
        uint256 lastTimeClaimed;
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
        if (certifiedAddition.liquidity) {
            require(intermediate.liquidityAdded, "A.LIQ");
        }
        _;
    }

    modifier onlyWhenOpenPresale() {
        uint256 nowTime = block.timestamp;
        require(
            nowTime >= generalInfo.openTimePresale &&
                nowTime <= generalInfo.closeTimePresale,
            "N.OPEN"
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
            "N.REG"
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
        require(!intermediate.initiate, "INITIATED");
        intermediate.initiate = true;
        require(
            _creatorToken[0] != address(0) && _creatorToken[1] != address(0),
            "ZERO ADDR"
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
        if (len > 0) {
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

    function approvePresale() external onlyPlatformOwner {
        require(!intermediate.approved, "APPROVED");
        intermediate.approved = true;
    }

    function register(
        uint256 _tokenAmount,
        uint256 _tier,
        uint256 _timestamp,
        bytes memory _signature
    ) external openRegister presaleIsNotCancelled {
        require(
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
            "W.PARAMS"
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
    ) public payable presaleIsNotCancelled onlyWhenOpenPresale nonReentrant {
        require(
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
            "SIGN/REG"
        );
        lessLib.setSingUsed(_signature, address(this));

        uint256 amount = (address(certifiedAddition.nativeToken) == address(0))
            ? msg.value
            : _tokenAmount;
        require(amount > 0, "can't invest zero");

        uint256 tokensLeft;
        uint256 nowTime = block.timestamp;
        if (certifiedAddition.whitelist.length > 0) {
            require(
                _stakedAmount >= stakingTiers[1],
                "TIER4/5"
            );
            tokensLeft = generalInfo.tokensForSaleLeft;
        } else {
            if (nowTime < generalInfo.openTimePresale + 3600) {
                require(
                    _stakedAmount >= stakingTiers[0],
                    "TIER 5"
                );
                tokensLeft =
                    (intermediate.beginingAmount * poolPercentages[0]) /
                    100;
            } else if (nowTime < generalInfo.openTimePresale + 5400) {
                require(
                    _stakedAmount >= stakingTiers[1],
                    "TIER 4"
                );
                tokensLeft =
                    (intermediate.beginingAmount -
                        generalInfo.tokensForSaleLeft) +
                    ((intermediate.beginingAmount * poolPercentages[1]) / 100);
            } else if (nowTime < generalInfo.openTimePresale + 6300) {
                require(
                    _stakedAmount >= stakingTiers[2],
                    "TIER 3"
                );
                tokensLeft =
                    (intermediate.beginingAmount -
                        generalInfo.tokensForSaleLeft) +
                    ((intermediate.beginingAmount * poolPercentages[2]) / 100);
            } else if (nowTime < generalInfo.openTimePresale + 6900) {
                require(
                    _stakedAmount >= stakingTiers[3],
                    "TIER 2"
                );
                tokensLeft =
                    (intermediate.beginingAmount -
                        generalInfo.tokensForSaleLeft) +
                    ((intermediate.beginingAmount * poolPercentages[3]) / 100);
            } else {
                require(
                    _stakedAmount >= stakingTiers[4],
                    "TIER 1"
                );
                tokensLeft = generalInfo.tokensForSaleLeft;
            }
        }
        uint256 reservedTokens = getTokenAmount(amount);
        require(
            intermediate.raisedAmount < generalInfo.hardCapInWei &&
                tokensLeft >= reservedTokens,
            "(N)ENOUGH"
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
            require(
                IERC20(certifiedAddition.nativeToken).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                ),
                "S.COIN TRANSFER"
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
            "W.PARAMS"
        );
        if (!intermediate.cancelled) {
            require(
                intermediate.raisedAmount < generalInfo.softCapInWei &&
                    !intermediate.liquidityAdded,
                "AFTERCAP"
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
            require(
                IERC20(certifiedAddition.nativeToken).transfer(to, amount),
                "S.COIN TRANSFER"
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
                claimed[msg.sender].amountClaimed <
                investments[msg.sender].amountTokens &&
                investments[msg.sender].amountEth != 0,
            "W.PARAMS"
        );
        if (certifiedAddition.vesting == 0) {
            claimed[msg.sender].amountClaimed = investments[msg.sender]
                .amountTokens; // make sure this goes first before transfer to prevent reentrancy
            require(
                IERC20(generalInfo.token).transfer(
                    msg.sender,
                    investments[msg.sender].amountTokens
                ),
                "T.TRANSFER"
            );
        } else {
            uint256 part = (investments[msg.sender].amountTokens *
                certifiedAddition.vesting) / 100;
            require(
                block.timestamp - claimed[msg.sender].lastTimeClaimed >=
                    2592000,
                "TIME"
            ); //one month vesting period == 30 days
            claimed[msg.sender].lastTimeClaimed = block.timestamp;
            if (
                part <=
                investments[msg.sender].amountTokens -
                    claimed[msg.sender].amountClaimed
            ) {
                claimed[msg.sender].amountClaimed += part;
                require(
                    IERC20(generalInfo.token).transfer(msg.sender, part),
                    "T.TRANSFER"
                );
            } else {
                part =
                    investments[msg.sender].amountTokens -
                    claimed[msg.sender].amountClaimed;
                claimed[msg.sender].amountClaimed = investments[msg.sender]
                    .amountTokens;
                require(
                    IERC20(generalInfo.token).transfer(msg.sender, part),
                    "CT.TRANSFER"
                );
            }
        }
    }

    function addLiquidity() external presaleIsNotCancelled nonReentrant {
        require(
            certifiedAddition.liquidity &&
                intermediate.raisedAmount >= generalInfo.softCapInWei &&
                uniswapInfo.liquidityAllocationTime <= block.timestamp &&
                !intermediate.liquidityAdded,
            "W.PARAMS"
        );
        if (certifiedAddition.automatically) {
            require(msg.sender == devAddress, "DEV");
        } else {
            require(msg.sender == generalInfo.creator, "CREATOR");
        }
        uint256 raisedAmount = intermediate.raisedAmount;

        intermediate.liquidityAdded = true;
        uniswapInfo.unlockTime =
            block.timestamp +
            (uniswapInfo.lpTokensLockDurationInDays * 24 * 60 * 60);

        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            address(lessLib.getUniswapRouter())
        );

        uint256 liqPoolEthAmount = (raisedAmount *
            uniswapInfo.liquidityPercentageAllocation) / 100;

        if (certifiedAddition.nativeToken != address(0)) {
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
            "N.ENOUGH"
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

        intermediate.raisedAmount -= amountEth;

        IUniswapV2Factory02 uniswapFactory = IUniswapV2Factory02(
            uniswapRouter.factory()
        );
        uniswapInfo.lpAddress = uniswapFactory.getPair(
            uniswapRouter.WETH(),
            address(token)
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
            intermediate.raisedAmount >= generalInfo.softCapInWei,
            "NO SOFTCAP"
        );
        require(!intermediate.withdrawedFunds, "ONCE");
        intermediate.withdrawedFunds = true;
        uint256 collectedBalance = intermediate.raisedAmount;
        if (address(0) == certifiedAddition.nativeToken) {
            payable(generalInfo.creator).transfer(collectedBalance);
        } else {
            require(
                IERC20(certifiedAddition.nativeToken).transfer(
                    generalInfo.creator,
                    collectedBalance
                ),
                "S.COIN TRANSFER"
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
                "T.TRANSFER"
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
            "LP.TRANSFER"
        );
        uniswapInfo.lpAmount = 0;
    }

    function collectFee() external nonReentrant {
        require(
            msg.sender == generalInfo.creator || msg.sender == platformOwner,
            "OWNERS"
        );
        uint256 collectedFee = generalInfo.collectedFee;
        require(collectedFee > 0, "WITHDRAWN");
        generalInfo.collectedFee = 0;
        if (intermediate.approved && !intermediate.cancelled) {
            payable(platformOwner).transfer(collectedFee);
        } else {
            intermediate.cancelled = true;
            payable(generalInfo.creator).transfer(collectedFee);
            uint256 bal = IERC20(generalInfo.token).balanceOf(address(this));
            if (bal > 0) {
                require(
                    IERC20(generalInfo.token).transfer(
                        generalInfo.creator,
                        bal
                    ),
                    "T.TRANSFER"
                );
            }
        }
    }

    function changePresaleTime(uint256 _newOpenTime, uint256 _newCloseTime)
        external
        presaleIsNotCancelled
        onlyPresaleCreator
    {
        require(
            block.timestamp < generalInfo.openTimePresale &&
                _newCloseTime - _newOpenTime > 6900 &&
                block.timestamp < _newOpenTime,
            "TIME"
        );
        if (certifiedAddition.whitelist.length == 0) {
            require(_newOpenTime > block.timestamp + 86400, "W.PARAMS");
        }
        if (certifiedAddition.liquidity) {
            require(
                _newCloseTime < uniswapInfo.liquidityAllocationTime,
                "W.LIQ.TIME"
            );
        }
        generalInfo.openTimePresale = _newOpenTime;
        generalInfo.closeTimePresale = _newCloseTime;
    }

    function cancelPresale() external presaleIsNotCancelled {
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
        intermediate.cancelled = true;
        uint256 bal = IERC20(generalInfo.token).balanceOf(address(this));
        if (bal > 0) {
            require(
                IERC20(generalInfo.token).transfer(generalInfo.creator, bal),
                "T.TRANSFER"
            );
        }
    }

    function setPresaleId(uint256 _id) external onlyFabric {
        if (id != 0) {
            require(id != _id);
        }
        id = _id;
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
            block.timestamp >= generalInfo.openTimePresale - 86400;
    }

    function getPresaleId() external view returns (uint256) {
        return id;
    }

    function getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        return (_weiAmount * tokenMagnitude) / generalInfo.tokenPriceInWei;
    }
}
