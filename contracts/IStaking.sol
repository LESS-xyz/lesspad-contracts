// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    function getStakedInfo(address _sender) external view returns(uint256, uint256, uint256);
    function getOverallBalanceInLess() external view returns(uint256);
}
