# 🛰️ Pulse Hook — for AI agents

This folder holds one file: everything an AI needs to actually understand Pulse Hook, in one drop.

## What's in `llms-full.md`

A single, self-contained markdown file — built to be pasted whole into an LLM chat or fetched by an agentic tool. No hunting through docs pages, no re-explaining the project from scratch. It covers:

- 🧠 **What it is, and why** — the MEV problem, general Uniswap v4 / hooks background, the one-line pitch
- ⚙️ **The exact swap flow** — all three hook callbacks, step by step, matching the real code path
- 📐 **The math — and why it was chosen** — Frugal2U vs. P² for the median, `frac^1.5` vs. the curves that got rejected along the way (with the actual reasoning, not just formulas)
- 🗂️ **The full technical structure** — file trees, a contract walkthrough, storage layout, and the security-relevant stuff (no admin, no pause, no upgrade path)
- 🚀 **Deployment & usage guides** — init a pool against an existing deployment, or deploy your own copy, condensed into commands you can actually run
- 💬 **Ready-made prompts** — for implementing changes, reviewing scope, stress-testing parameter tweaks, onboarding a contributor

## Why this exists

A docs site is great for a human clicking around. It's slower and lossier for an AI mid-conversation. This file skips that — hand it over once, and the AI already knows the project cold.

## Use it

**Download [`llms-full.md`](./llms-full.md) and discuss Pulse Hook with your favorite AI.** Ask it to explain the penalty curve, review a diff, help you deploy to a new chain, or just poke holes in the design — it's all in there.

---

Prefer the human-readable version? → [Documentation](https://pulse-hook.mintlify.site/introduction)
