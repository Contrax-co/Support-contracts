// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MasterChef.sol";
import "./TokenBar.sol";

contract SupportFactory{
    /**
    * @dev events
     */
    event NewChef(address newChefAddress);
    event NewBar(address newBarAddress);

    address public immutable uniswapV2Router;

    constructor(address _uniRouter){
        uniswapV2Router = _uniRouter;
    }

    /**
    * @dev build a mastercheft contract
    * @notice the caller of the function is the owner and dev
    * @param _token is the token to chef.
    * @notice _token must give this chef contract minting permission
    * @param _coinPerBlock is the coins to mint in TOTAl across ALL farms per block
    * @param _startBlock is the start of farming
    * @param _bonusEndBlock is the end of 10x bonus farming rewards
    * @return the address of the chef
     */
    function buildChef(address _token, uint _coinPerBlock, uint _startBlock, uint _bonusEndBlock)external returns(address){
        MasterChef chef = new MasterChef(_token, msg.sender, _coinPerBlock, _startBlock, _bonusEndBlock);
        emit NewChef(address(chef));
        return(address(chef));
    }

    /**
    * @dev builds a token bar complete with a sweep function
    * @param _token the token to store in the bar and sweep to
    * @return the address of the bar
     */
    function buildBar(address _token) external returns(address){
        TokenBar bar = new TokenBar(_token, uniswapV2Router);
        emit NewBar(address(bar));
        return(address(bar));
    }
}