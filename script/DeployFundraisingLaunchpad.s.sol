// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {FundraisingLaunchpad} from "../src/FundraisingLaunchpad.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployFundraisingLaunchpad is Script {
    address walletAddress = vm.envAddress("WALLET_ADDRESS");

    address proxyFactory = 0xA07d460ea38fBf9aB2Afc99708898E6846675fB0;
    address usdc = vm.envAddress("ARB_USDC_ADDR");
    address arbFakeUniswapRouter = vm.envAddress("ETH_UNISWAPV2_ROUTER_ADDR");
    address arbFakeUniswapFactory = vm.envAddress("ETH_UNISWAPV2_FACTORY_ADDR");
    address creator = vm.envAddress("WALLET_ADDRESS");
    uint256 fundingGoal = 5_000_000 ether;
    uint256 initialSupply = 1_000_000_000 ether;
    uint256 tokensForSale = 500_000_000 ether;
    uint256 creatorReward = 200_000_000 ether;
    uint256 liquidityAmount = 250_000_000 ether;
    uint256 platformfees = 50_000_000 ether;
    uint256 basePrice = 0.01 * 1e6;
    address tokenAddress = 0xB43457E7aC1b45C64195476a8249325010323600;

    FundraisingLaunchpad.LaunchpadConfig public config = FundraisingLaunchpad.LaunchpadConfig({
        token: tokenAddress,
        usdc: usdc,
        uniswapRouter: arbFakeUniswapRouter,
        uniswapFactory: arbFakeUniswapFactory,
        creator: creator,
        fundingGoal: fundingGoal,
        tokensForSale: tokensForSale,
        creatorReward: creatorReward,
        liquidityAmount: liquidityAmount,
        platformfees: platformfees,
        basePrice: basePrice
    });

    function run() external returns (address) {
        address proxy = deployLaunchpad();
        return proxy;
    }

    function deployLaunchpad() public returns (address) {
        vm.startBroadcast();
        FundraisingLaunchpad launchpad = new FundraisingLaunchpad();
        ERC1967Proxy proxy = new ERC1967Proxy(address(launchpad), "");
        FundraisingLaunchpad(address(proxy)).initialize(config);

        vm.stopBroadcast();
        return address(proxy);
    }
}

// forge script script/DeployFundraisingLaunchpad.s.sol:DeployFundraisingLaunchpad --account defaultKey --sender $WALLET_ADDRESS --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ARBSCAN_API_KEY -vvv
