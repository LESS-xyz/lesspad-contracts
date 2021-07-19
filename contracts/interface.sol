// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (
        uint amountA, 
        uint amountB, 
        uint liquidity
    );

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (
        uint amountToken, 
        uint amountETH, 
        uint liquidity
    );

    function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);

    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IUniswapV2Factory02 {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

interface IUniswapV2Pair {
    event Transfer(address indexed from, address indexed to, uint value);

    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function approve(address guy, uint wad) external returns (bool);
}

interface IPresaleFactory {
    function isSigner(address _address) external view returns (bool);
}
