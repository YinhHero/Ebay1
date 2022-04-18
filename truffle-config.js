// Allows us to use ES6 in our migrations and tests.
var HDWalletProvider = require("truffle-hdwallet-provider");

var mnemonic = "mosquito badge float source roof basket track soup sick venture snap armor";
// infura 注册后获取的api-key
var infura_apikey = "11637a50b4b04be4b15cb7da5fa9c043";

// 接下来，提供助记词（mnemonic）来生成你的账户。 進入 MetaMask -> Settings -> reveal seed words 复制到这里
//警告 ：在此过程中，我们强烈建议将助记符存储在另一个（秘密）文件中，以降低助记符泄漏风险。 如果有人知道你的助记符，他们将拥有你所有的地址和私钥！我这个地址是测试地址，没有主网的ETH代币，所以无所谓！

require('babel-register')

module.exports = {
  networks: {
    develop: {
      host: 'localhost',
      port: 8545,
      network_id: '*' // Match any network id
    },
    // development: {
    //   host: 'localhost',
    //   port: 9545,
    //   network_id: '*' // Match any network id
    // },
    ganacheNet: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    ropsten: {
      provider: () => new HDWalletProvider(mnemonic, 'https://ropsten.infura.io/v3/11637a50b4b04be4b15cb7da5fa9c043',0),
      network_id: 3,       // Ropsten's id
      gas: 5500000,        // Ropsten has a lower block limit than mainnet
      gasPrice: 200000000000,
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    }
    // advanced: {
    //   provider: () => new HDWalletProvider(mnemonic, `https://mainnet.infura.io`),
    //   network_id: 1,       // Custom network
    //   gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    //   gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    //   from: <address>,        // Account to send txs from (default: accounts[0])
    //   websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // }
  }
}
