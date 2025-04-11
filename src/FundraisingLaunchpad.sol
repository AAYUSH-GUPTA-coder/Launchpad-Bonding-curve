// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Import OpenZeppelin Upgradeable Contracts and utility libraries
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";

contract FundraisingLaunchpad is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /*//////////////////////////////////////////////////////////////
                                 ERROR
    //////////////////////////////////////////////////////////////*/
    error Launchpad__FundraisingFinalized();
    error Launchpad__ValueCannotBeZero();
    error Launchpad__SaleNotCompleted();
    error Launchpad__ExceedsTokensAvailableForSale();
    error Launchpad__OnlyCreator();

    /*//////////////////////////////////////////////////////////////
                          LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                          INTERFACES
    //////////////////////////////////////////////////////////////*/

    // External token interfaces
    IERC20 public token; // The fundraising token (18 decimals)
    IERC20 public usdc; // USDC token (6 decimals)

    // Uniswap router for liquidity addition.
    IUniswapV2Router public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;

    /*//////////////////////////////////////////////////////////////
                          STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    // Token Launchpad creator (will receive rewards on finalization)
    address private creator;

    // Distribution parameters (all token amounts are in 18-decimal units):
    uint256 private tokensForSale; // e.g. tokens available to be sold by the launchpad
    uint256 private creatorReward; // tokens sent to the launchpad creator upon finalization
    uint256 private liquidityAmount; // tokens paired with USDC to add liquidity to the liquidity pool in uniswap
    uint256 private platformfees; // tokens kept as a platform fee
    uint256 private fundingGoal; // minimum amount of USDC raised to consider the launchpad successful

    // Sale state variables
    uint256 private tokensSold; // Amount of token sold
    uint256 private usdcRaised; // accumulated USDC (6 decimals)
    bool private fundraisingFinalized;

    // basePrice: starting price per token (USDC, 6 decimals)
    uint256 private basePrice;
    // reserveRatio: ratio of tokens reserved for the launchpad
    uint256 private reserveRatio;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 cost);
    event FundraisingFinalized(
        uint256 totalUSDC, uint256 liquidityUSDC, uint256 liquidityAmount, uint256 liquidity, address pair
    );

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Modifier to check if a value is zero.
     * @param _amount The value to check.
     */
    modifier checkZero(uint256 _amount) {
        if (_amount == 0) revert Launchpad__ValueCannotBeZero();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to group initialization parameters.
    struct LaunchpadConfig {
        address token;
        address usdc;
        address uniswapRouter;
        address uniswapFactory;
        address creator;
        uint256 fundingGoal;
        uint256 tokensForSale;
        uint256 creatorReward;
        uint256 liquidityAmount;
        uint256 platformfees;
        uint256 basePrice;
    }

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
     * @notice Purchase tokens from the launchpad.
     * @param _amount Number of tokens to purchase (18 decimals).
     */
    function buyTokens(uint256 _amount) external nonReentrant checkZero(_amount) {
        if (fundraisingFinalized) revert Launchpad__FundraisingFinalized();
        if (tokensSold + _amount > tokensForSale) revert Launchpad__ExceedsTokensAvailableForSale();

        uint256 cost = calculateTokenPrice() * _amount;
        tokensSold += _amount;
        usdcRaised += cost;

        emit TokensPurchased(msg.sender, _amount, cost);

        // Receive USDC from buyer (USDC has 6 decimals)
        usdc.safeTransferFrom(msg.sender, address(this), cost);

        // Transfer purchased tokens to buyer
        token.safeTransfer(msg.sender, _amount);
    }

    /**
     * @notice Finalize the fundraising launchpad once the sale is complete.
     * @param _liquidityDeadline A timestamp by which the liquidity addition transaction must be executed.
     * uint deadline = block.timestamp + 600; // 10 minutes in the future
     */
    function finalizeFundraising(uint256 _liquidityDeadline) external nonReentrant {
        if (msg.sender != creator) revert Launchpad__OnlyCreator();
        if (fundraisingFinalized) revert Launchpad__FundraisingFinalized();
        if (tokensSold < tokensForSale) revert Launchpad__SaleNotCompleted();

        // Transfer creator reward tokens to the creator.
        token.safeTransfer(creator, creatorReward);

        // Split the USDC raised into two halves.
        uint256 halfUSDC = usdcRaised / 2;

        fundraisingFinalized = true;

        // Approve Uniswap router to spend the USDC and tokens for liquidity.
        usdc.approve(address(uniswapRouter), halfUSDC);
        token.approve(address(uniswapRouter), liquidityAmount);

        // Create the Uniswap Pair / Pool
        address pair = uniswapFactory.createPair(address(token), address(usdc));

        // Add liquidity on Uniswap.
        (uint256 amountToken, uint256 amountUSDC, uint256 liquidity) = uniswapRouter.addLiquidity(
            address(token), address(usdc), liquidityAmount, halfUSDC, 0, 0, creator, _liquidityDeadline
        );

        emit FundraisingFinalized(usdcRaised, amountUSDC, amountToken, liquidity, pair);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function initialize(LaunchpadConfig calldata config) public initializer {
        __Ownable_init(config.creator);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        token = IERC20(config.token);
        usdc = IERC20(config.usdc);
        uniswapRouter = IUniswapV2Router(config.uniswapRouter);
        uniswapFactory = IUniswapV2Factory(config.uniswapFactory);

        creator = config.creator;

        tokensForSale = config.tokensForSale;
        creatorReward = config.creatorReward;
        liquidityAmount = config.liquidityAmount;
        platformfees = config.platformfees;

        tokensSold = 0;
        usdcRaised = 0;
        basePrice = config.basePrice;
        fundingGoal = config.fundingGoal * 1e12; // convert to 18 decimals
        fundraisingFinalized = false;
    }

    /**
     * @notice Calculates the reserve ratio.
     * @return The reserve ratio.
     */
    function calculateReserveRatio() public returns (uint256) {
        uint256 basePrice18 = basePrice * 1e12;
        uint256 totalValueOfFundraiseToken = tokensForSale * basePrice18;
        reserveRatio = (fundingGoal * 1e18) / totalValueOfFundraiseToken;
        return reserveRatio;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice UUPS upgrade authorization.
     * @dev Only the contract owner can authorize an upgrade.
     * @param _newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                         VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the price of a launchpad token.
     * @return The price of a launchpad token.
     */
    function calculateTokenPrice() public view returns (uint256) {
        uint256 reserveTokenBalance = usdc.balanceOf(address(this));
        uint256 ContinuousTokenPrice = (reserveTokenBalance / (tokensForSale * reserveRatio));
        return ContinuousTokenPrice;
    }

    /**
     * @notice Calculates the number of tokens that can be purchased for a given amount of USDC.
     * @param _amountOfUsdc The amount of USDC to purchase.
     * @return The number of tokens that can be purchased.
     */
    function calculatePurchase(uint256 _amountOfUsdc) public view returns (uint256) {
        uint256 usdcAmount = _amountOfUsdc * 1e12;
        uint256 ReserveTokensReceived = usdcAmount;
        uint256 ReserveTokenBalance = usdc.balanceOf(address(this));

        return (tokensForSale * ((1 + ReserveTokensReceived / ReserveTokenBalance) ** reserveRatio - 1));
    }

    /**
     * @notice Get the remaining tokens to sell.
     * @return The remaining tokens to sell.
     */
    function getRemainingTokenToSell() public view returns (uint256) {
        return tokensForSale - tokensSold;
    }

    /**
     * @notice Get the tokens for sale.
     * @return The tokens for sale.
     */
    function getTokenForSale() public view returns (uint256) {
        return tokensForSale;
    }

    /**
     * @notice Get the raised amount.
     * @return The raised amount.
     */
    function getRaisedAmount() public view returns (uint256) {
        return usdcRaised;
    }

    /**
     * @notice Get the creator of the launchpad.
     * @return The creator of the launchpad.
     */
    function getCreator() public view returns (address) {
        return creator;
    }

    /**
     * @notice Get the amount to raise.
     * @return The amount to raise.
     */
    function getAmountToRaise() public view returns (uint256) {
        return fundingGoal;
    }

    /**
     * @notice Get the creator reward.
     * @return The creator reward.
     */
    function getCreatorReward() public view returns (uint256) {
        return creatorReward;
    }

    /**
     * @notice Get the liquidity amount.
     * @return The liquidity amount.
     */
    function getLiquidityAmount() public view returns (uint256) {
        return liquidityAmount;
    }

    /**
     * @notice Get the platform fees.
     * @return The platform fees.
     */
    function getPlatformFees() public view returns (uint256) {
        return platformfees;
    }

    /**
     * @notice Get the tokens sold.
     * @return The tokens sold.
     */
    function getTokensSold() public view returns (uint256) {
        return tokensSold;
    }

    /**
     * @notice Get the fundraising finalized status.
     * @return The fundraising finalized status.
     */
    function getFinalized() public view returns (bool) {
        return fundraisingFinalized;
    }

    /**
     * @notice Get the base price.
     * @return The base price.
     */
    function getBasePrice() public view returns (uint256) {
        return basePrice;
    }

    /**
     * @notice Get the reserve ratio.
     * @return The reserve ratio.
     */
    function getReserveRatio() public view returns (uint256) {
        return reserveRatio;
    }

    /// @notice Returns the version of the contract
    function version() public pure returns (uint256) {
        return 1;
    }
}
