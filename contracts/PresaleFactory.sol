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
    PresalePublic presalePublic;
    //mapping(address => uint256) public lastClaimedTimestamp;
    address public owner;
    mapping (address => bool) private signers; //adresses that can call sign functions 

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
        uint256 openVotingTime;
        uint256 openTime;
        uint256 closeTime;
        uint256 _tokenAmount;
        bytes _signature;
        address WETHAddress;
        /*bool liquidity;
        bool automatically;
        bool whitelisted;
        address[] whitelist;
        bool vesting;*/
    }

    struct CertifiedAddition {
        bool liquidity;
        bool automatically;
        bool vesting;
        bool whitelisted;
        address[] whitelist;
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
    ) external payable returns (uint256 presaleId) {
        /*require(
            _info.presaleType == 0,
            "Use other function for other presale type"
        );*/
        
        require(presalePublic._verifySigner(abi.encodePacked(address(token), msg.sender, _info._tokenAmount), _info._signature),
                "PresaleFactory: invalid signature");
        //timing check
        require(
                _info.openTime > block.timestamp &&
                _info.openVotingTime + safeLibrary.getVotingTime() + 86400 <= _info.openTime &&
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
                payable(address(this)),
                address(safeLibrary),
                safeLibrary.owner(),
                safeLibrary.getDev(),
                address(0),
                _info.WETHAddress
            );

        address presaleAddress = address(presale);
        address payable payableAddress = payable(address(presaleAddress));

        //uint256 fee;
        uint256 fee = 500000000000000000;
        /*{
            IUniswapV2Router02 uniswap =
                IUniswapV2Router02(safeLibrary.getUniswapRouter());
            (uint256 feeFromLib, address tether) = safeLibrary.getUsdtFee();
            address[] memory path = new address[](2);
            path[0] = uniswap.WETH();
            path[1] = tether;
            uint256[] memory usdtFee = uniswap.getAmountsIn(feeFromLib, path);
            require(msg.value >= usdtFee[0], "Too low msg.value");
            fee = usdtFee[0];
        }*/
        require(msg.value >= fee && fee > 0, "Not enough ETH");

        uint256 maxLiqPoolTokenAmount =
            ((_info.hardCapInWei *
                _cakeInfo.liquidityPercentageAllocation *
                (uint256(10)**uint256(token.decimals()))) /
                (_cakeInfo.listingPriceInWei * 100));

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
        payableAddress.transfer(fee);

        //initialize
        initializePresalePublic(
            presale,
            [maxTokensToBeSold,
            maxLiqPoolTokenAmount,
            fee],
            _info,
            _cakeInfo,
            _stringInfo
        );

        presaleId = safeLibrary.addPresaleAddress(address(presale), _stringInfo.saleTitle, _stringInfo.description, false);
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

    function isSigner(address _address)
        public
        view
    returns (bool) {
        return signers[_address];
    }

    function addSigner(address _address)
        public
        onlyDev
    {
        signers[_address] = true;
    }

    function removeSigner(address _address)
        public
        onlyDev
    {
        signers[_address] = false;
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
