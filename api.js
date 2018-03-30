const express = require('express')
const bodyParser = require('body-parser')

const Web3 = require('web3')

if (typeof web3 !== 'undefined') {
  web3 = new Web3(web3.currentProvider)
} else {
  // set the provider you want from Web3.providers
  web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:9545"))
}

const coinbase = '0x627306090abab3a6e1400e9345bc60c78a8bef57'

const mkt_abi = require('./abi.json')
const mkt_address = '0x345ca3e014aaf5dca488057592ee47305d9b3e10'

const mkt = new web3.eth.Contract(mkt_abi, mkt_address)

const app = express()

app.use(bodyParser.json())

app.use((req, res, next) => {
  req.web3 = web3
  req.mkt = mkt
  req.coinbase = coinbase

  next()
})

app.use('/product', require('./routes/product'))

console.log('Listening at http://localhost:3000')
app.listen(3000)
