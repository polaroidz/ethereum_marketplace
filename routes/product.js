const router = require('express').Router()

router.post('/', (req, res, next) => {
  const {owner, unitPrice, name} = req.body

  const options = {
    from: req.coinbase,
    gas: Math.pow(10, 6)
  }

  req.mkt.methods.registerProductFrom(owner, name, unitPrice)
    .send(options)
    .then(data => res.json(data))
    .catch(err => res.json(err))
    .then(() => next())
})

module.exports = router