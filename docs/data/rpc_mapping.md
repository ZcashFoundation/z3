# source: https://docs.google.com/spreadsheets/d/1UJxH1cowexGqadU32Uei5Qak6jGhXjb18-T_QBPmDAA/edit?gid=0#gid=0

| RPC Method | Where in new stack | Actions |
|---|---|---|
| `getaddressbalance` | Zebra (lightwalletd usage) / Zaino | Review implementation in Zebra |
| `getaddressdeltas` | Zaino |  |
| `getaddressmempool` | - | Lower priority. Possibly deprecate |
| `getaddresstxids` | Zebra (lightwalletd usage) / Zaino | Review implementation in Zebra \| Implement in Zaino |
| `getaddressutxos` | Zebra | Review implementation in Zebra |
| `getbestblockhash` | Zebra / Zaino |  |
| `getblock` | Zebra / Zaino | Being fully implemented in Zebra |
| `getblockchaininfo` | Zebra / Zaino | Review implementation in Zebra |
| `getblockcount` | Zebra / Zaino |  |
| `getblockdeltas` | Zaino | Implement in Zaino |
| `getblockhash` | Zebra / Zaino |  |
| `getblockhashes` | Zaino | Lower priority. Possibly deprecate |
| `getblockheader` | Zebra / Zaino |  |
| `getchaintips` | Zaino | Implement in Zaino |
| `getdifficulty` | Zebra / Zaino |  |
| `getmempoolinfo` | Zaino | Implement in Zaino |
| `getrawmempool` | Zebra / Zaino |  |
| `getspentinfo` | Zaino | Implement in Zaino |
| `gettxout` | Zaino | Implement in Zaino |
| `gettxoutproof` | Zaino | Lower priority |
| `gettxoutsetinfo` | Zaino |  |
| `verifychain` | - | Deprecate |
| `verifytxoutproof` | Zaino | Lower priority |
| `z_gettreestate` | Zebra / Zaino | Review implementation in Zebra |
| `getexperimentalfeatures` | - | Deprecate? Confirm what Zebra defines as experimental |
| `getinfo` | Zebra | Review implementation in Zebra |
| `getmemoryinfo` | Zebra | No plan to implement |
| `help` | Zebra | No plans to implement |
| `setlogfilter` | Zebra | No plans to implement |
| `stop` | Zebra | None |
| `z_getpaymentdisclosure` | - | Deprecate |
| `z_validatepaymentdisclosure` | - | Deprecate |
| `generate` | Zebra | None |
| `getgenerate` | Zebra | No plans to implement |
| `setgenerate` | Zebra | No plans to implement |
| `getblocksubsidy` | Zebra | None. All done in Zebra |
| `getblocktemplate` | Zebra | Review implementation in Zebra |
| `getlocalsolps` | Zebra | No plans to implement |
| `getmininginfo` | Zebra / Zaino |  |
| `getnetworkhashps` | - | Deprecated |
| `getnetworksolps` | Zebra / Zaino |  |
| `prioritisetransaction` | Zebra | No plans to implement |
| `submitblock` | Zebra | None |
| `addnode` | Zebra | Decide if we want to implement in Zebra |
| `clearbanned` | Zebra | Decide if we want to implement in Zebra |
| `disconnectnode` | Zebra | Decide if we want to implement in Zebra |
| `getaddednodeinfo` | Zebra | Decide if we want to implement in Zebra |
| `getnettotals` | Zebra | Decide if we want to implement in Zebra |
| `getnetworkinfo` | Zebra / Zaino | Implement in Zebra |
| `getpeerinfo` | Zebra / Zaino | Review implementation in Zebra |
| `listbanned` | Zebra | Decide if we want to implement in Zebra |
| `ping` | Zebra / Zaino | Implement in Zebra |
| `setban` | Zebra | Decide if we want to implement in Zebra |
| `createrawtransaction` | Zallet |  |
| `decoderawtransaction` | Zallet | Lower priority. Might deprecate |
| `decodescript` | Zallet | Lower priority. Might deprecate |
| `fundrawtransaction` | Zallet |  |
| `getrawtransaction` | Zebra / Zaino | Review implementation in Zebra |
| `sendrawtransaction` | Zebra / Zaino | Review implementation in Zebra |
| `signrawtransaction` | Zallet |  |
| `validateaddress` | Zebra / Zaino | Implement in Zaino |
| `verifymessage` | Zallet | Implement in Zallet |
| `z_validateaddress` | Zebra | Implement in Zaino |