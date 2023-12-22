# create and verify contract
source .env && forge create --rpc-url "https://polygon.llamarpc.com" \
  --constructor-args 0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd 0xCFb140930c5eF56d1c154eE865c7AC12E5EcB18b \
  --private-key $PRIVATE_KEY \
  --etherscan-api-key SNTIKT5HBS3WKWCW2GYAQN1NBU412UZUZW \
  --verify \
  src/core/RaffleManager.sol:RaffleManager

# verify already deployed contract
source .env && forge verify-contract \
    --chain-id 137 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string,string,string,uint256,uint256,bool,address,(uint256,uint256,address,bool))" "ERC20 FCFS with new factory" "EFW" "https://tideprotocol.infura-ipfs.io/ipfs/QmbM9YF6ETE6PsczVsyUY1Et6GAaWQwXB5SeAHjVdFhqwk" 1703255091 1705967999 false 0x8f5B08237d9aaf212a6ABeF3379149765dEE9C10 "(2,10000000000000000,0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,false)") \
    --etherscan-api-key $POLYGONSCAN_API_KEY \
    --compiler-version v0.8.21 \
    0x9Ce336259cCa2f686fe49Bc6ACeC8Cb41ed02b2D \
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
