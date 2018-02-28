var fixedSupplyToken = artifacts.require("./FixedSupplyToken.sol");


contract('MyToken', function (accounts) {

    it("first account should own all tokens", function () {
        var _totalSupply;
        var myTokenInststance;
        return fixedSupplyToken.deployed().then(function (instance) {
            myTokenInststance = instance;
            return myTokenInststance.totalSupply.call();
        }).then(function (totalSupply) {
            _totalSupply = totalSupply;
            return myTokenInststance.balanceOf(accounts[0])
        }).then(function (balanceAccountOwner) {
            assert.equal(balanceAccountOwner.toNumber(), _totalSupply, "Total Amount of Tokens is owned by Owner");
        })
    });

    it("Only First account has all the tokens, checking for the second account", function () {
        var myTokenInstance;
        return fixedSupplyToken.deployed().then(function (instance) {
            myTokenInstance = instance;
            return myTokenInstance.balanceOf(accounts[1])
        }).then(function (accountBalance) {
            assert.equal(accountBalance.toNumber(), 0, "Total Amount of Tokens is owned by some other address");
        })
    });

    it("should correctly send tokens", function () {
        var token;
        var account_one = accounts[0];
        var account_two = accounts[1];
        var account_one_starting_balance;
        var account_two_starting_balance;
        var account_one_ending_balance;
        var account_two_ending_balance;

        var amount = 10;

        return fixedSupplyToken.deployed().then(function (instance) {
            token = instance;
            return token.balanceOf.call(account_one);
        }).then(function (balance) {
            account_one_starting_balance = balance.toNumber();
            return token.balanceOf.call(account_two);
        }).then(function (balance) {
            account_two_starting_balance = balance.toNumber();
            return token.transfer(account_two, amount, {from: account_one});
        }).then(function () {
            return token.balanceOf.call(account_one)
        }).then(function (balance) {
            account_one_ending_balance = balance.toNumber();
            return token.balanceOf.call(account_two);
        }).then(function (balance) {
            account_two_ending_balance = balance.toNumber();
            assert.equal(account_one_ending_balance, account_one_starting_balance - amount, "Amount wasnt Correctly Taken from the sender");
            assert.equal(account_two_ending_balance, account_two_starting_balance + amount, "Amount  wanst Correctly sent to the reciever");
        })
    })


});