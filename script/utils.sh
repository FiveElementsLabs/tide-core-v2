# run script
forge script script/RaffleManager.s.sol:RaffleManagerDeploy --rpc-url $POLYGON_RPC_URL --broadcast --verify -vvvv

# verify already deployed contract
forge verify-contract \
    --chain-id 137 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string,string,string,uint256,uint256,bool,address,(uint256,uint256,address)[],(uint256,uint256,address)[])" "Referral Campaign by Awesome POG" "RCB" "https://tideprotocol.infura-ipfs.io/ipfs/QmNta6RjApJZzZHDp8jwoHxWFExSPeGNEnn6nmgqTcUaHJ" 1689340407 1692057600 false 0x8f5B08237d9aaf212a6ABeF3379149765dEE9C10  "[]" "[]") \
    --etherscan-api-key <your-api-key> \
    --compiler-version v0.8.21 \
    0x5D1563986673d6f4a1191b29C73baFae1764B747 \
    src/WaveContract.sol:WaveContract 

# retrieve airnode sponsor wallet from contract address
npx @api3/airnode-admin derive-sponsor-wallet-address \
  --airnode-address 0x9d3C147cA16DB954873A498e0af5852AB39139f2 \
  --airnode-xpub xpub6DXSDTZBd4aPVXnv6Q3SmnGUweFv6j24SK77W4qrSFuhGgi666awUiXakjXruUSCDQhhctVG7AQt67gMdaRAsDnDXv23bBRKsMWvRzo6kbf \
  --sponsor-address 0x2AC283aa28157dA7d2A735CF6e4d42c7d0Dd2a38