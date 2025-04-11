// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Interface for the Uniswap V2 Factory contract
interface IUniswapV2Factory {
    /// @notice Creates a pair for tokenA and tokenB if it doesn't exist yet.
    /// @param tokenA The address of the first token.
    /// @param tokenB The address of the second token.
    /// @return pair The address of the new pair (pool) contract.
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
