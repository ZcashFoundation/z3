# Zcash Ecosystem Map

```mermaid
graph TD
    %% Define Central Node
    ZcashProtocol((Zcash Protocol\nzk-SNARKs, PoW Network))

    %% Define Subgraphs for Categories
    subgraph CoreDev [Core Protocol Development & Stewardship]
        direction LR
        ECC[Electric Coin Co.\n(zcashd, Zashi, R&D)]
        ZF[Zcash Foundation\n(Zebra, Governance, ZCG Admin)]
    end

    subgraph Funding [Grant Funding & Community Support]
        direction LR
        ZCG[Zcash Community Grants\n(Dev Fund Allocation)]
        Ambassadors[Global Ambassadors]
    end

    subgraph WalletsApps [Wallet & Application Development]
        direction TB
        ECCWallets(ECC Reference Wallets\n e.g., Zashi)
        ThirdPartyWallets(Third-Party Wallets\n Nighthawk, YWallet, etc.)
        SDKs(Zcash SDKs\n iOS, Android, Rust)
    end

    subgraph Infra [Infrastructure & Services]
        direction TB
        Nodes(Node Operators\n zcashd/Zebra)
        Pools(Mining Pools)
        Explorers(Block Explorers)
        Exchanges(Exchanges)
    end

    subgraph Research [Research & Cryptography]
        direction LR
        ECCResearch(ECC Crypto Team)
        ZFResearch(ZF Research Initiatives)
        Academia(Academic Researchers)
    end

    %% Define Relationships (Arrows indicate influence, data flow, funding, usage etc.)

    %% Core Development -> Protocol
    ECC -->|Develops/Maintains 'zcashd'| ZcashProtocol
    ZF -->|Develops 'Zebra', Stewards| ZcashProtocol

    %% Funding Relationships
    ZF -- Administers & Supports --> ZCG
    ZCG -- Funds Projects --> ThirdPartyWallets
    ZCG -- Funds Projects --> SDKs
    ZCG -- Funds Projects --> Infra
    ZCG -- Funds Projects --> Research
    ZCG -- Funds Projects --> Ambassadors

    %% Development -> Wallets/SDKs
    ECC -- Develops --> ECCWallets
    ECC -- Leads --> ECCResearch
    ZF -- Supports --> ZFResearch
    SDKs -- Enables Dev --> ThirdPartyWallets
    SDKs -- Enables Dev --> ECCWallets

    %% Wallets/Apps -> Protocol & Infra
    ECCWallets -- Uses --> ZcashProtocol
    ThirdPartyWallets -- Uses --> ZcashProtocol
    ECCWallets -- Interacts With --> Nodes
    ThirdPartyWallets -- Interacts With --> Nodes

    %% Infrastructure -> Protocol & Users/Wallets
    Nodes -- Maintain & Validate --> ZcashProtocol
    Pools -- Secure (PoW) --> ZcashProtocol
    Explorers -- Read Data From --> Nodes
    Exchanges -- Interact With --> Nodes
    Exchanges -- Provide Liquidity --> ZcashProtocol
    Exchanges -- Serve Users --> WalletsApps

    %% Research -> Core Dev & Community
    Research -- Informs --> CoreDev
    ECCResearch -- Contributes To --> ECC
    ZFResearch -- Contributes To --> ZF
    Academia -- Publishes/Advises --> Research

    %% Community -> Protocol
    Ambassadors -- Promote --> ZcashProtocol

    %% Style (Optional, simple styling)
    style ZcashProtocol fill:#f9f,stroke:#333,stroke-width:2px
    classDef category fill:#f3f3f3,stroke:#555,stroke-dasharray: 5 5
    class CoreDev,Funding,WalletsApps,Infra,Research category
    ```
    