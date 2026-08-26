<img width="1832" height="500" alt="Frame 45(15)" src="https://github.com/user-attachments/assets/1b99a4e2-2478-4091-b26a-f6b02298e1c9" />

![Uniswap_v4_hook](https://img.shields.io/badge/Uniswap_Hook_Incubator-FF007A?style=flat)
![License](https://img.shields.io/github/license/no-hive/pulse_hook?style=flat&color=purple)
![First Commit](https://img.shields.io/badge/1st_commit-29_july-blue?style=flat)
![Last Commit](https://img.shields.io/github/last-commit/no-hive/pulse_hook?style=flat&color=blue)
![Commit Count](https://img.shields.io/github/commit-activity/t/no-hive/pulse_hook?style=flat&color=blue)
![Tests](https://github.com/no-hive/pulse_hook/actions/workflows/tests.yml/badge.svg)
![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/no-hive/pulse_hook/gh-pages/coverage.json?style=flat&color=32CB55)

#### Time-weighted priority-fee median to increase fees for abnormal MEV-patterned swaps.

#### 🧬 _No external off-chain modules or oracles. Runs entirely on-chain._

#### [DOCUMENTATION]() - _find more structured hook info here_ / [LLMs]() - _discuss the hook with your favorite ai agent_

## What is Pulse Hook

Pulse Hook is a Uniswap v4 Hook designed to reduce MEV, especially sandwich attacks, in low-liquidity pools such as newly launched and creator-token markets.

### The challenge

Low-liquidity pools are especially vulnerable to MEV bots. Attackers can use high priority fees to get their transactions included ahead of regular users, execute sandwich attacks, and extract value from traders and liquidity providers.

The challenge is to make this behavior less profitable while keeping the solution fully on-chain, gas-efficient, and independent of external infrastructure.

### The solution

Pulse Hook tracks the priority fees paid by swaps and maintains a shared reference level for the chain.

When a swap's priority fee is significantly higher than the typical level, the Hook applies an additional trading fee. This makes aggressive fee-bidding more expensive and can reduce the profitability of MEV strategies.

At the same time, the reference level adapts to network-wide demand. When priority fees rise across the entire network, the reference level rises as well, so normal users are not unnecessarily penalized during periods of high network activity.

## How does it work?

Pulse Hook has two main parts:

Dynamic fee — compares each swap's priority fee with the current reference level.
Shared measurement — provides that reference level using the average of the last 15 block-level snapshots of the running median.

A normal swap pays the standard 0.1% fee. A swap with an unusually high priority fee pays an additional penalty based on the Hook's penalty curve.

