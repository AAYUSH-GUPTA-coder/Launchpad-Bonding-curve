// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {LaunchpadFactory} from "../src/LaunchpadFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployLaunchpadFactory is Script {
    address walletAddress = vm.envAddress("WALLET_ADDRESS");

    function run() external returns (address) {
        address proxy = deployFactory();
        return proxy;
    }

    function deployFactory() public returns (address) {
        vm.startBroadcast();
        LaunchpadFactory factory = new LaunchpadFactory();
        ERC1967Proxy proxy = new ERC1967Proxy(address(factory), "");
        LaunchpadFactory(address(proxy)).initialize(walletAddress);
        vm.stopBroadcast();
        return address(proxy);
    }
}

// forge script script/DeployLaunchpadFactory.s.sol:DeployLaunchpadFactory --account defaultKey --sender $WALLET_ADDRESS --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ARBSCAN_API_KEY -vvv
