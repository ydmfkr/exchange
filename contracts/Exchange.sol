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
    event WithdrawalToken(uint indexed _symbolIndex, uint _amount, uint _priceInWei, uint _timestamp);
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
    event TokenAddedToSystem(uint _symbolIndex, uint _token, uint _timestamp);

    //////////////////////////////////
    // DEPOSIT AND WITHDRAWAL ETHER //
    //////////////////////////////////

    function depositEther() payable {
        require(balanceEthForAddress[msg.sender] + msg.value >= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] += msg.value;

    }

    function withdrawEther(uint amountInWei){
        require(balanceEthForAddress[msg.sender] - amountInWei >= 0);
        require(balanceEthForAddress[msg.sender] - amountInWei <= balanceEthForAddress[msg.sender]);
        balanceEthForAddress[msg.sender] -= amountInWei;
        msg.sender.transfer(amountInWei);
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

    }

    function withdrawToken(string symbolName, uint amount) {

        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        ERC20Interface token = ERC20Interface(tokens[symbolNameIndex].tokenContract);

        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] - amount >= 0);
        require(tokenBalanceForAddress[msg.sender][symbolNameIndex] - amount <= tokenBalanceForAddress[msg.sender][symbolNameIndex]);

        tokenBalanceForAddress[msg.sender][symbolNameIndex] -= amount;
        require(token.transfer(msg.sender, amount) == true);

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
        uint[] memory arrayVolumesBuy = new unit[](tokens[tokenIndex].amountBuyPrices);

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

        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);

        uint total_amount_ether_necessary = 0;
        uint total_amount_ether_available = 0;

        //if we have enough ether we can buy that token
        total_amount_ether_necessary = priceInWei * amount;

        //overflow check
        require(total_amount_ether_necessary >= amount);
        require(total_amount_ether_necessary >= priceInWei);
        require(balanceEthForAddress[msg.sender] >= total_amount_ether_necessary);
        require(balanceEthForAddress[msg.sender] - total_amount_ether_necessary >= 0);

        //first deduct the amount of ether from our balance
        balanceEthForAddress[msg.sender] -= total_amount_ether_necessary;


        if (tokens[tokenNameIndex].amountSellPrice == 0 || tokens[tokenNameIndex].currentSellPrice > priceInWei) {
            //limit orders: we dont have enough offers to fulfill the request


            //add the order to the orderBook
            addBuyOffer(tokenNameIndex, priceInWei, amount, msg.sender);

            //and emit the event
            LimitBuyOrderCreated(tokenNameIndex, msg.sender, amountInWei, tokens[tokenNameIndex].buyBook[priceInWei].offers_length);
        } else {
            //market order: current sell price is smaller or equal to the buy price
            revert();
        }

    }


    ///////////////////////////
    // BID LIMIT ORDER LOGIC //
    ///////////////////////////

    function addBuyOffer(uint8 tokenIndex, uint priceInWei, uint amount, address who) internal {

        tokens[tokenIndex].buyBook[priceInWei].offers_length++;
        tokens[tokenIndex].buyBook[priceInWei].offers[tokens[tokenIndex].buyBook[priceInWei].offers_length] = Offer(amount, priceInWei);

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
                    tokens[tokenIndex].buyBook[priceInWei].higherPrice = lowestBuyPrice;
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

        uint8 tokenNameIndex = getTokenIndexOrThrow(symbolName);

        uint total_amount_eth_available = 0;
        uint total_amount_eth_necessary = 0;

        //if we have enough ether, we can buy the tokens
        total_amount_eth_necessary = priceInWei * amount;

        //overflow check
        require(total_amount_eth_necessary >= amount);
        require(total_amount_eth_necessary >= priceInWei);
        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] >= amount);
        require(tokenBalanceForAddress[msg.sender][tokenNameIndex] - amount >= 0);
        require(balanceEthForAddress[msg.sender] + total_amount_eth_necessary >= balanceEthForAddress[msg.sender]);

        //subtract the amount of tokens from the address
        tokenBalanceForAddress[msg.sender][tokenNameIndex] -= amount;

        if (tokens[tokenNameIndex].amountBuyPrices == 0 || tokens[tokenNameIndex].currentBuyPrice < priceInWei) {
            //limit order : we don't have enough offers to fulfill this order requirement

            // add the order to the order book
            addSellOffer(tokenNameIndex, priceInWei, amount, msg.sender);

            // emit the Event
            LimitSellOrderCreated(tokenNameIndex, msg.sender, amount, priceInWei, tokens[tokenNameIndex].sellBook[priceInWei].offers_length);

        } else {

            revert();

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



    }


    function Exchange(){

    }
}
