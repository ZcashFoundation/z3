# Tech Context

## Technologies Used

* **[Zcashd](https://github.com/zcash/zcash):** Is the legacy Zcash full-node client software being replaced by the Z3 stack
* **[Zebra](https://github.com/ZcashFoundation/zebra):** A full-node implementation of the Zcash protocol that provides consensus and network functionalities in Rust.  Zebra has been under development by the Zcash Foundation since 2020 and is presently deployed by a number of decentralized node operators on mainnet.
* **[Zaino](https://github.com/zingolabs/zaino/):** An indexing service that provides light clients with blockchain data, replacing the legacy go light client server lightwalletd. Zaino is under active development by Zingo Labs, funded by a grant from [ZCG](https://zcashcommunitygrants.org/).
* **[Zallet](https://github.com/zcash/wallet):** A CLI wallet that provides wallet functionality that existed in Zcashd but is not planned for implementation in Zebra.  Zallet is under active development by the Electric Coin Company.
* **Rust:** Primary language for Zebra, Zaino, and Zallet (version TBD). Justification: Security, performance, and memory safety.
* **gRPC:** In consideration for communication between Zebra and Zaino (version TBD). Justification: Efficient and standardized RPC framework.
* **Docker:** For deployment and containerization (version TBD). Justification: Consistent and reproducible environments.

## Development Setup

* **Rust toolchain:** Requires a recent version of the Rust toolchain, including `rustc`, `cargo`, and `clippy`.
* **Docker:** Requires Docker for building and running the services.
* **Git:** Requires Git for version control.
* **Editor:** VSCode with Rust Analyzer extension recommended.

## Technical Constraints

* **Performance:** The system must be able to handle high transaction volumes and provide low-latency access to blockchain data.
* **Security:** Security is paramount, and all components must be designed to resist attacks.
* **Compatibility:** The system must be compatible with the Zcash protocol and network.

## RPC Methods used by Customers

The Zcashd Deprecation team engaged with customers and found that they are using the following RPC methods in production. They discussed and came to agreement on which component in the new Z3 stack should service each of these methods.

| RPC Method                    | Where in new stack                 | Actions                                               |
| ----------------------------- | ---------------------------------- | ----------------------------------------------------- |
| `getaddressbalance`           | Zebra (lightwalletd usage) / Zaino | Review implementation in Zebra                        |
| `getaddressdeltas`            | Zaino                              |                                                       |
| `getaddressmempool`           | -                                  | Lower priority. Possibly deprecate                    |
| `getaddresstxids`             | Zebra (lightwalletd usage) / Zaino | Review implementation in Zebra \| Implement in Zaino  |
| `getaddressutxos`             | Zebra                              | Review implementation in Zebra                        |
| `getbestblockhash`            | Zebra / Zaino                      |                                                       |
| `getblock`                    | Zebra / Zaino                      | Being fully implemented in Zebra                      |
| `getblockchaininfo`           | Zebra / Zaino                      | Review implementation in Zebra                        |
| `getblockcount`               | Zebra / Zaino                      |                                                       |
| `getblockdeltas`              | Zaino                              | Implement in Zaino                                    |
| `getblockhash`                | Zebra / Zaino                      |                                                       |
| `getblockhashes`              | Zaino                              | Lower priority. Possibly deprecate                    |
| `getblockheader`              | Zebra / Zaino                      |                                                       |
| `getchaintips`                | Zaino                              | Implement in Zaino                                    |
| `getdifficulty`               | Zebra / Zaino                      |                                                       |
| `getmempoolinfo`              | Zaino                              | Implement in Zaino                                    |
| `getrawmempool`               | Zebra / Zaino                      |                                                       |
| `getspentinfo`                | Zaino                              | Implement in Zaino                                    |
| `gettxout`                    | Zaino                              | Implement in Zaino                                    |
| `gettxoutproof`               | Zaino                              | Lower priority                                        |
| `gettxoutsetinfo`             | Zaino                              |                                                       |
| `verifychain`                 | -                                  | Deprecate                                             |
| `verifytxoutproof`            | Zaino                              | Lower priority                                        |
| `z_gettreestate`              | Zebra / Zaino                      | Review implementation in Zebra                        |
| `getexperimentalfeatures`     | -                                  | Deprecate? Confirm what Zebra defines as experimental |
| `getinfo`                     | Zebra                              | Review implementation in Zebra                        |
| `getmemoryinfo`               | Zebra                              | No plan to implement                                  |
| `help`                        | Zebra                              | No plans to implement                                 |
| `setlogfilter`                | Zebra                              | No plans to implement                                 |
| `stop`                        | Zebra                              | None                                                  |
| `z_getpaymentdisclosure`      | -                                  | Deprecate                                             |
| `z_validatepaymentdisclosure` | -                                  | Deprecate                                             |
| `generate`                    | Zebra                              | None                                                  |
| `getgenerate`                 | Zebra                              | No plans to implement                                 |
| `setgenerate`                 | Zebra                              | No plans to implement                                 |
| `getblocksubsidy`             | Zebra                              | None. All done in Zebra                               |
| `getblocktemplate`            | Zebra                              | Review implementation in Zebra                        |
| `getlocalsolps`               | Zebra                              | No plans to implement                                 |
| `getmininginfo`               | Zebra / Zaino                      |                                                       |
| `getnetworkhashps`            | -                                  | Deprecated                                            |
| `getnetworksolps`             | Zebra / Zaino                      |                                                       |
| `prioritisetransaction`       | Zebra                              | No plans to implement                                 |
| `submitblock`                 | Zebra                              | None                                                  |
| `addnode`                     | Zebra                              | Decide if we want to implement in Zebra               |
| `clearbanned`                 | Zebra                              | Decide if we want to implement in Zebra               |
| `disconnectnode`              | Zebra                              | Decide if we want to implement in Zebra               |
| `getaddednodeinfo`            | Zebra                              | Decide if we want to implement in Zebra               |
| `getnettotals`                | Zebra                              | Decide if we want to implement in Zebra               |
| `getnetworkinfo`              | Zebra / Zaino                      | Implement in Zebra                                    |
| `getpeerinfo`                 | Zebra / Zaino                      | Review implementation in Zebra                        |
| `listbanned`                  | Zebra                              | Decide if we want to implement in Zebra               |
| `ping`                        | Zebra / Zaino                      | Implement in Zebra                                    |
| `setban`                      | Zebra                              | Decide if we want to implement in Zebra               |
| `createrawtransaction`        | Zallet                             |                                                       |
| `decoderawtransaction`        | Zallet                             | Lower priority. Might deprecate                       |
| `decodescript`                | Zallet                             | Lower priority. Might deprecate                       |
| `fundrawtransaction`          | Zallet                             |                                                       |
| `getrawtransaction`           | Zebra / Zaino                      | Review implementation in Zebra                        |
| `sendrawtransaction`          | Zebra / Zaino                      | Review implementation in Zebra                        |
| `signrawtransaction`          | Zallet                             |                                                       |
| `validateaddress`             | Zebra / Zaino                      | Implement in Zaino                                    |
| `verifymessage`               | Zallet                             | Implement in Zallet                                   |
| `z_validateaddress`           | Zebra                              | Implement in Zaino                                    |

It is very important that the project team focuses on the agreed upon RPC mapping and figures out exactly which RPC will be served by which component, as ultimately this information will be used by Z3 to route requests to the right backend service.  Note that the RPC Method Support list seems to be imcomplete, with many methods indicating that they will be served by either Zebra or Zaino or both. We urgently need to drive these decisions to ground in order to move forward.

## RPC Methods exposed by Zcashd

The following [RPC methods](./data/zcashd_RPC_methods.md) are all of the methods historically exposed by the legacy Zcashd software.

## Dependencies

### Z3 Wrapper Dependencies

TBD but generally speaking we want to use the same libraries and frameworks that the ZF Engineering team is familiar and comfortable with based on its work on Zebra.

### Zebra Dependencies

* Core crates:
  * `zebra-chain`: Core data structures and crypto primitives for the Zcash protocol
  * `zebra-consensus`: Consensus rules implementation and block validation
  * `zebra-network`: P2P networking stack and peer management
  * `zebra-state`: Chain state management and block storage
  * `zebra-rpc`: JSON-RPC and gRPC server implementations
  * `zebra-script`: Bitcoin script verification engine for transparent transactions
  * `zebra-node-services`: Shared services used across multiple Zebra components
  * `zebra-scan`: Block and transaction scanning utilities
  * `zebra-grpc`: gRPC service definitions and implementations
  * `zebra-utils`: Common utilities and helper functions
  * `zebra-test`: Shared test infrastructure and helpers
  * `tower-batch-control`: Custom Tower middleware for batch control
  * `tower-fallback`: Custom Tower middleware for fallback handling
  * `zebrad`: Main executable binary crate

* Zcash Dependencies:
  * `halo2`: Zero-knowledge proof system used for Orchard shielded transactions
  * `orchard`: Implementation of the Orchard shielded pool protocol
  * `zcash_primitives`: Core Zcash cryptographic primitives
  * `zcash_proofs`: Zero-knowledge proof implementations
  * `zcash_client_backend`: Client functionality shared between wallets
  * `zcash_address`: Zcash address handling and encoding
  * `zcash_encoding`: Binary serialization for Zcash types
  * `zcash_history`: Block chain history handling
  * `zip32`: Hierarchical deterministic wallets for Zcash
  * `sapling-crypto`: Sapling zk-SNARK circuit implementations
  * `incrementalmerkletree`: Incremental Merkle tree implementation

* External dependencies:
  * `tokio`: Asynchronous runtime and utilities
  * `tower`: Service architecture and middleware
  * `futures`: Async/await primitives and utilities
  * `blake2b_simd`: High-performance hashing implementation
  * `metrics`: Core metrics collection and reporting
  * `metrics-exporter-prometheus`: Prometheus metrics exposition
  * `tracing`: Structured logging and diagnostics
  * `serde`: Data serialization framework
  * `rocksdb`: Persistent key-value storage backend
  * `hyper`: HTTP/HTTPS implementation
  * `tonic`: gRPC implementation
  * `jsonrpsee`: JSON-RPC framework
  * `reqwest`: HTTP client
  * `color-eyre`: Error reporting and handling
  * `proptest`: Property-based testing framework
  * `insta`: Snapshot testing support
  * `criterion`: Benchmarking framework

### Zaino Dependencies

* Core crates:
  * `zaino-serve`: Service implementation for light clients
  * `zaino-state`: State management and storage
  * `zaino-fetch`: Data fetching from Zebra nodes
  * `zaino-proto`: gRPC protocol definitions
  * `zaino-testutils`: Testing utilities
  * `zainod`: Main executable binary

* Zcash Dependencies:
  * `zcash_client_backend`: Modified version of librustzcash client backend
    * Custom fork: `zingolabs/librustzcash`
    * Tag: `zcash_client_sqlite-0.12.1_plus_zingolabs_changes-test_2`
    * Features: `lightwalletd-tonic`
  * `zcash_protocol`: Protocol definitions from librustzcash
    * Custom fork: `zingolabs/librustzcash`
    * Tag: `zcash_client_sqlite-0.12.1_plus_zingolabs_changes-test_2`

* Zebra Dependencies:
  * `zebra-chain`: Core data structures (from `main` branch)
  * `zebra-state`: State management (from `main` branch)
  * `zebra-rpc`: RPC interfaces (from `main` branch)

* Custom Dependencies:
  * `zingolib`: Core functionality from Zingo Labs
    * Tag: `zaino_dep_005`
  * `zingo-infra-testutils`: Testing infrastructure
  * `zingo-infra-services`: Service infrastructure

* External Dependencies:
  * `tokio`: Async runtime with full feature set
  * `tokio-stream`: Stream utilities for async data processing
  * `tonic`: gRPC implementation and server framework
  * `tonic-build`: gRPC code generation
  * `tower`: Service architecture with buffer and util features
  * `tracing`: Logging infrastructure
  * `reqwest`: HTTP client with rustls-tls support
  * `lmdb`: Lightning Memory-Mapped Database
  * `dashmap`: Thread-safe concurrent HashMap
  * `indexmap`: Hash table with deterministic iteration
  * `crossbeam-channel`: Multi-producer multi-consumer channels

### Zallet Dependencies

* Core crate:
  * `zallet`: Main wallet implementation including CLI interface and core functionality

* Zcash Dependencies:
  * `zcash_client_backend`: Wallet functionality from librustzcash
  * `zcash_client_sqlite`: SQLite storage implementation
  * `zcash_primitives`: Core cryptographic primitives
  * `zcash_keys`: Key management
  * `zcash_protocol`: Protocol definitions
  * `orchard`: Orchard shielded pool support
  * `sapling`: Sapling shielded pool support
  * `transparent`: Transparent address support
  * `zip32`: HD wallet key derivation
Note that all of the Zcash dependencies in Zallet are presently pinned to a specific revision of Librustzcash.

* External Dependencies:
  * `tokio`: Async runtime and utilities
  * `abscissa_core`: Application framework
  * `deadpool-sqlite`: SQLite connection pooling
  * `rusqlite`: SQLite database access
  * `age`: File encryption
  * `clap`: Command line argument parsing
  * `jsonrpsee`: JSON-RPC client
  * `tonic`: gRPC client (temporary for lightwalletd)

### Common Dependencies

* Runtime and async:
  * `tokio`: Async runtime used by all components
  * `tower`: Service architecture and middleware

* Observability:
  * `tracing`: Logging and diagnostics infrastructure used across all components
  
* Serialization:
  * `serde`: Data serialization framework

* RPC:
  * `tonic`: gRPC implementation (used by all, though Zallet's usage is temporary)
  * `jsonrpsee`: JSON-RPC framework (Zebra and Zallet)

* Error handling:
  * `color-eyre`: Error reporting and handling

* CLI:
  * `clap`: Command-line argument parsing

Note: While these dependencies are common, they might be used with different feature flags or versions across the components. The exact versions should be coordinated to ensure compatibility when integrating the components.

## Tool Usage Patterns

### Build Tools

* `cargo`:
  * Building: `cargo build --release`
  * Testing: `cargo test`
  * Dependency management: `cargo update`
  * Documentation: `cargo doc --no-deps`
  * Workspace management: `cargo workspace`

### Code Quality

* `clippy`:
  * Standard linting: `cargo clippy`
  * Strict checks: `cargo clippy -- -D warnings`
  * Workspace checks: `cargo clippy --workspace`
* `fmt`:
  * Code formatting: `cargo fmt`
  * Format check: `cargo fmt -- --check`

### Version Control

* `git`:
  * Branch management: Using feature branches
  * Commit messages: Following Conventional Commits spec
  * Code review: GitHub pull request workflow
  * Tagging: Semantic versioning for releases

### Containerization

* `docker`:
  * Local development: Docker Compose for service orchestration
  * Testing: Isolated test environments
  * CI/CD: GitHub Actions with Docker caching
  * Production: Multi-stage builds for minimal images

### Testing

* Unit tests: Per-module tests using `#[cfg(test)]`
* Integration tests: Using `tests/` directory
* Property testing: Using `proptest`
* Snapshot testing: Using `insta`
* Benchmarking: Using `criterion`

### Documentation

* API docs: Using rustdoc comments
* Architecture docs: Using architecture decision records (ADRs)
* User guides: Using mdBook

## Further Reading

For details about design patterns and conventions used across the Z3 stack, see the [System Patterns](systemPatterns.md).
