# create and verify contract
source .env && forge create --rpc-url "https://polygon.llamarpc.com" \
  --constructor-args 0x607291C9B3b03D8C2DC1F5f7F8db2B6A06C91183 0x8f5B08237d9aaf212a6ABeF3379149765dEE9C10 0x75d14F0Ae59003C0806B625B402a40340Ffde634 0xA668BDf7AC5f9a2C45F0F233708ea654993D219d \
  --private-key $PRIVATE_KEY \
  --etherscan-api-key SNTIKT5HBS3WKWCW2GYAQN1NBU412UZUZW \
  --verify \
  src/core/WaveFactory.sol:WaveFactory

# run deploy pipeline
source .env && forge script script/DeployPipeline.sol --rpc-url $POLYGON_RPC_URL --verify --etherscan-api-key $POLYGONSCAN_API_KEY --broadcast -vvvv --with-gas-price 1000000 #gas-price in wei

# run deploy pipeline on blockscout networks
source .env && forge script script/DeployPipeline.sol --rpc-url $SHIMMER_RPC_URL --verify --verifier-url "https://explorer.evm.shimmer.network.api/" --verifier blockscout --broadcast -vvvv --legacy --with-gas-price 1000000 #gas-price in wei

# verify already deployed contract
source .env && forge verify-contract \
    --chain-id 8822 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string,string,string,uint256,uint256,bool,address,(uint256,uint256,address,bool))" "Liquidity campaign" "LC" "https://campaigns-metadata.s3.eu-west-1.amazonaws.com/1020d4b8-2132-4ced-b807-85f2a0ca08af" 1718661644 1722383999 false 0xafA1853E44e547F1A9770Fd37c4556b4Faf54674 "(0,0,0x0000000000000000000000000000000000000000,false)") \
    --compiler-version v0.8.21 \
    --verifier blockscout \
    --verifier-url https://explorer.evm.iota.org/api \
    0x331395A35379bcAfA7612aaDF9a9fb54199a398c \
    src/core/WaveContract.sol:WaveContract

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

# verify on blockscout
forge verify-contract \
--chain-id 148 \
--num-of-optimizations 200 \
--watch \
--constructor-args $(cast abi-encode "constructor(string,string,string,uint256,uint256,bool,address,(uint256,uint256,address)[],(uint256,uint256,address)[])" "$SMR Raffle by ApeDAO" "$RB" "https://tideprotocol.infura-ipfs.io/ipfs/Qmda3qGoBgJp4Ru2m3oUJ9FDbXuiFDeedgscuw4FAXcQm5" 1702915225 1705599059 true 0x0000000000000000000000000000000000000000 "[]" "[(5,50000000,0x1074010000000000000000000000000000000000)]") \
--etherscan-api-key \
--compiler-version v0.8.21 \
--verifier blockscout \
--verifier-url https://explorer.evm.shimmer.network/api \
0x04d310073eFE595949f384AC030E661F5dD05b60 \
src/core/WaveContract.sol:WaveContract
