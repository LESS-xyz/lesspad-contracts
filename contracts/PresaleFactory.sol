// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "./Staking.sol";
//import "./LessLibrary.sol";
import "./PresaleCertified.sol";
import "./PresalePublic.sol";
import "./libraries/Calculations.sol";

contract PresaleFactory {

    LessLibrary public immutable safeLibrary;
    ERC20 public lessToken;
    //Staking public safeStakingPool;
    PresalePublic presalePublic;
    //mapping(address => uint256) public lastClaimedTimestamp;
    address public owner;
    mapping(address => bool) private signers; //adresses that can call sign functions

    struct PresaleInfo {
        bool isCertified;
        address tokenAddress;
        uint256 tokenPriceInWei;
        uint256 hardCapInWei;
        uint256 softCapInWei;
        uint256 openVotingTime;
        uint256 openTime;
        uint256 closeTime;
        uint256 _tokenAmount;
        bytes _signature;
        uint256 _timestamp;
    }

    struct CertifiedAddition {
        bool liquidity;
        bool automatically;
        uint8 vesting;
        bool whitelisted;
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

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyDev {
        require(msg.sender == owner || safeLibrary.getDev() == msg.sender);
        _;
    }

    event PublicPresaleCreated(
        uint256 presaleId,
        address creator,
        address presaleAddress,
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

    constructor(
        address _bscsInfoAddress,
        address _bscsToken
        //address _safeStakingPool
    ) {
        safeLibrary = LessLibrary(_bscsInfoAddress);
        lessToken = ERC20(_bscsToken);
        //safeStakingPool = Staking(_safeStakingPool);
        owner = msg.sender;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function createPresale(
        PresaleInfo calldata _info,
        CertifiedAddition calldata _addition,
        PresalePancakeSwapInfo calldata _cakeInfo,
        PresaleStringInfo calldata _stringInfo
    ) external payable returns (uint256 presaleId) {
        require(safeLibrary.getSignUsed(_info._signature), "used sign");
        require(
            safeLibrary._verifySigner(
                abi.encodePacked(
                    address(lessToken),
                    msg.sender,
                    _info._tokenAmount,
                    _info._timestamp
                ),
                _info._signature
            ),
            "invalid signature"
        );
        //timing check
        require(
            _info.openTime > block.timestamp &&
                _info.openVotingTime + safeLibrary.getVotingTime() + 86400 <=
                _info.openTime &&
                _info.openTime < _info.closeTime &&
                _info.closeTime < _cakeInfo.liquidityAllocationTime,
            "timing err"
        );
        require(
            _info.tokenPriceInWei > 0 &&
                _info.softCapInWei > 0 &&
                _info.hardCapInWei > 0 &&
                _info.hardCapInWei >= _info.softCapInWei,
            "Wrong params"
        );

        ERC20 _token = ERC20(_info.tokenAddress);

        uint256 feeEth = Calculations.usdtToEthFee(address(safeLibrary));
        require(msg.value >= feeEth && feeEth > 0, "value<=0");

        // maxLiqPoolTokenAmount, maxTokensToBeSold, requiredTokenAmount
        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts = Calculations.countAmountOfTokens(
            _info.hardCapInWei,
            _info.tokenPriceInWei,
            _cakeInfo.listingPriceInWei,
            _cakeInfo.liquidityPercentageAllocation,
            _token.decimals()
        );

        if (!_info.isCertified) {
            PresalePublic presale = new PresalePublic(
                payable(address(this)),
                address(safeLibrary),
                safeLibrary.owner(),
                safeLibrary.getDev()
            );
            _token.transferFrom(msg.sender, address(presale), tokenAmounts[2]);
            payable(address(presale)).transfer(feeEth);
            initializePresalePublic(
                presale,
                [tokenAmounts[1], tokenAmounts[0], feeEth],
                _info,
                _cakeInfo,
                _stringInfo
            );
            presaleId = safeLibrary.addPresaleAddress(
                address(presale),
                _stringInfo.saleTitle,
                _stringInfo.description,
                false
            );
            presale.setPresaleId(presaleId);
            safeLibrary.setSingUsed(_info._signature, address(this));
            emit PublicPresaleCreated(
                presaleId,
                msg.sender,
                address(presale),
                _info.tokenAddress,
                _cakeInfo.liquidityAllocationTime
            );
        } else {
            PresaleCertified presale = new PresaleCertified(
                payable(address(this)),
                address(safeLibrary),
                safeLibrary.owner(),
                safeLibrary.getDev()
            );
            _token.transferFrom(msg.sender, address(presale), tokenAmounts[2]);
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
                true
            );
            presale.setPresaleId(presaleId);
            safeLibrary.setSingUsed(_info._signature, address(this));
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
    }

    function initializePresalePublic(
        PresalePublic _presale,
        uint256[3] memory _tokensForSaleLiquidityFee,
        PresaleInfo calldata _info,
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
                _info.openVotingTime,
                _info.openTime,
                _info.closeTime,
                _tokensForSaleLiquidityFee[2]
            ]
        );
        _presale.setUniswapInfo(
            _cakeInfo.listingPriceInWei,
            _cakeInfo.lpTokensLockDurationInDays,
            _cakeInfo.liquidityPercentageAllocation,
            _cakeInfo.liquidityAllocationTime
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
        if (_info.isCertified) {
            _presale.setCertifiedAddition(
                _addition.liquidity,
                _addition.automatically,
                _addition.vesting,
                _addition.whitelisted,
                _addition.whitelist,
                _addition.nativeToken
            );
        }
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
    }

    function migrateTo(address payable _newFactory) external onlyDev {
        _newFactory.transfer(address(this).balance);
    }

    function addOrRemoveSigner(address _address, bool _canSign) public onlyDev {
        signers[_address] = _canSign;
    }

    function isSigner(address _address) public view returns (bool) {
        return signers[_address];
    }
}
