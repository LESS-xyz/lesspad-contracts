// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Staking.sol";
import "./LessLibrary.sol";
//import "./PresaleCertified.sol";
import "./PresalePublic.sol";

contract PresaleFactory {
    event PublicPresaleCreated(
        uint256 presaleId,
        address creator,
        address tokenAddress,
        uint256 timeForLiquidity
    );
    event CertifiedAutoPresaleCreated(
        uint256 presaleId,
        address creator,
        address tokenAddress,
        uint256 timeForLiquidity
    );
    event CertifiedPresaleCreated(
        uint256 presaleId,
        address creator,
        address tokenAddress
    );
    event Received(address indexed from, uint256 amount);

    LessLibrary public immutable safeLibrary;
    ERC20 public token;
    Staking public safeStakingPool;
    //mapping(address => uint256) public lastClaimedTimestamp;
    address public owner;

    constructor(
        address _bscsInfoAddress,
        address _bscsToken,
        address _safeStakingPool
    ) {
        safeLibrary = LessLibrary(_bscsInfoAddress);
        token = ERC20(_bscsToken);
        safeStakingPool = Staking(_safeStakingPool);
        owner = msg.sender;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    struct PresaleInfo {
        address tokenAddress;
        uint256 tokenPriceInWei;
        uint256 hardCapInWei;
        uint256 softCapInWei;
        uint256 maxInvestInWei;
        uint256 minInvestInWei;
        uint256 openTime;
        uint256 closeTime;
        uint8 presaleType;
        bool liquidity;
        bool automatically;
        bool whitelisted;
        address[] whitelist;
        bool vesting;
    }

    struct PresalePancakeSwapInfo {
        uint256 listingPriceInWei;
        uint256 lpTokensLockDurationInDays;
        uint8 liquidityPercentageAllocation;
        uint256 liquidityAllocationTime;
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

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyDev {
        require(msg.sender == owner || safeLibrary.getDev() == msg.sender);
        _;
    }

    function createPresalePublic(
        PresaleInfo calldata _info,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) external {
        require(
            _info.presaleType == 0,
            "Use other function for other presale type"
        );
        //timing check
        require(
            block.timestamp + safeLibrary.getVotingTime() <= _info.openTime &&
                _info.openTime < _info.closeTime &&
                _info.closeTime < _cakeInfo.liquidityAllocationTime,
            "Wrong timing"
        );
        require(
            _info.tokenPriceInWei > 0 &&
                _info.softCapInWei > 0 &&
                _info.hardCapInWei > 0 &&
                _info.hardCapInWei >= _info.softCapInWei,
            "Wrong parameters"
        );
        uint256 stakedBalance = safeLibrary.getStakedSafeBalance(msg.sender);
        require(
            stakedBalance >= safeLibrary.getMinCreatorStakedBalance(),
            "Stake LESS"
        );

        ERC20 _token = ERC20(_info.tokenAddress);
        PresalePublic presale =
            new PresalePublic(
                address(this),
                address(safeLibrary),
                safeLibrary.owner(),
                safeLibrary.getDev()
            );

        uint256 maxLiqPoolTokenAmount =
            ((_info.hardCapInWei *
                _cakeInfo.liquidityPercentageAllocation *
                (uint256(10)**uint256(token.decimals()))) /
                _cakeInfo.listingPriceInWei) * 100;

        uint256 maxTokensToBeSold =
            (((_info.hardCapInWei * 110) / 100) *
                (uint256(10)**uint256(token.decimals()))) /
                _info.tokenPriceInWei;
        uint256 requiredTokenAmount = maxLiqPoolTokenAmount + maxTokensToBeSold;
        require(
            maxLiqPoolTokenAmount > 0 && maxTokensToBeSold > 0,
            "Wrong parameters"
        );
        _token.transferFrom(msg.sender, address(presale), requiredTokenAmount);

        initializePresalePublic(
            presale,
            maxTokensToBeSold,
            maxLiqPoolTokenAmount,
            _info,
            _cakeInfo,
            _stringInfo
        );

        /*SafeTeslaLiquidityLock liquidityLock =
            new SafeTeslaLiquidityLock(
                ERC20(
                    safeLibrary.getCakeV2LPAddress(
                        address(_token),
                        safeLibrary.getWBNB()
                    )
                ),
                _cakeInfo.liquidityAddingTime +
                    (_cakeInfo.lpTokensLockDurationInDays * 1 days),
                msg.sender,
                address(0)
            );*/

        uint256 presaleId = safeLibrary.addPresaleAddress(address(presale));
        presale.setPresaleId(presaleId);
        emit PublicPresaleCreated(
            presaleId,
            msg.sender,
            _info.tokenAddress,
            _cakeInfo.liquidityAllocationTime
        );
    }

    /*function createPresaleCertified(
        PresaleInfo calldata _info,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) external {
        require(
            _info.presaleType == 1,
            "Use other function for other presale type"
        );
        uint256 stakedBalance = safeLibrary.getStakedSafeBalance(msg.sender);
        require(
            stakedBalance >= safeLibrary.getMinCreatorStakedBalance(),
            "Stake LESS"
        );

        ERC20 _token = ERC20(_info.tokenAddress);
        PresaleCertified presale =
            new PresaleCertified(
                address(this),
                address(safeLibrary),
                safeLibrary.owner(),
                safeLibrary.getDev()
            );

        uint256 maxTokensToBeSold =
            (((_info.hardCapInWei * 110) / 100) *
                (uint256(10)**uint256(token.decimals()))) /
                _info.tokenPriceInWei;
        uint256 maxLiqPoolTokenAmount;
        uint256 requiredTokenAmount;
        if (_info.liquidity) {
            maxLiqPoolTokenAmount =
                ((_info.hardCapInWei *
                    _cakeInfo.liquidityPercentageAllocation *
                    (uint256(10)**uint256(token.decimals()))) /
                    _cakeInfo.listingPriceInWei) * 100;
            require(
                maxLiqPoolTokenAmount > 0 && maxTokensToBeSold > 0,
                "Wrong parameters"
            );
            requiredTokenAmount = maxLiqPoolTokenAmount + maxTokensToBeSold;
        } else {
            requiredTokenAmount = maxTokensToBeSold;
            require(requiredTokenAmount > 0, "Wrong parameters");
        }
        _token.transferFrom(msg.sender, address(presale), requiredTokenAmount);

        initializePresaleCertified(
            presale,
            maxTokensToBeSold,
            maxLiqPoolTokenAmount,
            _info,
            _cakeInfo,
            _stringInfo
        );

        uint256 presaleId = safeLibrary.addPresaleAddress(address(presale));
        presale.setPresaleId(presaleId);
        if (_info.liquidity && _info.automatically) {
            emit CertifiedAutoPresaleCreated(presaleId, msg.sender, _info.tokenAddress, _cakeInfo.liquidityAllocationTime);
        } else {
            emit CertifiedPresaleCreated(presaleId, msg.sender, _info.tokenAddress);
        }
    }*/

    function initializePresalePublic(
        PresalePublic _presale,
        uint256 _tokensForSale,
        uint256 _tokensForLiquidity,
        PresaleInfo calldata _info,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) internal {
        _presale.init(
            [msg.sender, _info.tokenAddress],
            [_info.tokenPriceInWei,
            _tokensForSale,
            _tokensForLiquidity,
            _info.softCapInWei,
            _info.hardCapInWei],
            _cakeInfo.liquidityPercentageAllocation,
            [_cakeInfo.listingPriceInWei,
            _cakeInfo.lpTokensLockDurationInDays,
            _cakeInfo.liquidityAllocationTime,
            _info.openTime,
            _info.closeTime]
        );
        _presale.setStringInfo(
            _stringInfo.saleTitle,
            _stringInfo.linkTelegram,
            _stringInfo.linkGithub,
            _stringInfo.linkTwitter,
            _stringInfo.linkWebsite,
            _stringInfo.linkLogo,
            _stringInfo.description,
            _stringInfo.whitepaper
        );
    }

    /*function initializePresaleCertified(
        PresaleCertified _presale,
        uint256 _tokensForSale,
        uint256 _tokensForLiquidity,
        PresaleInfo calldata _info,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) internal {
        _presale.init(
            [msg.sender,
            _info.tokenAddress],
            [_info.tokenPriceInWei,
            _tokensForSale,
            _tokensForLiquidity,
            _info.softCapInWei,
            _info.hardCapInWei],
            _cakeInfo.liquidityPercentageAllocation,
            [_cakeInfo.listingPriceInWei,
            _cakeInfo.lpTokensLockDurationInDays,
            _cakeInfo.liquidityAllocationTime,
            _info.openTime,
            _info.closeTime],
            _info.whitelist,
            [_info.whitelisted,
            _info.liquidity,
            _info.automatically]
        );
        _presale.setStringInfo(
            _stringInfo.saleTitle,
            _stringInfo.linkTelegram,
            _stringInfo.linkGithub,
            _stringInfo.linkTwitter,
            _stringInfo.linkWebsite,
            _stringInfo.linkLogo,
            _stringInfo.description,
            _stringInfo.whitepaper
        );
    }*/

    /*function claimHodlerFund() external {
        require(address(this).balance > 0);
        require(
            lastClaimedTimestamp[msg.sender] + safeLibrary.getMinClaimTime() <=
                block.timestamp,
            "Do not qualify"
        );

        uint256 totalHodlerBalance =
            safeLibrary.getStakedSafeBalance(msg.sender);

        require(
            totalHodlerBalance >= safeLibrary.getMinRewardQualifyBal() &&
                totalHodlerBalance <= safeLibrary.getMaxRewardQualifyBal(),
            "Do not qualifY"
        );
        lastClaimedTimestamp[msg.sender] = block.timestamp;
        msg.sender.transfer(
            totalHodlerBalance.mul(address(this).balance).div(
                token.totalSupply()
            )
        );
    }*/

    function migrateTo(address payable _newFactory) external onlyDev {
        _newFactory.transfer(address(this).balance);
    }
}
