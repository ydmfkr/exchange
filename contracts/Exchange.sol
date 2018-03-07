pragma solidity ^0.4.0;

import './owned.sol';
import './FixedSupplyToken.sol';


contract Exchange is owned {


    ///////////////////////
    // GENERAL STRUCTURE //
    ///////////////////////
    struct Offer {
        uint amount;
        address who;
    }

    struct OrderBook {

        uint higherPrice;
        uint lowerPrice;

        mapping(uint => Offer) offers;

        uint offers_key;
        uint offers_length;

    }

    struct Token {

        address tokenContract;
        string symbolName;

        mapping(uint => OrderBook) buyBook;

        uint currentBuyPrice;
        uint lowestBuyPrice;
        uint amountBuyPrices;

        mapping(uint => OrderBook) sellBook;

        uint currentSellPrice;
        uint highestSellPrice;
        uint amountSellPrices;

    }

    //support max 255 tokens
    mapping(uint8 => Token) tokens;
    uint8 symbolNameIndex;

    //////////////
    // BALANCES //
    //////////////
    mapping(address => mapping(uint8 => uint)) tokenBalanceForAddress;
    mapping(address => uint) balanceEthForAddress;

    ////////////
    // EVENTS //
    ////////////

    // Events For Deposit/Withdrawal

    event DepositForTokenReceived(address indexed _from, uint indexed _symbolIndex, uint _amount, uint _timestamp);
    event WithdrawalToken(address indexed _to, uint _symbolIndex, uint _amount, uint _timestamp);
    event DepositForEthReceived(address indexed _from, uint _amount, uint _timestamp);
    event WithdrawalEth(address indexed _to, uint _amount, uint _timestamp);

    //Events For Orders

    event LimitSellOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _ordeyKey);
    event SellOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);
    event SellOrderCanceled(uint indexed _symbolIndex, uint _priceInWei, uint _orderKey);
    event LimitBuyOrderCreated(uint indexed _symbolIndex, address indexed _who, uint _amountTokens, uint _priceInWei, uint _orderKey);
    event BuyOrderFulfilled(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _orderKey);
    event BuyOrderCanceled(uint _symbolIndex, uint _priceInWei, uint _orderKey);

    //Events For Management
    event TokenAddedToSystem(uint _symbolIndex, string _token, uint _timestamp);

    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL ETHER //
    //////////////////////////////////

    function depositEther() payable {
        require(balanceEthForAddress[msg.sender] + msg.value >= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] += msg.value;
        DepositForEthReceived(msg.sender, msg.value, now);
    }

    function withdrawEther(uint amountInWei){
        require(balanceEthForAddress[msg.sender] - amountInWei >= 0);
        require(balanceEthForAddress[msg.sender] - amountInWei <= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] -= amountInWei;
        msg.sender.transfer(amountInWei);
        WithdrawalEth(msg.sender, amountInWei, now);
    }

    function getEthBalanceInWei() constant returns (uint){

        return balanceEthForAddress[msg.sender];

    }

    //////////////////////
    // TOKEN MANAGEMENT //
    //////////////////////

    function addToken(string symbolName, address erc20TokenAddress) onlyOwner {
        require(!hasToken(symbolName));
        symbolNameIndex++;
        tokens[symbolNameIndex].symbolName = symbolName;
        tokens[symbolNameIndex].tokenContract = erc20TokenAddress;
        TokenAddedToSystem(symbolNameIndex, symbolName, now);
    }

    function hasToken(string symbolName) constant returns (bool){
        uint8 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function getSymbolIndex(string symbolName) internal returns (uint8){
        for (uint8 i = 1; i <= symbolNameIndex; i++) {
            if (stringEquals(tokens[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function getSymbolIndexOrThrow(string symbolName) returns (uint8){
        uint8 index = getSymbolIndex(symbolName);
        require(index > 0);
        return index;
    }

    /////////////////////////////////
    // STRING COMPARISON FUNCTION  //
    /////////////////////////////////

    function stringEquals(string storage _a, string memory _b) internal returns (bool){
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);
        if (a.length != b.length)
            return false;
        for (uint i = 0; i < a.length; i++)
            if (a[i] != b[i])
                return false;

        return true;
    }
    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL TOKEN //
    //////////////////////////////////
    function depositToken(string symbolName, uint amount) {

        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[symbolNameIndex].tokenContract);

        require(token.transferFrom(msg.sender, address(this), amount) == true);
        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] + amount >= tokenBalanceForAddress[msg.sender][symbolNameIndex]);
        tokenBalanceForAddress[msg.sender][symbolNameIndex] += amount;
        DepositForTokenReceived(msg.sender, symbolNameIndex, amount, now);
    }

    function withdrawToken(string symbolName, uint amount) {

        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[symbolNameIndex].tokenContract);

        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] - amount >= 0);
        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] - amount <= tokenBalanceForAddress[msg.sender][symbolNameIndex]);

        tokenBalanceForAddress[msg.sender][symbolNameIndex] -= amount;
        require(token.transfer(msg.sender, amount) == true);
        WithdrawalToken(msg.sender, symbolNameIndex, amount, now);
    }

    function getBalance(string symbolName) constant returns (uint) {

        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][symbolNameIndex];

    }

    /////////////////////////////
    // ORDER BOOK - BID ORDERS //
    /////////////////////////////
    function getBuyOrderBook(string symbolName) constant returns (uint[], uint[]) {

        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);
        uint[] memory arrayBuyPrices = new uint[](tokens[tokenIndex].amountBuyPrices);
        uint[] memory arrayVolumesBuy = new uint[](tokens[tokenIndex].amountBuyPrices);

        uint whilePrice = tokens[tokenIndex].lowestBuyPrice;
        uint counter = 0;
        if (tokens[tokenIndex].currentBuyPrice > 0) {
            while (whilePrice <= tokens[tokenIndex].currentBuyPrice) {
                arrayBuyPrices[counter] = whilePrice;
                uint volumeAtPrice = 0;
                uint offers_key = 0;

                offers_key = tokens[tokenIndex].buyBook[whilePrice].offers_key;
                while (offers_key <= tokens[tokenIndex].buyBook[whilePrice].offers_length) {
                    volumeAtPrice += tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].amount;
                    offers_key++;
                }

                arrayVolumesBuy[counter] = volumeAtPrice;

                //next whilePrice
                if (whilePrice == tokens[tokenIndex].buyBook[whilePrice].higherPrice) {
                    break;
                } else {
                    whilePrice = tokens[tokenIndex].buyBook[whilePrice].higherPrice;
                }
                counter++;
            }
        }
        return (arrayBuyPrices, arrayVolumesBuy);

    }


    /////////////////////////////
    // ORDER BOOK - ASK ORDERS //
    /////////////////////////////
    function getSellOrderBook(string symbolName) constant returns (uint[], uint[]) {

        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);
        uint[] memory arraySellPrices = new uint[](tokens[tokenIndex].amountSellPrices);
        uint[] memory arrayVolumesSell = new uint[](tokens[tokenIndex].amountSellPrices);

        uint whileSellPrice = tokens[tokenIndex].currentSellPrice;
        uint sellCounter = 0;

        if (tokens[tokenIndex].currentSellPrice > 0) {
            while (whileSellPrice <= tokens[tokenIndex].highestSellPrice) {
                arraySellPrices[sellCounter] = whileSellPrice;

                uint volumeAtCurrentSellPrice = 0;
                uint offers_key = 0;

                offers_key = tokens[tokenIndex].sellBook[whileSellPrice].offers_key;
                while (offers_key <= tokens[tokenIndex].sellBook[whileSellPrice].offers_length) {

                    volumeAtCurrentSellPrice += tokens[tokenIndex].sellBook[whileSellPrice].offers[offers_key].amount;
                    offers_key++;

                }

                arrayVolumesSell[sellCounter] = volumeAtCurrentSellPrice;

                //next whileSellPrice
                if (tokens[tokenIndex].sellBook[whileSellPrice].higherPrice == 0) {
                    break;
                } else {
                    whileSellPrice = tokens[tokenIndex].sellBook[whileSellPrice].higherPrice;
                }
                sellCounter++;
            }
        }

        return (arraySellPrices, arrayVolumesSell);
    }



    ////////////////////////////
    // NEW ORDER - BID ORDER //
    ///////////////////////////
    function buyToken(string symbolName, uint priceInWei, uint amount) {

        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);

        uint total_amount_ether_necessary = 0;

        //if we have enough ether we can buy that token
        total_amount_ether_necessary = priceInWei * amount;

        //overflow check
        require(total_amount_ether_necessary >= amount);
        require(total_amount_ether_necessary >= priceInWei);
        require(balanceEthForAddress[msg.sender] >= total_amount_ether_necessary);
        require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary >= 0);

        //first deduct the amount of ether from our balance
        balanceEthForAddress[msg.sender] -= total_amount_ether_necessary;


        if (tokens[tokenIndex].amountSellPrices == 0 || tokens[tokenIndex].currentSellPrice > priceInWei) {
            //limit orders: we don't have enough offers to fulfill the request


            //add the order to the orderBook
            addBuyOffer(tokenIndex, priceInWei, amount, msg.sender);

            //and emit the event
            LimitBuyOrderCreated(tokenIndex, msg.sender, amount, priceInWei, tokens[tokenIndex].buyBook[priceInWei].offers_length);
        } else {
            //market order: current sell price is smaller or equal to the buy price

            //first find the cheapest sell price that is lower than the buy price [buy: 60@5000] [sell: 50@4500] [sell: 5@5000]
            // it first buys into the sellBook of 50@4500
            // then it buys into the sellBook of 5@5000
            // finally if something is remaining => buyToken() function is executed

            // buy up the volume
            // add ether to seller, add symbolName to buyer until offers_key <= offers_length

            uint total_amount_ether_available = 0;
            uint whilePrice = tokens[tokenIndex].currentSellPrice;
            uint amountNecessary = amount;
            uint offers_key;
            //we start with the smallest sellPrice and work our way down the book
            while (whilePrice <= priceInWei && amountNecessary > 0) {
                offers_key = tokens[tokenIndex].sellBook[whilePrice].offers_key;
                //since each price can have different sellers, we loop through the stack(FIFO)
                while (offers_key <= tokens[tokenIndex].sellBook[whilePrice].offers_length && amountNecessary > 0) {
                    uint volumeAtPriceFromAddress = tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].amount;

                    //two choices from here
                    //either the person having the ask order does not has enough volume to fulfill the market order - we use it completely and move on the the next offer in the stack
                    // else we make use of the fraction of the volume of the ask order - and then lower his amount and fulfill the market order
                    if (volumeAtPriceFromAddress <= amountNecessary) {
                        total_amount_ether_available = volumeAtPriceFromAddress * whilePrice;

                        //overflow check
                        require(balanceEthForAddress[msg.sender] >= total_amount_ether_available);
                        require(balanceEthForAddress[msg.sender] - total_amount_ether_available <= balanceEthForAddress[msg.sender]);

                        //deduct the amount of ether from the balance
                        balanceEthForAddress[msg.sender] -= total_amount_ether_available;

                        //overflow check
                        require(tokenBalanceForAddress[msg.sender][tokenIndex] + volumeAtPriceFromAddress >= tokenBalanceForAddress[msg.sender][tokenIndex]);
                        require(balanceEthForAddress[tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].who] + total_amount_ether_available >= balanceEthForAddress[tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].who]);

                        //since this if statement is only if the market orders volume is more than the ask offer in the orderBook
                        tokenBalanceForAddress[msg.sender][tokenIndex] += volumeAtPriceFromAddress;
                        tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].amount = 0;
                        balanceEthForAddress[tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].who] += total_amount_ether_necessary;
                        tokens[tokenIndex].sellBook[whilePrice].offers_key++;

                        SellOrderFulfilled(tokenIndex, volumeAtPriceFromAddress, whilePrice, offers_key);
                        amountNecessary -= volumeAtPriceFromAddress;

                    } else {
                        //just for our sake
                        require(tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].amount > amountNecessary);

                        total_amount_ether_necessary = amountNecessary * whilePrice;
                        //overflow check
                        require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary <= balanceEthForAddress[msg.sender]);

                        //first deduct the amount of ether from the balance
                        balanceEthForAddress[msg.sender] -= total_amount_ether_necessary;

                        //overflow check
                        require(balanceEthForAddress[tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].who] + total_amount_ether_necessary >= balanceEthForAddress[tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].who]);
                        //the market order volume is lesser than the ask volume, so we reduce the stack, add the tokens and deposit the ether
                        tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].amount -= amountNecessary;
                        balanceEthForAddress[tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].who] += total_amount_ether_necessary;
                        tokenBalanceForAddress[msg.sender][tokenIndex] += amountNecessary;


                        //since we have fulfilled our market sell order
                        SellOrderFulfilled(tokenIndex, amountNecessary, whilePrice, offers_key);

                        amountNecessary = 0;

                    }
                    //if it was the last offer for the price, we have to set the currentSellPrice higher
                    if (offers_key == tokens[tokenIndex].sellBook[whilePrice].offers_length &&
                    tokens[tokenIndex].sellBook[whilePrice].offers[offers_key].amount == 0) {

                        //we will have one lesser sell order price
                        tokens[tokenIndex].amountSellPrices--;
                        //next whilePrice
                        if (whilePrice == tokens[tokenIndex].sellBook[whilePrice].higherPrice ||
                        tokens[tokenIndex].sellBook[whilePrice].higherPrice == 0) {
                            //we have reached the last sell price
                            tokens[tokenIndex].currentSellPrice = 0;
                        } else {
                            tokens[tokenIndex].currentSellPrice = tokens[tokenIndex].sellBook[whilePrice].higherPrice;
                            tokens[tokenIndex].sellBook[tokens[tokenIndex].sellBook[whilePrice].higherPrice].lowerPrice = 0;
                        }
                    }
                    offers_key++;
                }
                //we set the currentSellPrice again, since when the volume is used up for the lowest price the currentSellPrice is set there...
                whilePrice = tokens[tokenIndex].currentSellPrice;
            }
            if(amountNecessary>0){
                //add a limit order
                buyToken(symbolName, priceInWei, amountNecessary);
            }

        }

    }


    ///////////////////////////
    // BID LIMIT ORDER LOGIC //
    ///////////////////////////

    function addBuyOffer(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {

        tokens[tokenIndex].buyBook[priceInWei].offers_length++;
        tokens[tokenIndex].buyBook[priceInWei].offers[tokens[tokenIndex].buyBook[priceInWei].offers_length] = Offer(amount, who);

        if (tokens[tokenIndex].buyBook[priceInWei].offers_length == 1) {

            tokens[tokenIndex].buyBook[priceInWei].offers_key = 1;

            //we have a new buy order - increase the counter, so we can set the getOrderBook array later
            tokens[tokenIndex].amountBuyPrices++;

            //have to retrieve the lower and the higher prices in the linked list
            uint currentBuyPrice = tokens[tokenIndex].currentBuyPrice;
            uint lowestBuyPrice = tokens[tokenIndex].lowestBuyPrice;

            if (lowestBuyPrice == 0 || lowestBuyPrice > priceInWei) {

                if (currentBuyPrice == 0) {
                    // there's no buy order yet, we insert the first one
                    tokens[tokenIndex].currentBuyPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                } else {

                    //or the lowest one
                    tokens[tokenIndex].buyBook[lowestBuyPrice].lowerPrice = priceInWei;
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = lowestBuyPrice;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;

                }
                tokens[tokenIndex].lowestBuyPrice = priceInWei;


            } else if (currentBuyPrice < priceInWei) {

                //the offer to buy is the highest one, we don't need to find the right spot

                tokens[tokenIndex].buyBook[currentBuyPrice].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].lowerPrice = currentBuyPrice;
                tokens[tokenIndex].currentBuyPrice = priceInWei;

            } else {

                //we are somewhere in the middle, we need to find the right spot
                uint buyPrice = tokens[tokenIndex].currentBuyPrice;
                bool weFoundIt = false;
                while (buyPrice > 0 && !weFoundIt) {
                    if (buyPrice < priceInWei && tokens[tokenIndex].buyBook[buyPrice].higherPrice > priceInWei) {

                        // set the new order book entry higher/lower first right

                        tokens[tokenIndex].buyBook[priceInWei].lowerPrice = buyPrice;
                        tokens[tokenIndex].buyBook[priceInWei].higherPrice = tokens[tokenIndex].buyBook[buyPrice].higherPrice;

                        //set the higher priced  order book  entries lowerPrice  to the current price

                        tokens[tokenIndex].buyBook[tokens[tokenIndex].buyBook[buyPrice].higherPrice].lowerPrice = priceInWei;

                        //set the lower priced  order book  entries higherPrice  to the current price

                        tokens[tokenIndex].buyBook[buyPrice].higherPrice = priceInWei;

                        // set weFoundIt

                        weFoundIt = true;
                    }
                    buyPrice = tokens[tokenIndex].buyBook[buyPrice].lowerPrice;
                }
            }
        }
    }




    ////////////////////////////
    // NEW ORDER - ASK ORDER //
    ///////////////////////////
    function sellToken(string symbolName, uint priceInWei, uint amount) {

        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);

        uint total_amount_eth_available = 0;
        uint total_amount_eth_necessary = 0;

        //if we have enough ether, we can buy the tokens
        total_amount_eth_necessary = priceInWei * amount;

        //overflow check
        require(total_amount_eth_necessary >= amount);
        require(total_amount_eth_necessary >= priceInWei);
        require(tokenBalanceForAddress[msg.sender][tokenIndex] >= amount);
        require(tokenBalanceForAddress[msg.sender][tokenIndex] - amount >= 0);
        require(balanceEthForAddress[msg.sender] + total_amount_eth_necessary >= balanceEthForAddress[msg.sender]);

        //subtract the amount of tokens from the address
        tokenBalanceForAddress[msg.sender][tokenIndex] -= amount;

        if (tokens[tokenIndex].amountBuyPrices == 0 || tokens[tokenIndex].currentBuyPrice < priceInWei) {
            //limit order : we don't have enough offers to fulfill this order requirement

            // add the order to the order book
            addSellOffer(tokenIndex, priceInWei, amount, msg.sender);

            // emit the Event
            LimitSellOrderCreated(tokenIndex, msg.sender, amount, priceInWei, tokens[tokenIndex].sellBook[priceInWei].offers_length);

        } else {
            //market order: current buy price is more than or equal to the sell price

            //first we find the "highest buy price" that is higher than the  sell amount [buy: 60@5000] [buy: 50@4500] [sell: 500@4000]
            //second sell up the volume for 5000
            //third sell up the volume for 4500
            //if there are still some tokens left in the sell order, add it to the sellOrderBook

            //2: conversely if we sell up the whole volume
            // add ether to seller, add symbolName to buyer until offers_key <= offers_length

            uint whilePrice = tokens[tokenIndex].currentBuyPrice;
            uint amountNecessary = amount;
            uint offers_key;

            //we start with the highest buy price and work our way down the book
            while (whilePrice >= priceInWei && amountNecessary > 0) {
                offers_key = tokens[tokenIndex].buyBook[whilePrice].offers_key;
                //since each price can have different buyers, we need another while loop, to loop through the stack of buyers(FIFO)
                while (offers_key <= tokens[tokenIndex].buyBook[whilePrice].offers_length && amountNecessary > 0) {
                    uint volumeAtPriceFromAddress = tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].amount;

                    //two choices form here
                    // either the 1st persons volume is not enough to fulfill the market order - so we use it completely and move on to the next person
                    // or the 1st persons buy volume is equal to or more than the volume of the market order, so we deduct the required volume and fulfill the order
                    if (volumeAtPriceFromAddress <= amountNecessary) {

                        total_amount_eth_available = volumeAtPriceFromAddress * whilePrice;

                        //overflow check
                        require(tokenBalanceForAddress[msg.sender][tokenIndex] >= volumeAtPriceFromAddress);
                        //actually subtract the amount of tokens to change it
                        tokenBalanceForAddress[msg.sender][tokenIndex] -= volumeAtPriceFromAddress;

                        //overflow check
                        require(tokenBalanceForAddress[msg.sender][tokenIndex] - volumeAtPriceFromAddress >= 0);
                        require(tokenBalanceForAddress[tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].who][tokenIndex] + volumeAtPriceFromAddress >= tokenBalanceForAddress[tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].who][tokenIndex]);
                        require(balanceEthForAddress[msg.sender] + total_amount_eth_available >= balanceEthForAddress[msg.sender]);

                        //this persons bid volume is less than or equal to the ask offer, so we use it up completely
                        tokenBalanceForAddress[tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].who][tokenIndex] += volumeAtPriceFromAddress;
                        tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].amount = 0;
                        balanceEthForAddress[msg.sender] += total_amount_eth_available;
                        tokens[tokenIndex].buyBook[whilePrice].offers_key++;
                        SellOrderFulfilled(tokenIndex, volumeAtPriceFromAddress, whilePrice, offers_key);

                        amountNecessary -= volumeAtPriceFromAddress;
                    } else {
                        // just for sanity
                        require(volumeAtPriceFromAddress - amountNecessary > 0);
                        //we take the rest of the outstanding amount
                        total_amount_eth_necessary = amountNecessary * whilePrice;

                        //overflow check
                        require(tokenBalanceForAddress[msg.sender][tokenIndex] >= amountNecessary);
                        //actually subtract the amount of tokens from the sellers account
                        tokenBalanceForAddress[msg.sender][tokenIndex] -= amountNecessary;

                        //overflow check
                        require(balanceEthForAddress[msg.sender] + total_amount_eth_necessary >= balanceEthForAddress[msg.sender]);
                        require(tokenBalanceForAddress[tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].who][tokenIndex] + amountNecessary >= tokenBalanceForAddress[tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].who][tokenIndex]);

                        //the market order volume is not enough to fulfill the bid order volumes request. So we reduce his stack, add the eth to us and the symbolname to him
                        tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].amount -= amountNecessary;
                        balanceEthForAddress[msg.sender] += total_amount_eth_necessary;
                        tokenBalanceForAddress[tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].who][tokenIndex] += amountNecessary;

                        SellOrderFulfilled(tokenIndex, amountNecessary, whilePrice, offers_key);

                        amountNecessary = 0;
                        //we have fulfilled the market order

                    }

                    //if it was the last offer for the currentBuyPrice, we have to set the currentBuyPrice lower now. Additionally we have one offer lesser.....
                    if (offers_key == tokens[tokenIndex].buyBook[whilePrice].offers_length &&
                    tokens[tokenIndex].buyBook[whilePrice].offers[offers_key].amount == 0) {

                        tokens[tokenIndex].amountBuyPrices--;

                        //we have one lesser price offer here
                        // next whilePrice
                        if (whilePrice == tokens[tokenIndex].buyBook[whilePrice].lowerPrice ||
                        tokens[tokenIndex].buyBook[whilePrice].lowerPrice == 0) {

                            tokens[tokenIndex].currentBuyPrice = 0;
                            //we have reached the last price;
                        } else {
                            tokens[tokenIndex].currentBuyPrice = tokens[tokenIndex].buyBook[whilePrice].lowerPrice;
                            tokens[tokenIndex].buyBook[tokens[tokenIndex].buyBook[whilePrice].lowerPrice].higherPrice = tokens[tokenIndex].currentBuyPrice;

                        }


                    }
                    offers_key++;
                }
                //we set the currentBuyPrice again, since when the volume is used up for a highest price the currentBuyPrice is set there
                whilePrice = tokens[tokenIndex].currentBuyPrice;
            }
            if (amountNecessary > 0) {
                //add a limit order, we could'nt fulfill all the orders
                sellToken(symbolName, priceInWei, amountNecessary);
            }

        }

    }

    ///////////////////////////
    // ASK LIMIT ORDER LOGIC //
    ///////////////////////////

    function addSellOffer(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {
        tokens[tokenIndex].sellBook[priceInWei].offers_length++;
        tokens[tokenIndex].sellBook[priceInWei].offers[tokens[tokenIndex].sellBook[priceInWei].offers_length] = Offer(amount, who);

        if (tokens[tokenIndex].sellBook[priceInWei].offers_length == 1) {
            tokens[tokenIndex].sellBook[priceInWei].offers_key = 1;

            // we have a new sell order - increase the counter, so we can set the getOrderBook array later
            tokens[tokenIndex].amountSellPrices++;

            //lower and higher prices have to be set
            uint currentSellPrice = tokens[tokenIndex].currentSellPrice;

            uint highestSellPrice = tokens[tokenIndex].highestSellPrice;

            if (highestSellPrice == 0 || highestSellPrice < priceInWei) {

                if (currentSellPrice == 0) {

                    //there's no sell order yet, we will add the first one
                    tokens[tokenIndex].currentSellPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;

                } else {

                    //this is the highest Sell Price
                    tokens[tokenIndex].sellBook[highestSellPrice].higherPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = highestSellPrice;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;

                }

                tokens[tokenIndex].highestSellPrice = priceInWei;

            } else if (currentSellPrice > priceInWei) {

                // the current selling price is the lowest one, we don't need to find the right spot
                tokens[tokenIndex].sellBook[currentSellPrice].lowerPrice = priceInWei;
                tokens[tokenIndex].sellBook[priceInWei].higherPrice = currentSellPrice;
                tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                tokens[tokenIndex].currentSellPrice = priceInWei;


            } else {

                //somewhere in the middle, where in we need to find the right spot
                uint sellPrice = tokens[tokenIndex].currentSellPrice;

                bool weFoundIt = false;

                while (sellPrice > 0 && !weFoundIt) {
                    if (sellPrice < priceInWei && tokens[tokenIndex].sellBook[sellPrice].higherPrice > priceInWei) {

                        //set the new order's linked list pointers of higher/lower Price
                        tokens[tokenIndex].sellBook[priceInWei].lowerPrice = sellPrice;
                        tokens[tokenIndex].sellBook[priceInWei].higherPrice = tokens[tokenIndex].sellBook[sellPrice].higherPrice;

                        //set the higherPrices pointer(lowerPrice) to point to the current priceInWei
                        tokens[tokenIndex].sellBook[tokens[tokenIndex].sellBook[sellPrice].higherPrice].lowerPrice = priceInWei;
                        //set the currentSellPrice's pointer(higherPrice) to point to the current priceInWei
                        tokens[tokenIndex].sellBook[sellPrice].higherPrice = priceInWei;

                        weFoundIt = true;

                    }
                    sellPrice = tokens[tokenIndex].sellBook[sellPrice].higherPrice;
                }

            }

        }
    }


    //////////////////////////////
    // CANCEL LIMIT ORDER LOGIC //
    //////////////////////////////
    function cancelOrder(string symbolName, bool isSellOrder, uint priceInWei, uint offerKey) {

        uint8 tokenIndex = getSymbolIndexOrThrow(symbolName);

        if (isSellOrder) {

            require(tokens[tokenIndex].sellBook[priceInWei].offers[offerKey].who == msg.sender);

            uint tokenAmount = tokens[tokenIndex].sellBook[priceInWei].offers[offerKey].amount;
            require(tokenBalanceForAddress[msg.sender][tokenIndex] + tokenAmount >= tokenBalanceForAddress[msg.sender][tokenIndex]);

            tokenBalanceForAddress[msg.sender][tokenIndex] += tokenAmount;
            tokens[tokenIndex].sellBook[priceInWei].offers[offerKey].amount = 0;
            SellOrderCanceled(symbolNameIndex, priceInWei, offerKey);

        } else {

            require(tokens[tokenIndex].buyBook[priceInWei].offers[offerKey].who == msg.sender);

            uint tokenAmounts = tokens[tokenIndex].buyBook[priceInWei].offers[offerKey].amount;
            uint etherToRefund = priceInWei * tokenAmounts;
            require(balanceEthForAddress[msg.sender] + etherToRefund >= balanceEthForAddress[msg.sender]);

            balanceEthForAddress[msg.sender] += etherToRefund;
            tokens[tokenIndex].buyBook[priceInWei].offers[offerKey].amount = 0;
            BuyOrderCanceled(tokenIndex, priceInWei, offerKey);

        }

    }


    function Exchange(){

    }
}
