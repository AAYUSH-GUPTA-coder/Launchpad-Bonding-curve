// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract DeployERC20 is Script {
    address owner = vm.envAddress("WALLET_ADDRESS");

    function run() external returns (address) {
        vm.startBroadcast();
        ERC20Token token = new ERC20Token(owner, "RAGA", "RG", 1_000_000_000 ether);
        vm.stopBroadcast();

        console.log("Token deployed at:", address(token));
        return address(token);
    }
}

// forge script script/DeployERC20.s.sol:DeployERC20 --account defaultKey --sender $WALLET_ADDRESS --rpc-url $ARB_SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ARBSCAN_API_KEY -vvv
