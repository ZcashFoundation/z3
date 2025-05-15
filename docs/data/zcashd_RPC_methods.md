# Zcashd RPC Methods Reference

## Blockchain Information
- `getblockchaininfo` - Get current state of the blockchain
- `getbestblockhash` - Get hash of best (tip) block in the longest blockchain
- `getblockcount` - Get the current block count
- `getblock` - Get block data by hash
- `getblockhash` - Get hash of block at height
- `getblockheader` - Get block header by hash
- `getchaintips` - Get information about all known chain tips
- `z_gettreestate` - Get Sapling and Orchard tree state
- `z_getsubtreesbyindex` - Get note commitment subtrees
- `getdifficulty` - Get proof-of-work difficulty

## Mempool Operations
- `getmempoolinfo` - Get mempool statistics
- `getrawmempool` - Get all transaction IDs in memory pool
- `gettxout` - Get details about an unspent transaction output
- `gettxoutsetinfo` - Get statistics about the unspent transaction output set

## Chain Validation
- `verifychain` - Verify blockchain database
- `getblockdeltas` - Get block deltas by hash
- `getblockhashes` - Get block hashes in range
- `invalidateblock` - Permanently mark a block as invalid
- `reconsiderblock` - Remove invalid status from block and children

## Mining
- `getlocalsolps` - Get local solutions per second
- `getnetworksolps` - Get network solutions per second
- `getnetworkhashps` - Get estimated network hashes per second
- `getmininginfo` - Get mining-related information
- `prioritisetransaction` - Change transaction priority
- `getblocktemplate` - Get block template for mining
- `submitblock` - Submit mined block
- `getblocksubsidy` - Get block subsidy reward
- `getgenerate` - Check if CPU mining is enabled
- `setgenerate` - Set generation on/off
- `generate` - Mine blocks immediately

## Network and Node Info
- `getinfo` - Get general information
- `getmemoryinfo` - Get memory usage info
- `getconnectioncount` - Get connection count
- `getdeprecationinfo` - Get deprecation info
- `ping` - Ping other nodes
- `getpeerinfo` - Get peer connection info
- `addnode` - Add/remove/try a node
- `disconnectnode` - Disconnect from node
- `getaddednodeinfo` - Get info about added nodes
- `getnettotals` - Get network traffic info
- `getnetworkinfo` - Get network info
- `setban` - Ban a network address
- `listbanned` - List banned IPs/Subnets
- `clearbanned` - Clear banned addresses

## Address and Validation
- `validateaddress` - Validate a transparent address
- `z_validateaddress` - Validate a shielded address
- `createmultisig` - Create multisig address
- `verifymessage` - Verify signed message
- `getexperimentalfeatures` - Get experimental feature state
- `getaddresstxids` - Get txids for address
- `getaddressbalance` - Get address balance
- `getaddressdeltas` - Get address deltas
- `getaddressutxos` - Get address utxos
- `getaddressmempool` - Get address mempool
- `getspentinfo` - Get spent info for output

## Debug and Testing
- `setmocktime` - Set network time for testing