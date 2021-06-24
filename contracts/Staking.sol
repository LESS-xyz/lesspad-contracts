// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./LessLibrary.sol";

contract Staking is ReentrancyGuard {
    using Address for address;

    IERC20 public safeToken;
    LessLibrary public safeLibrary;
    uint256 private totalStakedAmount;

    event Staked(address indexed from, uint256 amount);
    event Unstaked(address indexed from, uint256 amount);

    struct AccountInfo {
        uint256 balance;
        uint256 lastStakedTimestamp;
        uint256 lastUnstakedTimestamp;
    }
    mapping(address => AccountInfo) public accountInfos;
    modifier onlyDev() {
        require(
            msg.sender == safeLibrary.getFactoryAddress() ||
                msg.sender == safeLibrary.owner() ||
                msg.sender == safeLibrary.getDev(),
            "Only Dev"
        );
        _;
    }

    constructor(address _safeToken, address _safeLibrary) {
        safeToken = IERC20(_safeToken);
        safeLibrary = LessLibrary(_safeLibrary);
    }

    function stake(uint256 _amount) public nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(safeToken.balanceOf(msg.sender) >= _amount, "Invalid balance");

        AccountInfo storage account = accountInfos[msg.sender];
        safeToken.transferFrom(msg.sender, address(this), _amount);
        account.balance = account.balance + _amount;
        totalStakedAmount += _amount;

        if (account.lastUnstakedTimestamp == 0) {
            account.lastUnstakedTimestamp = block.timestamp;
        }
        account.lastStakedTimestamp = block.timestamp;
        emit Staked(msg.sender, _amount);
    }

    function unstake(uint256 _amount) external nonReentrant {
        AccountInfo storage account = accountInfos[msg.sender];
        uint256 minUnstakeTime = safeLibrary.getMinUnstakeTime();

        require(
            !address(msg.sender).isContract(),
            "Please use your individual account"
        );

        require(account.balance > 0, "Nothing to unstake");
        require(_amount > 0, "Invalid amount");
        require(
            minUnstakeTime == 0 ||
                (account.lastUnstakedTimestamp + minUnstakeTime <=
                    block.timestamp),
            "Invalid Unstake Time"
        );
        if (account.balance < _amount) {
            _amount = account.balance;
        }
        account.balance = account.balance - _amount;
        totalStakedAmount -= _amount;
        account.lastUnstakedTimestamp = block.timestamp;

        if (account.balance == 0) {
            account.lastStakedTimestamp = 0;
            account.lastUnstakedTimestamp = 0;
        }
        safeToken.transfer(msg.sender, _amount);
        emit Unstaked(msg.sender, _amount);
    }

    function setLibraryAddress(address _newInfo) external onlyDev {
        safeLibrary = LessLibrary(_newInfo);
    }

    function getStakedAmount() external view returns(uint256) {
        return totalStakedAmount;
    }

    function getAccountInfo(address staker) external view returns (uint256, uint256, uint256) {
        AccountInfo storage account = accountInfos[staker];
        return (account.balance, account.lastStakedTimestamp, account.lastUnstakedTimestamp);
    }
}