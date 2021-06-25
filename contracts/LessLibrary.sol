// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IStaking.sol";

contract LessLibrary is Ownable {
    PresaleInfo[] private presaleAddresses; // track all presales created

    uint256 private minInvestorBalance = 15000 * 1e18;
    uint256 private votingTime = 3 days; //tthree days
    //uint256 private votingTime = 300;
    uint256 private minStakeTime = 1 days; //one day
    uint256 private minUnstakeTime = 6 days; //six days

    address private factoryAddress;

    uint256 private minVoterBalance = 500 * 1e18; // minimum number of  tokens to hold to vote
    uint256 private minCreatorStakedBalance = 8000 * 1e18; // minimum number of tokens to hold to launch rocket

    uint8 private feePercent = 2;
    uint32 private usdtFee = 1 * 1e6;

    address private uniswapRouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // uniswapV2 Router
    address private tether = address(0x110a13FC3efE6A245B50102D2d79B3E76125Ae83);

    address payable private lessVault;
    address private devAddress;
    IStaking public safeStakingPool;

    mapping(address => bool) private isPresale;

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

    constructor(address _dev, address payable _vault) {
        require(_dev != address(0));
        require(_vault != address(0));
        devAddress = _dev;
        lessVault = _vault;
    }

    function setFactoryAddress(address _factory) external onlyDev {
        require(_factory != address(0));
        factoryAddress = _factory;
    }

    function setUsdtFee(uint32 _newAmount) external onlyDev {
        require(_newAmount > 0, "Wrong parameter");
        usdtFee = _newAmount;
    }

    function getUsdtFee() external view onlyFactory returns(uint256, address) {
        return (usdtFee, tether);
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

    function setPresaleAddress(uint256 id, address _newAddress)
        external
        onlyDev
    {
        presaleAddresses[id].presaleAddress = _newAddress;
    }

    function changeDev(address _newDev) external onlyDev {
        require(_newDev != address(0), "Wrong new address");
        devAddress = _newDev;
    }

    function setVotingTime(uint256 _newVotingTime) external onlyDev {
        require(_newVotingTime > 0, "Wrong new time");
        votingTime = _newVotingTime;
    }

    function setStakingAddress(address _staking) external onlyDev {
        require(_staking != address(0));
        safeStakingPool = IStaking(_staking);
    }

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

    function getMinYesVotesThreshold() external view returns (uint256) {
        uint256 stakedAmount = safeStakingPool.getStakedAmount();
        return stakedAmount / 10;
    }

    function getFactoryAddress() external view returns (address) {
        return factoryAddress;
    }

    function getMinCreatorStakedBalance() external view returns (uint256) {
        return minCreatorStakedBalance;
    }

    function getStakedSafeBalance(address sender)
        public
        view
        returns (uint256)
    {
        uint256 balance;
        uint256 lastStakedTimestamp;
        (balance, lastStakedTimestamp, ) = safeStakingPool.getAccountInfo(
            address(sender)
        );

        if (lastStakedTimestamp + minStakeTime <= block.timestamp) {
            return balance;
        }
        return 0;
    }

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
}