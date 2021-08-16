// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PresaleCertified.sol";

contract PresaleFactoryCertified is ReentrancyGuard {
    LessLibrary public immutable safeLibrary;
    address public owner;

    struct PresaleInfo {
        address tokenAddress;
        uint256 tokenPriceInWei;
        uint256 hardCapInWei;
        uint256 softCapInWei;
        uint256 openTime;
        uint256 closeTime;
        uint256 _tokenAmount;
        bytes _signature;
        uint256 _timestamp;
        uint8[4] poolPercentages;
        uint256[5] stakingTiers;
    }

    struct CertifiedAddition {
        bool liquidity;
        bool automatically;
        uint8 vesting;
        address[] whitelist;
        address nativeToken;
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

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyDev() {
        require(msg.sender == owner || safeLibrary.getDev() == msg.sender);
        _;
    }

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

    constructor(address _bscsInfoAddress) {
        safeLibrary = LessLibrary(_bscsInfoAddress);
        owner = msg.sender;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function createPresaleCertified(
        PresaleInfo calldata _info,
        CertifiedAddition calldata _addition,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) external payable nonReentrant returns (uint256 presaleId) {
        require(
            safeLibrary.getMinCreatorStakedBalance() <= _info._tokenAmount &&
            !safeLibrary.getSignUsed(_info._signature) &&
                safeLibrary._verifySigner(
                    keccak256(
                        abi.encodePacked(
                            _info.tokenAddress,
                            msg.sender,
                            _info._tokenAmount,
                            _info._timestamp
                        )
                    ),
                    _info._signature,
                    1
                ),
            "SIGN"
        );
        if (_addition.liquidity) {
            require(
                _info.closeTime < _cakeInfo.liquidityAllocationTime &&
                    _cakeInfo.liquidityPercentageAllocation > 0 &&
                    _cakeInfo.listingPriceInWei > 0 &&
                    _cakeInfo.lpTokensLockDurationInDays > 29,
                "LIQ"
            );
        }
        if (_addition.whitelist.length == 0) {
            require(block.timestamp + safeLibrary.getRegistrationTime() <= _info.openTime, "TIME");
        } else {
            require(block.timestamp <= _info.openTime, "TIME");
        }
        require(
            6900 < _info.closeTime - _info.openTime &&
                _info.tokenPriceInWei > 0 &&
                _info.softCapInWei > 0 &&
                _info.hardCapInWei > 0 &&
                _info.hardCapInWei >= _info.softCapInWei,
            "PARAM"
        );
        if (address(0) != _addition.nativeToken) {
            require(
                safeLibrary.isValidStablecoin(_addition.nativeToken),
                "STABLECOIN"
            );
        }

        ERC20 _token = ERC20(_info.tokenAddress);

        uint256 feeEth = Calculations.usdtToEthFee(address(safeLibrary));
        //uint256 feeEth = 50000000000000000;
        require(msg.value >= feeEth && feeEth > 0, "FEE");

        // maxLiqPoolTokenAmount, maxTokensToBeSold, requiredTokenAmount
        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts = Calculations.countAmountOfTokens(
            _info.hardCapInWei,
            _info.tokenPriceInWei,
            _cakeInfo.listingPriceInWei,
            _cakeInfo.liquidityPercentageAllocation,
            _token.decimals()
        );

        PresaleCertified presale = new PresaleCertified(
            payable(address(this)),
            address(safeLibrary),
            safeLibrary.owner(),
            safeLibrary.getDev()
        );
        require(
            _token.transferFrom(msg.sender, address(presale), tokenAmounts[2]),
            "T.TRANSFER"
        );
        payable(address(presale)).transfer(feeEth);
        initializePresaleCertified(
            presale,
            [tokenAmounts[1], tokenAmounts[0], feeEth],
            _info,
            _addition,
            _cakeInfo,
            _stringInfo
        );
        presaleId = safeLibrary.addPresaleAddress(
            address(presale),
            _stringInfo.saleTitle,
            _stringInfo.description,
            true,
            0
        );
        presale.setPresaleId(presaleId);
        safeLibrary.setSingUsed(_info._signature, address(presale));
        if (_addition.liquidity && _addition.automatically) {
            emit CertifiedAutoPresaleCreated(
                presaleId,
                msg.sender,
                _info.tokenAddress,
                _cakeInfo.liquidityAllocationTime
            );
        } else {
            emit CertifiedPresaleCreated(
                presaleId,
                msg.sender,
                _info.tokenAddress
            );
        }
    }

    function initializePresaleCertified(
        PresaleCertified _presale,
        uint256[3] memory _tokensForSaleLiquidityFee,
        PresaleInfo calldata _info,
        CertifiedAddition calldata _addition,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) internal {
        _presale.init(
            [msg.sender, _info.tokenAddress],
            [
                _info.tokenPriceInWei,
                _tokensForSaleLiquidityFee[0],
                _tokensForSaleLiquidityFee[1],
                _info.softCapInWei,
                _info.hardCapInWei,
                _info.openTime,
                _info.closeTime,
                _tokensForSaleLiquidityFee[2]
            ]
        );

        _presale.setCertifiedAddition(
            _addition.liquidity,
            _addition.automatically,
            _addition.vesting,
            _addition.whitelist,
            _addition.nativeToken
        );

        if (_addition.liquidity) {
            _presale.setUniswapInfo(
                _cakeInfo.listingPriceInWei,
                _cakeInfo.lpTokensLockDurationInDays,
                _cakeInfo.liquidityPercentageAllocation,
                _cakeInfo.liquidityAllocationTime
            );
        }
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
        _presale.setArrays(_info.poolPercentages, _info.stakingTiers);
    }

    function migrateTo(address payable _newFactory) external onlyDev {
        _newFactory.transfer(address(this).balance);
    }
}
