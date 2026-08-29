<img width="1832" height="500" alt="Frame 45(15)" src="https://github.com/user-attachments/assets/1b99a4e2-2478-4091-b26a-f6b02298e1c9" />

![Uniswap_v4_hook](https://img.shields.io/badge/Uniswap_Hook_Incubator-FF007A?style=flat)
![License](https://img.shields.io/github/license/no-hive/pulse_hook?style=flat&color=purple)
![First Commit](https://img.shields.io/badge/1st_commit-29_july-blue?style=flat)
![Last Commit](https://img.shields.io/github/last-commit/no-hive/pulse_hook?style=flat&color=blue)
![Commit Count](https://img.shields.io/github/commit-activity/t/no-hive/pulse_hook?style=flat&color=blue)
![Tests](https://github.com/no-hive/pulse_hook/actions/workflows/tests.yml/badge.svg)
![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/no-hive/pulse_hook/gh-pages/coverage.json?style=flat&color=32CB55)

## Pulse Hook

This hook is build to solve MEV problem for pools with low liquidity - perfect ready-to-use solution for creator coins pools, niche memecoins or launchpads. It uses a priority fee median to track unusual behavior and make MEV-patterned swaps less profitable.

🧬 _No external off-chain modules or oracles. Runs entirely on-chain._

> _inspired by [Uniswap v4 Truncated Oracle Hook](https://blog.uniswap.org/uniswap-v4-truncated-oracle-hook) and [median-oracles by saucepoint](https://github.com/saucepoint/median-oracles)_


## What Pulse Hook does

1. __Reads the priority fee__ - Checks the extra fee paid for faster inclusion..
2. __Compares to the norm__ - Measures it against the recent typical level.
3. __Normal swaps pay 0.1%__ - No extra fee when bidding is near the norm.
4. __Aggressive bids pay more__ - Higher-than-normal priority fees trigger a dynamic surcharge.
5. __Swap executes normally__ - The extra fee goes to the pool.
6. __Updates from meaningful swaps__ - Eligible trades can update the typical priority fee.
7. __Resists manipulation__ - Only eligible pools and meaningful price moves affect the shared reference.

---

## Explore the hook

#### 🔮 [DOCUMENTATION](https://pulse-hook.mintlify.site/introduction) - find much more structured hook info here.
#### 👾 [LLMs](https://github.com/no-hive/pulse_hook/blob/main/llms/README.md) - discuss the hook and its docs with your favorite ai agent.

--- 

## Build with the hook


#### 🍇 [INIT POOL](https://pulse-hook.mintlify.site/guides/init-pool) - find how to deploy a pool with a hook here.
#### ⚗️ [DELPOY HOOK](https://pulse-hook.mintlify.site/guides/deploy-hook) - see how to install the hook to check it, judge it, modify it, deploy it.


