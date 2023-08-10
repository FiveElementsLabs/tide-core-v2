# run script
forge script script/RaffleManager.s.sol:RaffleManagerDeploy --rpc-url $POLYGON_RPC_URL --broadcast --verify -vvvv

# create and verify contract
forge create --rpc-url https://polygon.llamarpc.com \
    --constructor-args 0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd 0xE04DC42993d6094ed745169C4BB18f24204426B9 \
    --private-key <key>  \
    --etherscan-api-key <key> \
    --verify \
    src/RaffleManager.sol:RaffleManager

# verify already deployed contract
forge verify-contract \
    --chain-id 137 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string,string,string,uint256,uint256,bool,address,(uint256,uint256,address)[],(uint256,uint256,address)[])" "Referral Campaign by Awesome POG" "RCB" "https://tideprotocol.infura-ipfs.io/ipfs/QmNta6RjApJZzZHDp8jwoHxWFExSPeGNEnn6nmgqTcUaHJ" 1689340407 1692057600 false 0x8f5B08237d9aaf212a6ABeF3379149765dEE9C10  "[]" "[]") \
    --etherscan-api-key <key> \
    --compiler-version v0.8.21 \
    0x5D1563986673d6f4a1191b29C73baFae1764B747 \
    src/WaveContract.sol:WaveContract 

npx @api3/airnode-admin sponsor-requester \
  --providerUrl https://polygon.llamarpc.com \
  --sponsor-mnemonic "pole...drastic" \
  --requester-address <address> # raffle manager address

# retrieve airnode sponsor wallet from contract address
npx @api3/airnode-admin derive-sponsor-wallet-address \
  --airnode-address 0x9d3C147cA16DB954873A498e0af5852AB39139f2 \
  --airnode-xpub xpub6DXSDTZBd4aPVXnv6Q3SmnGUweFv6j24SK77W4qrSFuhGgi666awUiXakjXruUSCDQhhctVG7AQt67gMdaRAsDnDXv23bBRKsMWvRzo6kbf \
  --sponsor-address <address>