// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Token} from "./ERC20Token.sol";
import {FundraisingLaunchpad} from "./FundraisingLaunchpad.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title LaunchpadFactory
 * @author Aayush Gupta
 * @notice Upgradeable factory contract (using UUPS) that allows users to launch their own fundraising launchpads.
 * The factory deploys a new token (ERC20Token) and a new fundraising campaign (FundraisingLaunchpad)
 * with custom parameters provided by the launchpad creator.
 */
contract LaunchpadFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                 ARRAY
    //////////////////////////////////////////////////////////////*/
    /// @notice Array of deployed launchpad contract addresses.
    address[] private tokenLaunchpad;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a new launchpad is created.
    event LaunchpadCreated(address indexed launchpad, address indexed token, address indexed creator);

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                               EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new fundraising launchpad with custom parameters.
     * @param _tokenName The name of the new token.
     * @param _tokenSymbol The symbol of the new token.
     * @param _usdc Address of the USDC token (6 decimals).
     * @param _uniswapRouter Address of the Uniswap V2 router.
     * @param _creator Address of the launchpad creator.
     * @param _fundingGoal Amount of USDC to be raised to consider the launchpad successful (6 decimals).
     * @param _initialSupply Total token supply (18 decimals).
     * @param _tokensForSale The number of tokens available for sale (18 decimals).
     * @param _creatorReward The token amount rewarded to the launchpad creator (18 decimals).
     * @param _liquidityTokens The token amount to be paired with USDC for liquidity (18 decimals).
     * @param _platformfees The token amount reserved as a platform fee (18 decimals).
     * @param _basePrice Base price per token in USDC (6 decimals).
     * @return launchpadAddr The address of the newly deployed launchpad contract.
     */
    function createLaunchpad(
        string memory _tokenName,
        string memory _tokenSymbol,
        address _usdc,
        address _uniswapRouter,
        address _creator,
        uint256 _fundingGoal,
        uint256 _initialSupply,
        uint256 _tokensForSale,
        uint256 _creatorReward,
        uint256 _liquidityTokens,
        uint256 _platformfees,
        uint256 _basePrice
    ) external returns (address launchpadAddr) {
        // Deploy a new ERC20Token contract.
        ERC20Token token = new ERC20Token(_creator, _tokenName, _tokenSymbol, _initialSupply);

        // Deploy a new FundraisingLaunchpad upgradeable contract.
        FundraisingLaunchpad launchpad = new FundraisingLaunchpad();

        // Create a configuration struct with all the required parameters.
        FundraisingLaunchpad.LaunchpadConfig memory config = FundraisingLaunchpad.LaunchpadConfig({
            token: address(token),
            usdc: _usdc,
            uniswapRouter: _uniswapRouter,
            creator: _creator,
            fundingGoal: _fundingGoal,
            tokensForSale: _tokensForSale,
            creatorReward: _creatorReward,
            liquidityAmount: _liquidityTokens,
            platformfees: _platformfees,
            basePrice: _basePrice
        });

        // Initialize the launchpad contract with the provided configuration.
        launchpad.initialize(config);

        tokenLaunchpad.push(address(launchpad));
        emit LaunchpadCreated(address(launchpad), address(token), msg.sender);
        return address(launchpad);
    }

    /*//////////////////////////////////////////////////////////////
                               PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the factory with USDC and Uniswap router addresses.
     * @param _owner Address of the owner.
     */
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts upgrades to the owner.
     * @param _newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                               VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the list of all launchpad addresses.
     * @return tokenLaunchpad Array of deployed launchpad contract addresses.
     */
    function getLaunchpads() external view returns (address[] memory) {
        return tokenLaunchpad;
    }
}
