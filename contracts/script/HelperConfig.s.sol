// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// If we are on a local Anvil, we use the mock config
// Else, grab the existing address for the live network
library HelperConfig {
    // CHAIN IDs
    uint256 internal constant ETHEREUM_MAINNET_CHAIN_ID = 1;
    uint256 internal constant UNICHAIN_MAINNET_CHAIN_ID = 130;
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 internal constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant ROBINHOOD_CHAIN_ID = 4663;
    uint256 internal constant ARBITRUM_ONE_CHAIN_ID = 42161;

    // The list of tokens to pass to the constructor
    // to use as tokens the pool can trust while being
    // updated. Protects the contract from dust attacks.
    struct NetworkConfig {
        address poolManager; // network-specific Pool Manager contract
        address[] soundTokens;
    }

    // No constructor and no state — the network is resolved fresh
    // on every call from block.chainid.
    function getDeploymentConfig() internal view returns (NetworkConfig memory) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (block.chainid == ETHEREUM_MAINNET_CHAIN_ID) {
            return getEthereumMainnetConfig();
        } else if (block.chainid == UNICHAIN_MAINNET_CHAIN_ID) {
            return getUnichainConfig();
        } else if (block.chainid == BASE_MAINNET_CHAIN_ID) {
            return getBaseConfig();
        } else if (block.chainid == BASE_SEPOLIA_CHAIN_ID) {
            return getBaseSepoliaConfig();
        } else if (block.chainid == ROBINHOOD_CHAIN_ID) {
            return getRobinhoodConfig();
        } else if (block.chainid == ARBITRUM_ONE_CHAIN_ID) {
            return getArbitrumConfig();
        } else {
            return getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](4);
        soundTokens[0] = address(0); // Native Sepolia ETH
        soundTokens[1] = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // WETH
        soundTokens[2] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // UNI
        soundTokens[3] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC

        return NetworkConfig({poolManager: 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543, soundTokens: soundTokens});
    }

    function getEthereumMainnetConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](6);
        soundTokens[0] = address(0); // Native ETH
        soundTokens[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        soundTokens[2] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
        soundTokens[3] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // UNI
        soundTokens[4] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        soundTokens[5] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT

        return NetworkConfig({poolManager: 0x000000000004444c5dc75cB358380D2e3dE08A90, soundTokens: soundTokens});
    }

    function getUnichainConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](5);
        soundTokens[0] = address(0); // Native ETH
        soundTokens[1] = 0x4200000000000000000000000000000000000006; // WETH
        soundTokens[2] = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
        soundTokens[3] = 0x8f187aA05619a017077f5308904739877ce9eA21;
        soundTokens[4] = 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
        // If you need USDT0 as a 6th token, uncomment and size the array to 6:
        // soundTokens[5] = 0x9151434b16b9763660705744891fA906F660EcC5; // USDT0

        return NetworkConfig({poolManager: 0x1F98400000000000000000000000000000000004, soundTokens: soundTokens});
    }

    function getBaseConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](3);
        soundTokens[0] = address(0); // Native ETH
        soundTokens[1] = 0x4200000000000000000000000000000000000006; // WETH
        soundTokens[2] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC

        return NetworkConfig({
            poolManager: 0x498581fF718922c3f8e6A244956aF099B2652b2b,
            soundTokens: soundTokens
        });
    }

    function getBaseSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](3);
        soundTokens[0] = address(0); // Native Sepolia ETH on Base Sepolia
        soundTokens[1] = 0x4200000000000000000000000000000000000006; // WETH
        soundTokens[2] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Testnet USDC

        return NetworkConfig({
            poolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408,
            soundTokens: soundTokens
        });
    }

    function getRobinhoodConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](3);
        soundTokens[0] = address(0); // Native ETH
        soundTokens[1] = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73; // WETH
        soundTokens[2] = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168; // USDG

        return NetworkConfig({
            poolManager: 0x8366a39CC670B4001A1121B8F6A443A643e40951,
            soundTokens: soundTokens
        });
    }

    function getArbitrumConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](6);
        soundTokens[0] = address(0); // Native ETH
        soundTokens[1] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
        soundTokens[2] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC
        soundTokens[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
        soundTokens[4] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT
        soundTokens[5] = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB

        return NetworkConfig({
            poolManager: 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32,
            soundTokens: soundTokens
        });
    }

    function getAnvilEthConfig() internal pure returns (NetworkConfig memory) {
        address[] memory soundTokens = new address[](1);
        soundTokens[0] = address(0);

        return NetworkConfig({poolManager: address(0), soundTokens: soundTokens});
    }
}
