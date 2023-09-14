# create and verify contract
forge create --rpc-url rpcUrl \
    --constructor-args $(cast abi-encode "constructor(string,(uint256,string)[])" "Example" "[(1000,example)]") \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify \
    contractPath

# verify already deployed contract
forge verify-contract \
    --chain-id chainId \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string,(uint256,string)[])" "Example" "[(1000,example)]") \
    --etherscan-api-key $ARBISCAN_API_KEY \
    --compiler-version v0.8.21 \
    contractAddress \
    contractPath

#api3 section
npx @api3/airnode-admin sponsor-requester \
  --providerUrl providerUrl \
  --sponsor-mnemonic "pole...drastic" \
  --requester-address <address> # raffle manager address

# retrieve airnode sponsor wallet from contract address
npx @api3/airnode-admin derive-sponsor-wallet-address \
  --airnode-address airnodeAddress \
  --airnode-xpub airnodeXPub \
  --sponsor-address sponsorAddress