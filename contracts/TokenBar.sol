// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Swap.sol";

// TokenBar is the coolest bar in town. You come in with some Token, and leave with more! The longer you stay, the more Token you get.
//
// This contract handles swapping to and from xToken, the staking token.
contract TokenBar is ERC20, Swap{
    IERC20 public token;

    // Define the Token token contract
    constructor(IERC20 _token, address _uniV2Router) ERC20("TokenBar", "xTOKEN") Swap(address(msg.sender), _uniV2Router){
        token = _token;
    }

    // Enter the bar. Pay some TOKENs. Earn some shares.
    // Locks Token and mints xToken
    function enter(uint256 _amount) public {
        // Gets the amount of Token locked in the contract
        uint256 totalToken = token.balanceOf(address(this));
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // If no xToken exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalToken == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xToken the Token is worth. The ratio will change overtime, as xToken is burned/minted and Token deposited + gained from fees / withdrawn.
        else {
            uint256 what = (_amount * totalShares) / (totalToken);
            _mint(msg.sender, what);
        }
        // Lock the Token in the contract
        token.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your TOKENs.
    // Unlocks the staked + gained Token and burns xToken
    function leave(uint256 _share) public {
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Token the xToken is worth
        uint256 what = (_share * token.balanceOf(address(this))) / (totalShares);
        _burn(msg.sender, _share);
        token.transfer(msg.sender, what);
    }

    /// @dev if address = 0x0 then sweep ETH
    function sweep(address _token)external{
        require(!inSwapAndLiquify, "Contract is already busy swaping... Please wait");
        if(_token == address(0)){
            _swapEthForTokens(address(this).balance, address(token));
        }else{
            //swap the _token balance of this contract for token
            _swapTokensForTokens(IERC20(_token).balanceOf(address(this)), _token, address(token));
        }
    }
}
