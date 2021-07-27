// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Swap{

    IUniswapV2Router02 immutable uniRouter;
    address lpReveiver;
    bool inSwapAndLiquify = false;

    constructor(address _lpReceiver, address _uniRouter){
        uniRouter = IUniswapV2Router02(_uniRouter);
        lpReveiver = _lpReceiver;
    }

    modifier lockTheSwap {
            inSwapAndLiquify = true;
            _;
            inSwapAndLiquify = false;
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    /// @dev swaps half of tokens in contract for eth and combine with the other half for liquidity
    function _swapAndLiquify(uint256 contractTokenBalance, address _token) internal virtual lockTheSwap {
        // split the contract balance into halfs
        uint256 halfOfLiquify = contractTokenBalance / 2;
        uint256 otherHalfOfLiquify = contractTokenBalance - halfOfLiquify;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        _swapTokensForEth(halfOfLiquify, _token); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - (initialBalance);

        // add liquidity to uniswap
        _addLiquidityEth(otherHalfOfLiquify, newBalance, _token);
    }

    /// @dev swaps tokens for eth and sends that eth to the contract
    function _swapTokensForEth(uint256 tokenAmount, address _token) internal virtual{
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(_token);
        path[1] = uniRouter.WETH();

        IERC20(_token).approve(address(uniRouter), tokenAmount);

        // make the swap
        uniRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /// @dev swap eth for tokens
    function _swapEthForTokens(uint ethAmount, address _token) internal virtual{
        address[] memory path = new address[](2);
        path[0] = uniRouter.WETH();
        path[1] = address(_token);

        // make the swap
        uniRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value:ethAmount}(
            0,
            path,
            address(this),
            block.timestamp
        );
       
    }

    /// @dev swaps tokens for tokens
    function _swapTokensForTokens(uint tokenAmount, address _tokenA, address _tokenB) internal virtual{
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](3);
        path[0] = address(_tokenA);
        path[1] = uniRouter.WETH();
        path[2] = address(_tokenB);

        IERC20(_tokenA).approve(address(uniRouter), tokenAmount);

        // make the swap
        uniRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

    }

    /// @dev adds liquidity to uniswap of eth and token
    function _addLiquidityEth(uint256 tokenAmount, uint256 ethAmount, address _token) internal virtual{
        // approve token transfer to cover all possible scenarios
        IERC20(_token).approve(address(uniRouter), tokenAmount);

        // add the liquidity
        uniRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lpReveiver,
            block.timestamp
        );
    }
}
