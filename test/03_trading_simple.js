var fixedSupplyToken = artifacts.require('./FixedSupplyToken.sol');
var exchange = artifacts.require('./Exchange.sol');

contract('Simple Order Tests', function (accounts) {

    before(function () {
        var instanceToken;
        var instanceExchange;
        return exchange.deployed().then(function (exchangeInstance) {
            instanceExchange = exchangeInstance;
            return instanceExchange.depositEther({from: accounts[0], value: web3.toWei(3, 'ether')});

        }).then(function (txResult) {
            console.log("Tx Result after Depositiing Ether:");
            console.log(txResult);
            return fixedSupplyToken.deployed();
        }).then(function (tokenInstance) {
            instanceToken = tokenInstance;
            return instanceExchange.addToken("FIXED", instanceToken.address);
        }).then(function (txResult) {
            console.log("Tx Result after Adding Token:");
            console.log(txResult);
            return instanceToken.approve(instanceExchange.address, 2000);
        }).then(function (txResult) {
            console.log("Tx Result after Approving Token:");
            console.log(txResult);
            return instanceExchange.depositToken("FIXED", 2000);
        })
    })

    it("should be able to add a limit a buy order", function () {
        var myExchangeInstance;
        return exchange.deployed().then(function (instance) {
            myExchangeInstance = instance;
            return myExchangeInstance.getBuyOrderBook.call("FIXED");
        }).then(function (orderBook) {
            assert.equal(orderBook.length, 2, "BuyOrderBook should have two elements");
            assert.equal(orderBook[0].length, 0, "OrderBook should have 0 Buy Offers");
            return myExchangeInstance.buyToken("FIXED", we3.toWei(1, 'finney'), 5);
        }).then(function (txResult) {
            console.log("Tx Result after Buying Token:");
            console.log(txResult);
            assert.equal(txResult.logs.length, 1, "There Should have been one Log Message Emitted");
            assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event Should be LimitBuyOrderCreated");
            return myExchangeInstance.getBuyOrderBook.call("FIXED");
        }).then(function (orderBook) {
            assert.equal(orderBook[0].length, 1, "The OrderBook should have One BuyOffer");
            assert.equal(orderBook[1].length, 1, "The OrderBook Should have One Buy Volume one element");
        })
    })

    it("should be possible to add three limit buy orders", function () {
        var myExchangeInstance;
        var orderBookLengthBeforeBuy;
        return exchange.deployed().then(function (instance) {
            myExchangeInstance = instance;
            return myExchangeInstance.getBuyOrderBook.call("FIXED");
        }).then(function (orderBook) {
            orderBookLengthBeforeBuy = orderBook[0].length;
            console.log("Order Book Length before Buy: " + orderBookLengthBeforeBuy);
            return myExchangeInstance.buyToken("FIXED", web3.toWei(1.4, 'finney'), 5);
        }).then(function (txResult) {
            console.log("Tx Result after Buying Token:");
            console.log(txResult);
            assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event Should Be LimitBuyOrderCreated");
            return myExchangeInstance.buyToken("FIXED", web3.toWei(2, 'finney'), 5);
        }).then(function (txResult) {
            console.log("Tx Result after Buying Token:");
            console.log(txResult);
            assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event Should Be LimitBuyOrderCreated");
            return myExchangeInstance.getBuyOrderBook.call("FIXED");
        }).then(function (orderBook) {
            assert.equal(orderBook[0].length, orderBookLengthBeforeBuy + 2, "Order Book Should Have two more buy offers");
            assert.equal(orderBook[1].length, orderBookLengthBeforeBuy + 2, "Order Book Volume should have 2 more volume elements");
        })
    })

})