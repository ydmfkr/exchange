var fixedSupplyToken = artifacts.require('./FixedSupplyToken.sol');
var exchange = artifacts.require('./Exchange.sol');


contract('Basic Exchange Tests', function (accounts) {

	it("should be possible to add tokens", function () {

		var myTokenInstance;
		var exchangeInstance;
		return fixedSupplyToken.deployed().then(function (instance) {
			myTokenInstance = instance;
			return exchange.deployed();
		}).then(function (instance) {
			exchangeInstance = instance;
			return exchangeInstance.addToken("FIXED", myTokenInstance.address);

		}).then(function (txResult) {
			console.log("Added Token Return Value: " + txResult);
			assert.eqaul(txResult.logs[0].event, "TokenAddedToSystem", "Token Added TO System Evnt Should be Emitted");
			return exchangeInstance.hasToken.call("FIXED");
		}).then(function (booleanHasToken) {
			assert.equal(booleanHasToken, true, "The Token was not added");
			return exchangeInstance.hasToken.call("SOMETHING");
		}).then(function (booleanHasNotToken) {
			assert.equal(booleanHasNotToken, false, "A Token That does not exist was found");
		})

	});


	it("should be possible to deposit and withdraw ether", function () {

		var myExchangeInstance;
		var balanceBeforeTransaction = web3.eth.getBalance(accounts[0]);
		console.log(balanceBeforeTransaction);
		var balanceAfterDeposit;
		var balanceAfterWithdraw;
		var gasUsed = 0;

		return exchange.deployed().then(function (instance) {
			myExchangeInstance = instance;
			return myExchangeInstance.depositEther({from: accounts[0], value: web3.toWei(1, 'ether')});
		}).then(function (txHash) {
			gasUsed += txHash.receipt.cumulativeGasUsed * web3.eth.getTransaction(txHash.receipt.transactionHash).gasPrice.toNumber();
			console.log(gasUsed);
			balanceAfterDeposit = web3.eth.getBalance(accounts[0]);
			console.log("Balance after Deposit into exchange: " + balanceAfterDeposit);
			return myExchangeInstance.getEthBalanceInWei.call();
		}).then(function (balanceInWei) {
			assert.equal(balanceInWei.toNumber(), web3.toWei(1, 'ether'), "There is one Ether Available");
			assert.isAtLeast(balanceBeforeTransaction.toNumber() - balanceAfterDeposit.toNumber(), web3.toWei(1, 'ether'), "Balances of the accounts are the same");
			return myExchangeInstance.withdrawEther(web3.toWei(1, 'ether'));
		}).then(function (txHash) {
			balanceAfterWithdraw = web3.eth.getBalance(accounts[0]);
			return myExchangeInstance.getEthBalanceInWei.call();
		}).then(function (balanceInWei) {
			assert.equal(balanceInWei.toNumber(), 0, "There is no ether available anymore");
			assert.isAtLeast(balanceAfterWithdraw.toNumber(), balanceBeforeTransaction.toNumber() - (gasUsed * 2), "There is one Ether Available");
		})

	});

	it("should be able to deposit token", function () {

		var myExchangeInstance;
		var myTokenInstance;
		return fixedSupplyToken.deployed().then(function (instance) {
			myTokenInstance = instance;
			return instance;
		}).then(function (tokenInstance) {
			myTokenInstance = tokenInstance;
			return exchange.deployed();
		}).then(function (exchangeInstance) {
			myExchangeInstance = exchangeInstance;
			return myTokenInstance.approve(myExchangeInstance.address, 2000);
		}).then(function (txResult) {
			return myExchangeInstance.depositToken("FIXED", 2000);
		}).then(function (txResult) {
			return myExchangeInstance.getBalance("FIXED");
		}).then(function (balanceToken) {
			assert.equal(balanceToken, 2000, " There should be 2000 tokens for this address");
		})

	});

	it("should be able to withdraw tokens", function () {
		var myExchangeInstance;
		var myTokenInstance;
		var balancedTokenInExchangeBeforeWithdrawal;
		var balancedTokenInTokenBeforeWithdrawal;
		var balancedTokenInExchangeAfterWithdrawal;
		var balancedTokenInTokenAfterWithdrawal;

		return fixedSupplyToken.deployed().then(function (instance) {
			myTokenInstance = instance;
			return instance;
		}).then(function (tokenInstance) {
			myTokenInstance = tokenInstance;
			return exchange.deployed();
		}).then(function (exchangeInstance) {
			myExchangeInstance = exchangeInstance;
			return myExchangeInstance.getBalance.call("FIXED");
		}).then(function (balanceExchange) {
			balancedTokenInExchangeBeforeWithdrawal = balanceExchange.toNumber();
			return myTokenInstance.balanceOf.call(accounts[0]);
		}).then(function (balanceToken) {
			balancedTokenInTokenBeforeWithdrawal = balanceToken.toNumber();
			return myExchangeInstance.withdrawToken("FIXED", balancedTokenInExchangeBeforeWithdrawal);
		}).then(function (txResult) {
			return myExchangeInstance.getBalance.call("FIXED");
		}).then(function (balanceExchange) {
			balancedTokenInExchangeAfterWithdrawal = balanceExchange.toNumber();
			return myTokenInstance.balanceOf(accounts[0]);
		}).then(function (balanceToken) {
			balancedTokenInTokenAfterWithdrawal = balanceToken.toNumber();
			assert.equal(balancedTokenInExchangeAfterWithdrawal, 0, "There should be 0 tokens left in the exchange");
			assert.equal(balancedTokenInTokenAfterWithdrawal, balancedTokenInTokenBeforeWithdrawal + balancedTokenInExchangeBeforeWithdrawal, "The total amount of tokens should be equal to the inital amount");
		})

	})


});