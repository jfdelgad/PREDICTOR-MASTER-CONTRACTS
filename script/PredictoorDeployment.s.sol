// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/forge-std/src/Script.sol";
import {Predictoor} from "../src/Predictoor.sol";
import {PredictoorMaster} from "../src/PredictoorMaster.sol";

contract PredictoorDeployment is Script {
    // address constant oceanTokenAddr = 0x973e69303259B0c2543a38665122b773D28405fB; //testnet
    address constant oceanTokenAddr = 0x39d22B78A7651A76Ffbde2aaAB5FD92666Aca520; //mainnet

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Predictoor predTemplate = new Predictoor();
        console.log("Template at:", address(predTemplate));

        PredictoorMaster master = new PredictoorMaster(address(predTemplate), oceanTokenAddr);
        console.log("Master at:", address(master));
        vm.stopBroadcast();
    }
}

// forge script script/PredictoorDeployment.s.sol:PredictoorDeployment --rpc-url $OASIS_SAPPHIRE_TESTNET_RPC_URL --broadcast -vvvv
