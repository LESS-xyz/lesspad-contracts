// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface.sol";

contract LessLibrary is Ownable {
    PresaleInfo[] private presaleAddresses; // track all presales created

    uint256 private minInvestorBalance = 1000 * 1e18;
    uint256 private votingTime = 3 days; //three days
    uint256 private minStakeTime = 1 days; //one day
    uint256 private minUnstakeTime = 6 days; //six days

    address public factoryAddress;

    uint256 private minVoterBalance = 500 * 1e18; // minimum number of  tokens to hold to vote
    uint256 private minCreatorStakedBalance = 8000 * 1e18; // minimum number of tokens to hold to launch rocket

    uint8 private feePercent = 2;
    uint32 private usdtFee = 1 * 1e6;

    address private uniswapRouter; // uniswapV2 Router
    address public tether;
    address public usdCoin;

    address payable private lessVault;
    address private devAddress;
    //IStaking public safeStakingPool;

    mapping(address => bool) private isPresale;
    mapping(bytes32 => bool) public usedSignature;

    struct PresaleInfo {
        bytes32 title;
        address presaleAddress;
        string description;
        bool isCertified;
    }

    modifier onlyDev() {
        require(owner() == msg.sender || msg.sender == devAddress, "onlyDev");
        _;
    }

    modifier onlyPresale() {
        require(isPresale[msg.sender], "Not presale");
        _;
    }

    modifier onlyFactory() {
        require(factoryAddress == msg.sender, "onlyFactory");
        _;
    }

    constructor(address _dev, address payable _vault, address _uniswapRouter, address _tether, address _usdc) {
        require(_dev != address(0));
        require(_vault != address(0));
        devAddress = _dev;
        lessVault = _vault;
        uniswapRouter = _uniswapRouter;
        tether = _tether;
        usdCoin = _usdc;
    }

    function setFactoryAddress(address _factory) external onlyDev {
        require(_factory != address(0));
        factoryAddress = _factory;
    }

    function setUsdtFee(uint32 _newAmount) external onlyDev {
        require(_newAmount > 0, "0 amt");
        usdtFee = _newAmount;
    }

    function getUsdtFee() external view onlyFactory returns(uint256, address) {
        return (usdtFee, tether);
    }

    function setTetherAddress(address _newAddress) external onlyDev {
        require(_newAddress != address(0), "0 addr");
        tether = _newAddress;
    }

    function setMinStakeTime(uint256 _new) external onlyDev {
        minStakeTime = _new;
    }

    function setMinUnstakeTime(uint256 _new) external onlyDev {
        minUnstakeTime = _new;
    }

    function addPresaleAddress(address _presale, bytes32 _title, string memory _description, bool _type)
        external
        onlyFactory
        returns (uint256)
    {
        presaleAddresses.push(PresaleInfo(_title, _presale, _description, _type));
        isPresale[_presale] = true;
        //uint256 _id = presaleAddresses.length - 1;
        //forAllPoolsSearch[_id] = PresaleInfo(_title, _presale, _description, _type);
        return presaleAddresses.length - 1;
    }

    function getPresalesCount() external view returns (uint256) {
        return presaleAddresses.length;
    }

    function getPresaleAddress(uint256 id) external view returns (address) {
        return presaleAddresses[id].presaleAddress;
    }

    /*function setPresaleAddress(uint256 id, address _newAddress)
        external
        onlyDev
    {
        presaleAddresses[id].presaleAddress = _newAddress;
    }*/

    function changeDev(address _newDev) external onlyDev {
        require(_newDev != address(0), "Wrong new address");
        devAddress = _newDev;
    }

    function setVotingTime(uint256 _newVotingTime) external onlyDev {
        require(_newVotingTime > 0, "Wrong new time");
        votingTime = _newVotingTime;
    }

    /*function setStakingAddress(address _staking) external onlyDev {
        require(_staking != address(0));
        safeStakingPool = IStaking(_staking);
    }*/

    function getVotingTime() public view returns(uint256){
        return votingTime;
    }

    function getMinInvestorBalance() external view returns (uint256) {
        return minInvestorBalance;
    }

    function getMinUnstakeTime() external view returns (uint256) {
        return minUnstakeTime;
    }

    function getDev() external view onlyFactory returns (address) {
        return devAddress;
    }

    function getMinVoterBalance() external view returns (uint256) {
        return minVoterBalance;
    }
    //back!!!
    function getMinYesVotesThreshold(uint256 totalStakedAmount) external pure returns (uint256) {
        uint256 stakedAmount = totalStakedAmount;
        return stakedAmount / 10;
    }

    function getFactoryAddress() external view returns (address) {
        return factoryAddress;
    }

    function getMinCreatorStakedBalance() external view returns (uint256) {
        return minCreatorStakedBalance;
    }

    /*function getStakedSafeBalance(address sender)
        public
        view
        returns (uint256)
    {
        uint256 balance;
        uint256 lastStakedTimestamp;
        (balance, lastStakedTimestamp, ) = safeStakingPool.getStakedInfo(sender);

        if (lastStakedTimestamp + minStakeTime <= block.timestamp) {
            return balance;
        }
        return 0;
    }*/

    function getUniswapRouter() external view returns (address) {
        return uniswapRouter;
    }

    function setUniswapRouter(address _uniswapRouter) external onlyDev {
        uniswapRouter = _uniswapRouter;
    }

    function calculateFee(uint256 amount) external view onlyPresale returns(uint256){
        return amount * feePercent / 100;
    }

    function getVaultAddress() external view onlyPresale returns(address payable){
        return lessVault;
    }

    function getArrForSearch() external view returns(PresaleInfo[] memory) {
        return presaleAddresses;
    }
    
    function _verifySigner(bytes memory data, bytes memory signature)
        public
        view
        returns (bool)
    {
        IPresaleFactory presaleFactory = IPresaleFactory(payable(factoryAddress));
        address messageSigner =
            ECDSA.recover(keccak256(data), signature);
        require(
            presaleFactory.isSigner(messageSigner),
            "Unauthorised signer"
        );
        return true;
    }

    function setSingUsed(bytes memory _sign, address _presale) external {
        require(isPresale[_presale], "u have no permition");
        usedSignature[keccak256(_sign)] = true;
    }

    function getSignUsed(bytes memory _sign) external view returns(bool) {
        return usedSignature[keccak256(_sign)];
    }
}