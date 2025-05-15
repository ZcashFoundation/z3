| Category | RPC call | Zebra support | Zcashd support | Zallet support | Zaino support | Where in new stack | Actions | Comments | Block Explorers | Insight Explorer | NH Explorer | Mining pool 1 | Mining pool 2 | Mining Pool 3 | Mining Pool 4 | Exchange 1 | Exchange 2 | Exchange 3 | Exchange 4 | Exchange 5 | Exchange 6 |
|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| Addressindex | getaddressbalance | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method | TRUE | TRUE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Addressindex | getaddressdeltas | No | Yes |  |  | Zaino |  | Related to prioritisetransaction | TRUE | TRUE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Addressindex | getaddressmempool | No | Yes |  |  | \- | Lower priority. Possibly deprecate | Is anyone using this? Lower priority for now. Fee deltas, might want to make a more useful method in future | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Addressindex | getaddresstxids | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra \| Implement in Zaino | Zebra only supports lightwalletd usage of this RPC method | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Addressindex | getaddressutxos | Partial | Yes |  |  | Zebra | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method | FALSE | FALSE | FALSE |  |  |  |  |  |  |  | TRUE |  |  |
| Blockchain | getbestblockhash | Yes | Yes |  |  | Zebra \| Zaino |  |  | TRUE | TRUE | TRUE |  |  |  |  |  |  | TRUE | TRUE |  |  |
| Blockchain | getblock | Partial | Yes |  |  | Zebra \| Zaino | Being fully implemented in Zebra | Zebra only supports lightwalletd usage of this RPC method. anchor will not be supported. | TRUE | TRUE | TRUE | TRUE | TRUE | FALSE | FALSE | TRUE | TRUE | TRUE | TRUE | TRUE |  |
| Blockchain | getblockchaininfo | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method | TRUE | TRUE | TRUE |  |  |  |  |  | TRUE | TRUE |  |  | TRUE |
| Blockchain | getblockcount | Yes | Yes |  |  | Zebra \| Zaino |  | Requested by 2 mining pools and 1 exchange | TRUE | TRUE | TRUE | TRUE | TRUE | FALSE | FALSE | TRUE | TRUE |  | TRUE | TRUE |  |
| Blockchain | getblockdeltas | No | Explorer-only |  |  | Zaino | Implement in Zaino | Insight explorer | FALSE | TRUE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | getblockhash | Yes | Yes |  |  | Zebra \| Zaino |  | Requested by 1 mining pool and 1 exchange | FALSE | FALSE | FALSE | TRUE | FALSE | FALSE | FALSE | TRUE | TRUE | TRUE |  | TRUE | TRUE |
| Blockchain | getblockhashes | No | Explorer-only |  |  | Zaino | Lower priority. Possibly deprecate | Lower priority | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | getblockheader | Yes | Yes |  |  | Zebra \| Zaino |  | Requested by 1 mining pool. chainwork will not be supported (undocumented in zcashd) | TRUE | FALSE | TRUE | TRUE | FALSE |  |  |  |  | TRUE |  |  |  |
| Blockchain | getchaintips | No | Yes |  |  | Zaino | Implement in Zaino |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | getdifficulty | Yes | Yes |  |  | Zebra \| Zaino |  | Requested by 1 mining pool | TRUE | FALSE | TRUE | TRUE | FALSE |  |  |  |  |  |  |  |  |
| Blockchain | getmempoolinfo | No | Yes |  |  | Zaino | Implement in Zaino |  | TRUE | FALSE | TRUE |  |  |  |  |  | TRUE |  |  |  | TRUE |
| Blockchain | getrawmempool | Yes | Yes |  |  | Zebra \| Zaino |  |  | TRUE | FALSE | TRUE |  |  |  |  |  |  | TRUE | TRUE | TRUE |  |
| Blockchain | getspentinfo | No | Explorer-only |  |  | Zaino | Implement in Zaino | Insight explorer | FALSE | TRUE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | gettxout | No | Yes |  |  | Zaino | Implement in Zaino | Used by Exchange 2 | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE | TRUE |  |  | TRUE |
| Blockchain | gettxoutproof | No | Yes |  |  | Zaino | Lower priority |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | gettxoutsetinfo | No | Yes |  |  | Zaino |  |  | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | verifychain | No | Yes |  |  | \- | Deprecate | zcashd debugging function | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | verifytxoutproof | No | Yes |  |  | Zaino | Lower priority | Related to gettxoutproof. Standalone function, could be anywhere | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Blockchain | z_gettreestate | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Control | getexperimentalfeatures | No | Yes |  |  | \- | Deprecate? Confirm what Zebra defines as experimental | zcashd-specific | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Control | getinfo | Partial | Yes |  |  | Zebra | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Control | getmemoryinfo | No | Yes |  |  | Zebra | No plan to implement | Lower priority | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Control | help | No | Yes |  |  | Zebra | No plans to implement | Lower priority | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Control | setlogfilter | No | Yes |  |  | Zebra | No plans to implement | Lower priority | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Control | stop | Yes | Yes |  |  | Zebra | None |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Disclosure | z_getpaymentdisclosure | No | Disabled by default |  |  | \- | Deprecate | This is for Sprout, and is only enabled via the -paymentDisclosure feature flag. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Disclosure | z_validatepaymentdisclosure | No | Disabled by default |  |  | \- | Deprecate | This is for Sprout, and is only enabled via the -paymentDisclosure feature flag. | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Generating | generate | Yes | Yes |  |  | Zebra | None | Regtest only | FALSE | FALSE | FALSE |  |  |  |  |  |  |  | TRUE |  |  |
| Generating | getgenerate | No | Yes |  |  | Zebra | No plans to implement | Regtest only. Lower priority | FALSE | FALSE | FALSE |  |  |  |  |  |  |  | TRUE |  |  |
| Generating | setgenerate | No | Yes |  |  | Zebra | No plans to implement | Regtest only. Lower priority | FALSE | FALSE | FALSE |  |  |  |  |  |  |  | TRUE |  |  |
| Mining | getblocksubsidy | Yes | Yes |  |  | Zebra | None. All done in Zebra | Requested by 1 mining pool | FALSE | FALSE | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |
| Mining | getblocktemplate | Partial | Yes |  |  | Zebra | Review implementation in Zebra | Server lists and work IDs are not supported in Zebra | FALSE | FALSE | FALSE |  |  | TRUE | TRUE |  |  |  |  |  |  |
| Mining | getlocalsolps | No | Yes |  |  | Zebra | No plans to implement | Testnet/Regtest only. Local CPU mining only; lower priority | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Mining | getmininginfo | Yes | Yes |  |  | Zebra \| Zaino |  |  | TRUE | FALSE | TRUE |  |  |  |  |  |  |  |  |  |  |
| Mining | getnetworkhashps | Yes | Disabled in 6.2.0 |  |  | \- | Deprecate | Deprecated | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Mining | getnetworksolps | Yes | Yes |  |  | Zebra \| Zaino |  | Requested by 1 mining pool | TRUE | FALSE | TRUE | TRUE | FALSE |  |  |  |  |  |  |  |  |
| Mining | prioritisetransaction | No | Yes |  |  | Zebra | No plans to implement | Related to getaddressdeltas. Only implement if specifically requested by a mining pool | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Mining | submitblock | Yes | Yes |  |  | Zebra | None | Requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE | TRUE | TRUE |  |  |  |  |  |  |
| Network | addnode | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | clearbanned | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | disconnectnode | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | getaddednodeinfo | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | getconnectioncount | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | getdeprecationinfo | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | getnettotals | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | getnetworkinfo | No | Yes |  |  | Zebra \| Zaino | Implement in Zebra | Lower priority to implement in Zebra | TRUE | FALSE | TRUE |  |  |  |  |  |  | TRUE |  |  | TRUE |
| Network | getpeerinfo | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra | Requested by 1 mining pool | TRUE | FALSE | TRUE | TRUE | FALSE |  |  |  |  |  |  |  |  |
| Network | listbanned | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | ping | No | Yes |  |  | Zebra \| Zaino | Implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Network | setban | No | Yes |  |  | Zebra | Decide if we want to implement in Zebra | Lower priority to implement in Zebra | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Rawtransactions | createrawtransaction | No | Deprecated in 6.2.0 | Not planned |  | Zallet |  | Required by 2 exchanges. Zallet will expose PCZTs instead. Being implemented in Zebra by external contributor. There are other ways to do this with a newer API. | FALSE | FALSE | FALSE |  |  | FALSE | FALSE | TRUE | TRUE |  |  |  |  |
| Rawtransactions | decoderawtransaction | No | Yes |  |  | Zallet | Lower priority. Might deprecate | Just a utility method, implementable outside zebra \| requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE | FALSE | FALSE | TRUE |  |  |  |  | TRUE |
| Rawtransactions | decodescript | No | Yes |  |  | Zallet | Lower priority. Might deprecate | Just a utility method. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Rawtransactions / wallet | fundrawtransaction | No | Deprecated in 6.2.0 | Not planned |  | Zallet |  | Zallet will expose PCZTs instead. | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE |  |  |  |  |
| Rawtransactions | getrawtransaction | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method \| requested by 1 mining pool | TRUE | FALSE | TRUE | TRUE | FALSE | FALSE | FALSE | TRUE |  | TRUE | TRUE | TRUE | TRUE |
| Rawtransactions | sendrawtransaction | Partial | Yes |  |  | Zebra \| Zaino | Review implementation in Zebra | Zebra only supports lightwalletd usage of this RPC method \| requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | FALSE | FALSE | FALSE | TRUE | TRUE | TRUE | TRUE | TRUE |  |
| Rawtransactions / wallet | signrawtransaction | No | Deprecated in 6.2.0 | Not planned |  | Zallet |  | Zallet will expose PCZTs instead. | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE | TRUE |  |  |  |
| Util | createmultisig | No | Yes |  |  | Zallet |  | Blocked on P2SH support in zcash_client_sqlite | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Util | estimatefee | No | No (removed) |  |  |  | Removed | Removed in https://github.com/zcash/zcash/issues/6557 | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  | TRUE |
| Util | validateaddress | Yes | Yes |  |  | Zebra \| Zaino | Implement in Zaino | Requested by 1 mining pool | TRUE | FALSE | TRUE | TRUE | FALSE | FALSE | FALSE | TRUE | TRUE |  |  |  |  |
| Util | verifymessage | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE |  |  |  |  |  |  |  |  |
| Util | z_validateaddress | Yes | Yes |  |  | Zebra | Implement in Zaino |  | TRUE | FALSE | TRUE |  |  |  |  |  |  | TRUE |  |  |  |
| Wallet | addmultisigaddress | No | Yes |  |  | Zallet | Implement in Zallet | Blocked on P2SH support in zcash_client_sqlite: https://github.com/zcash/librustzcash/issues/1370 | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | backupwallet | No | Yes |  |  | Zallet | Implement in Zallet | Would be copying the SQLite database file; maybe better done as a CLI command? | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | dumpprivkey | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  | TRUE |  |  |  |
| Wallet | dumpwallet | No | No (removed) |  |  |  | Removed | Removed in https://github.com/zcash/zcash/issues/5513 | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | encryptwallet | No | Experimental | Not planned |  | Zallet |  | Similar functionality would be implemented as CLI commands, not JSON-RPC methods. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | getbalance | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  | TRUE | TRUE |  |  |
| Wallet | getnewaddress | No | Disabled in 5.4.0 | Not planned |  | Zallet |  | Deprecated | FALSE | FALSE | FALSE |  |  | FALSE | FALSE | TRUE | TRUE |  |  |  |  |
| Wallet | getrawchangeaddress | No | Disabled in 5.4.0 | Not planned |  | Zallet |  | Deprecated | FALSE | FALSE | FALSE |  | TRUE | FALSE | FALSE | TRUE |  |  |  |  |  |
| Wallet | getreceivedbyaddress | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | gettransaction | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | TRUE | FALSE | FALSE | TRUE | TRUE | TRUE | TRUE |  |  |
| Wallet | getunconfirmedbalance | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | getwalletinfo | No | Yes | Stub |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  | TRUE |  |  | TRUE | TRUE |  |  |  |
| Wallet | importaddress | No | Yes |  |  | Zallet | Implement in Zallet | Less keen on supporting in JSON-RPC; if no one is using it then would leave out. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  | TRUE |  |  |
| Wallet | importprivkey | No | Yes |  |  | Zallet | Implement in Zallet | Less keen on supporting in JSON-RPC; if no one is using it then would leave out. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | importpubkey | No | Yes | Not planned |  | Zallet |  |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | importwallet | No | Yes | Not planned |  | Zallet |  | Would rather have specific commands for importing wallet material rather than a JSON-RPC | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | keypoolrefill | No | Deprecated in 6.2.0 | Not planned |  | Zallet |  | Only needed when interoperability with legacy Bitcoin infrastructure is required. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | listaddresses | No | Yes | Yes |  | Zallet | Enhance as support for other keys is added |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | listaddressgroupings | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | listlockunspent | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  | TRUE |  |  |  |
| Wallet | listreceivedbyaddress | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | listsinceblock | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE | TRUE |  |  |  |
| Wallet | listtransactions | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE |  |  |  |  |  |  |  |  |
| Wallet | listunspent | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | FALSE | TRUE | FALSE | TRUE | TRUE |  |  |  |  |
| Wallet | lockunspent | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE | TRUE |  |  |  |
| Wallet | sendmany | No | Legacy |  |  | Zallet | Implement in Zallet | Legacy transaction creation API \| requested by 1 mining pool. May need to change semantics. | FALSE | FALSE | FALSE | FALSE | TRUE | TRUE |  |  |  |  |  |  |  |
| Wallet | sendtoaddress | No | Legacy |  |  | Zallet | Implement in Zallet | Legacy transaction creation API. May need to change semantics. | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE |  |  |  |  |
| Wallet | settxfee | No | Deprecated in 6.2.0 | Not planned |  | Zallet | Do not implement | Not ZIP 317-conformant. This is only used by legacy transaction creation APIs (sendtoaddress, sendmany, and fundrawtransaction) | FALSE | FALSE | FALSE |  |  |  |  |  | TRUE |  |  |  |  |
| Wallet | signmessage | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | walletconfirmbackup | No | Internal | Not planned |  | Zallet |  | Internal method that is not intended to be called directly by users | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_exportkey | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_exportviewingkey | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_exportwallet | No | Yes |  |  | Zallet | Implement in Zallet | Might change output format to zeWIF, or we could add a format argument | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_getaddressforaccount | No | Yes | Yes |  | Zallet | Implement in Zallet | Requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE |  |  |  |  | TRUE |  |  |  |
| Wallet | z_getbalance | No | Disabled in 6.2.0 | Not planned |  | Zallet |  | Requested by 1 mining pool, should use z_getbalanceforaccount, z_getbalanceforviewingkey, or getbalance (for legacy transparent balance) instead. | FALSE | FALSE | FALSE | FALSE | TRUE |  |  |  |  |  |  |  |  |
| Wallet | z_getbalanceforaccount | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  | TRUE |  |  |  |
| Wallet | z_getbalanceforviewingkey | No | Yes |  |  | Zallet | Implement in Zallet | Zallet has UUID for all accounts including viewing keys, so not as necessary. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_getmigrationstatus | No | Yes | Not planned |  | Zallet |  | Could implement dummy "not migrating" response | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_getnewaccount | No | Yes | WIP |  | Zallet | Implement in Zallet | Requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE |  |  |  |  | TRUE | TRUE |  |  |
| Wallet | z_getnewaddress | No | Disabled in 5.4.0 | Not planned |  | Zallet |  | Deprecated | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_getnotescount | No | Yes | WIP |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  | TRUE |  |  |  |
| Wallet | z_getoperationresult | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | TRUE |  |  |  |  | TRUE |  |  |  |
| Wallet | z_getoperationstatus | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | TRUE |  |  |  |  |  |  |  |  |
| Wallet | z_gettotalbalance | No | Deprecated in 5.0.0 | Not planned |  | Zallet |  | Deprecated \| requested by 1 mining pool, should use z_getbalanceforaccount or getbalance | FALSE | FALSE | FALSE | FALSE | TRUE | FALSE | FALSE | TRUE |  |  |  |  |  |
| Wallet | z_importkey | No | Sprout or Sapling |  |  | Zallet | Implement in Zallet | Implement for Sapling. Orchard support not needed. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_importviewingkey | No | Sprout or Sapling |  |  | Zallet | Implement in Zallet | Implement for Sapling. Unified Viewing Key support not needed. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_importwallet | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_listaccounts | No | Yes | WIP |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  | TRUE | TRUE |  |  |
| Wallet | z_listaddresses | No | Disabled in 5.4.0 | Not planned |  | Zallet |  | Deprecated, should use listaddresses | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_listoperationids | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_listreceivedbyaddress | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_listunifiedreceivers | Yes | Yes | Stub |  | Zallet \| Zebra | Implement in Zallet | Requested by 1 mining pool | TRUE | FALSE | TRUE | TRUE | FALSE |  |  |  |  | TRUE |  |  |  |
| Wallet | z_listunspent | No | Yes | WIP |  | Zallet |  | Requested by 1 mining pool | FALSE | FALSE | FALSE | TRUE | FALSE |  |  |  |  | TRUE |  |  |  |
| Wallet | z_mergetoaddress | No | Yes |  |  | Zallet | Implement in Zallet |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_sendmany | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | TRUE |  |  |  |  | TRUE | TRUE |  |  |
| Wallet | z_setmigration | No | Yes |  |  | Zallet | Do not implement | zcashd only supported Sprout-to-Sapling; Zallet won't support Sprout. | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | z_shieldcoinbase | No | Yes |  |  | Zallet | Implement in Zallet | Requested by 2 mining pools | FALSE | FALSE | FALSE | TRUE | TRUE |  |  |  |  |  | TRUE |  |  |
| Wallet | z_viewtransaction | No | Yes |  |  | Zallet | Implement in Zallet | Maybe modify semantics to show entire transaction | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | zcbenchmark | No | Yes | Not planned |  | Zallet |  |  | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
| Wallet | zcsamplejoinsplit | No | Yes |  |  | Zallet | Do not implement | Sprout-only | FALSE | FALSE | FALSE |  |  |  |  |  |  |  |  |  |  |
