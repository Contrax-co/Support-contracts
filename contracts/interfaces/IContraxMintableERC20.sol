// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IContraxMintableERC20 is IERC20{
    function mint(address _who, uint _amount)external;
}