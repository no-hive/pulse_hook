// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

contract CreateDynamicPoolScript is Script {
    using PoolIdLibrary for PoolKey;
    IPoolManager constant POOL_MANAGER =
        IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);

    address constant HOOK =
        0x4a1f3a3e99417A6aB309a3aAD639f23521c9D0C0;

    address constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {
        // USDC < WETH
        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(HOOK)
        });

        // Initial price: 1 WETH ~= 3000 USDC.
        // sqrtPriceX96 = sqrt(3000 * 1e6 / 1e18) * 2^96
        uint160 sqrtPriceX96 = 4339505179874779489676287024;

        vm.startBroadcast();

        console2.log("Initializing pool...");
        console2.log("PoolManager:", address(POOL_MANAGER));
        console2.log("Hook:", HOOK);
        console2.log("USDC:", USDC);
        console2.log("WETH:", WETH);
        console2.log("Dynamic fee:", uint256(key.fee));
        console2.log("Tick spacing:", key.tickSpacing);

      int24 tick = POOL_MANAGER.initialize(key, sqrtPriceX96);
bytes32 poolId = PoolId.unwrap(key.toId());

        vm.stopBroadcast();

        console2.log("================================");
        console2.log("POOL CREATED");
        console2.log("PoolId:");
        console2.logBytes32(poolId);
        console2.log("================================");
    }
}