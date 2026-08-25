// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {BaseScript} from "./base/BaseScript.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {PulseHook} from "../src/PulseHook.sol";

/// @notice Mines the address and deploys the PulseHook.sol Hook contract
contract DeployHookScript is BaseScript {
    function run() public {
        console2.log("=====================================================");
        console2.log("  DeployHookScript: starting PulseHook deployment");
        console2.log("=====================================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", msg.sender);

        HelperConfig.NetworkConfig memory deploymentConfig = HelperConfig.getDeploymentConfig();

        require(
            deploymentConfig.poolManager != address(0), "DeployHookScript: PoolManager not configured for this chain"
        );

        address[] memory listedTokens = deploymentConfig.soundTokens;

        console2.log("-----------------------------------------------------");
        console2.log("PoolManager (from config):", deploymentConfig.poolManager);
        console2.log("Listed tokens count:", listedTokens.length);
        for (uint256 i = 0; i < listedTokens.length; i++) {
            console2.log("  Token", i, listedTokens[i]);
        }

        // hook contracts must have specific flags encoded in the address
        // TODO: confirm this matches PulseHook.getHookPermissions() exactly — was previously
        // BEFORE_SWAP_FLAG duplicated (a no-op), which silently dropped AFTER_SWAP from the mask.
        uint160 flags = uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        console2.log("-----------------------------------------------------");
        console2.log("Hook flags (uint160):", flags);

        // Mine a salt that will produce a hook address with the correct flags
        IPoolManager poolManager = IPoolManager(deploymentConfig.poolManager);
        bytes memory constructorArgs = abi.encode(poolManager, listedTokens);

        console2.log("Mining salt via HookMiner...");
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(PulseHook).creationCode, constructorArgs);

        console2.log("Mined hook address: ", hookAddress);
        console2.log("Mined salt:");
        console2.logBytes32(salt);

        // Deploy the hook using CREATE2
        console2.log("-----------------------------------------------------");
        console2.log("Broadcasting deployment transaction...");
        vm.startBroadcast();
        PulseHook pulseHook = new PulseHook{salt: salt}(poolManager, listedTokens);
        vm.stopBroadcast();

        require(address(pulseHook) == hookAddress, "DeployHookScript: Hook Address Mismatch");

        console2.log("=====================================================");
        console2.log("  Deployment successful");
        console2.log("=====================================================");
        console2.log("PulseHook deployed at:", address(pulseHook));
        console2.log("PoolManager used:", address(poolManager));
        console2.log("Salt used:");
        console2.logBytes32(salt);
        console2.log("=====================================================");
    }
}
