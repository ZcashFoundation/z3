# Project Brief

## Overview
Z3: Building a modern, secure, reliable, scalable software stack that will replace [Zcashd](https://github.com/zcash/zcash).

## Core Features
- A full-node implementation that implements the Zcash protocol (Zebra)
- A service that provides indexing and serves light clients blockchain data (Zaino) 
- A cli-wallet that provides wallet functionality that existed in Zcashd but that is not planned for implementation in Zebra (Zallet)
- A wrapper service that exposes the three previously mentioned services as a "single binary" to the users

## Target Users
- Developers of the Zcash protocol (including the Zcash Foundation, the Electric Coin Company, Shielded Labs, Zingo Labs and the broader community)
- Operators of centralized cryptocurrency exchanges (including Coinbase, Gemini, Kraken, Binance, etc.)
- Operators of decentralized cryptocurrency exchanges (including the Zcash DEX implemented with Near Intents)
- Operators of cryptocurrency wallet software platforms (including Zashi, Brave Wallet, etc.)
- Operators of ASIC based proof of work miners on the Zcash blockchain
- Operators of "finalizers" (known more commonly as validators) as Zcash prepares to transition to a hybrid Proof of Work / Proof of Stake consensus algorithm.
- Operators of block explorers on the Zcash network. We can leverage the [open source Nighthawk explorer](https://github.com/nighthawk-apps/zcash-explorer) (which is unfortunately no longer maintained) as a proof of concept application consuming the Z3 stack while it's under development. There is [work already underway](https://github.com/ZcashFoundation/zebra/issues/8435) to get this explorer working with Zebra.

## Technical Preferences
- [Zcashd](https://github.com/zcash/zcash) is the legacy software that is being replaced
- [Zebra](https://github.com/ZcashFoundation/zebra) for the Zcash full node 
- [Zaino](https://github.com/zingolabs/zaino/) for the indexing service that will interface with Zebrad via RPC and the ReadStateService, and also replace the legacy go light client server [lightwalletd](https://github.com/zcash/lightwalletd)
- [Zallet](https://github.com/zcash/wallet) for the cli-wallet that will replace the wallet functionality that originally existed in Zcashd
- The Z3 wrapper software that is the primary software deliverable of this project should be written in Rust, unless there is a *really* good reason to use another language or framework.
- Security is of paramount importance
- Clippy as the Rust linter of choice
- Git and Github for SCM
- Github Actions for CI
- Test driven development
- Docker for deployment
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) as standard for SCM commit messaging

## Further Reading

For a detailed analysis of the problems we're solving and proposed solution, see the [Product Context](productContext.md).
