var fixedSupplyToken = artifacts.require('./FixedSupplyToken.sol');
var exchange = artifacts.require('./Exchange.sol');

contract("Exchange Order Tests", function (accounts) {
	before(function () {
		var instanceExchange;
		var instanceToken;
		return exchange.deployed().then(function (value) {
			instanceExchange = value;
			return instanceExchange.depositEther({from: accounts[0], value: web3.toWei(3, 'ether')});
		}).then(function (txResult) {
			return fixedSupplyToken.deployed();
		}).then(function (value) {
			instanceToken = value;
			return instanceExchange.addToken("FIXED", instanceToken.address);
		}).then(function (value) {
			return instanceToken.transfer(accounts[1], 2000);
		}).then(function (value) {
			return instanceToken.approve(instanceExchange.address, 2000, {from: accounts[1]});
		}).then(function (value) {
			return instanceExchange.depositToken("FIXED", 2000, {from: accounts[1]});
		})
	});

	it("should be possible to add fully fulfill buy orders", function () {
		var myExchangeInstance;
		return exchange.deployed().then(function (value) {
			myExchangeInstance = value;
			return myExchangeInstance.getSellOrderBook.call("FIXED");
		}).then(function (orderBook) {
			assert.equal(orderBook.length, 2, "SellOrderBook Should Have 2 Elements");
			assert.equal(orderBook[0].length, 0, "SellOrderBook Should have 0 Sell Offers");
			return myExchangeInstance.sellToken("FIXED", web3.toWei(2, 'finney'), 5, {from: accounts[1]});
		}).then(function (txResult) {
			assert.equal(txResult.logs.length, 1, "There should have been one log message emitted.");
			assert.equal(txResult.logs[0].event, "LimitSellOrderCreated", "The Log-Event should be LimitSellOrderCreated");
			return myExchangeInstance.getSellOrderBook.call("FIXED");
		}).then(function (orderBook) {
			assert.equal(orderBook[0].length, 1, "OrderBook should have 1 sell offers");
			assert.equal(orderBook[1].length, 1, "OrderBook should have 1 sell volume has one element");
			assert.equal(orderBook[1][0], 5, "OrderBook should have a volume of 5 coins someone wants to sell");
			return myExchangeInstance.buyToken("FIXED", web3.toWei(3, 'finney'), 5);
		}).then(function (txResult) {
			assert.equal(txResult.logs.length, 1, "There should hav been one log message emitted");
			assert.equal(txResult.logs[0].event, "SellOrderFulfilled", "The Log-Event should be SellOrderFulfilled");
			return myExchangeInstance.getSellOrderBook.call("FIXED");
		}).then(function (orderBook) {
			assert.equal(orderBook[0].length, 0, "Sell Order Book should have 0 sell offers");
			assert.equal(orderBook[1].length, 0, "Sell order volume should be 0");
			return myExchangeInstance.getBuyOrderBook.call("FIXED");
		}).then(function (orderBook) {
			assert.equal(orderBook[0].length, 0, "buyorderBook should have 0 buy offers");
			assert.equal(orderBook[1].length, 0, "buyorderBook volume should be 0");
		})
	})
});