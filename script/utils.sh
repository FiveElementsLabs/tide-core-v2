# create and verify contract
source .env && forge create --rpc-url "https://polygon.llamarpc.com" \
  --constructor-args 0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd 0xCFb140930c5eF56d1c154eE865c7AC12E5EcB18b \ 
    --private-key $PRIVATE_KEY \
    --etherscan-api-key SNTIKT5HBS3WKWCW2GYAQN1NBU412UZUZW \
    --verify \
    src/core/RaffleManager.sol:RaffleManager

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
