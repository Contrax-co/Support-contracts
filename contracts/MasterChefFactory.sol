// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MasterChef.sol";

contract BuilderFactory{
    event NewChef(address newChefAddress);
    constructor(){}

    function buildChef(address _token, uint _coinPerBlock, uint _startBlock, uint _bonusEndBlock)external returns(address){
        MasterChef chef = new MasterChef(_token, msg.sender, _coinPerBlock, _startBlock, _bonusEndBlock);
        emit NewChef(address(chef));
        return(address(chef));
    }
}