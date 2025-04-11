// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ERC20Token
 * @author Aayush Gupta
 * @notice ERC20 token contract that created ERC20 Token and mint initial supply.
 */
contract ERC20Token is ERC20 {
    /**
     * @notice Constructor that mints the entire token supply to the owner.
     * @param _owner The address that will receive the token supply.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _initialSupply The initial supply of the token.
     */
    constructor(address _owner, string memory _name, string memory _symbol, uint256 _initialSupply)
        ERC20(_name, _symbol)
    {
        // Mint _initialSupply amount of tokens (scaled by 1e18 for decimals)
        _mint(_owner, _initialSupply * 1e18);
    }
}
