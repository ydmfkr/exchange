pragma solidity ^0.4.0;

contract owner {

    address owner;

    modifier onlyOwner(){
        if(msg.sender == owner){
            _;
        }
    }

    function owner(){
        owner = msg.sender;
    }
}
