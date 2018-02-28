var fixedSupplyToken = artifacts.require('./FixedSupplyToken.sol');
var exchange = artifacts.require('./Exchange.sol');


contract('Exchange Basic Tests', function (accounts) {

	it("should be possible to add tokens", function () {

		var myTokenInstance;
		var exchangeInstance;
		return fixedSupplyToken.deployed().then(function (instance) {
			myTokenInstance = instance;
			return exchange.deployed();
		}).then(function (instance) {
			exchangeInstance = instance;
			return exchangeInstance.addToken("FIXED", myTokenInstance.address);

		}).then(function (value) {
			console.log("Added Token Return Value: " + value);
			return exchangeInstance.hasToken.call("FIXED");
		}).then(function (booleanHasToken) {
			assert.equal(booleanHasToken, true, "The Token was not added");
			return exchangeInstance.hasToken.call("SOMETHING");
		}).then(function (booleanHasNotToken) {
			assert.equal(booleanHasNotToken, false, "A Token That does not exist was found");
		})

	})

});