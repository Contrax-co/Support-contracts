// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./interfaces/IContraxMintableERC20.sol";
import './interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


/**
* @title LGERC20. An ERC20 variant with Uniswap LGE features
* @author Carson Case (carsonpcase@gmail.com) 
 */
contract LGE is Ownable{
    /* =====Events=====*/
    event ethRaised(address,uint256);

    /* =====State Variables=====*/
    bool public immutable isWhitelist;
    uint256 public immutable LGESupply;
    uint256 public totalETHContributed;
    uint256 public immutable endTime;
    address public immutable  LPTokenReceiver;
    IContraxMintableERC20 public token;
    bool public LGEComplete = false;

    /*=====Data Structures=====*/
    mapping(address => uint256) public contributers;
    mapping(address => bool) public whitelist;
    address[] public contributerList;

    /*=====Interfaces=====*/
    IUniswapV2Router02 public immutable UniswapV2Router02;
    
    /*=====Constructor=====*/
    constructor(
    bool    _isWhielist,                    //->true if whitelist on who can contribute
    address _token,                         //->ERC20 token
    uint256 _LGESupply,                     //->ERC20 Tokens to be minted for LGE
    address _UniswapV2Router02,             //->Address of Uniswap Router             
    address _LPTokenReceiver,               //->Address of the recipitent of Liquidity tokens      
    uint256 _endTime                        //->End time for LGE 
    )              
    Ownable()
    {
        isWhitelist = _isWhielist;
        UniswapV2Router02 = IUniswapV2Router02(_UniswapV2Router02);     //Initialize Uniswap router
        LGESupply = _LGESupply;                                         //Note tokens to be sent off in LGE
        token = IContraxMintableERC20(_token);
        token.mint(address(this),_LGESupply);                                //Mint those tokens to contract
        LPTokenReceiver = _LPTokenReceiver;                             //LP Token receiver
        endTime = _endTime;                                             //End time
    }

    /**
    * @dev receive function is how you contribute. Can only do when LGE is on
     */
    receive() payable external{
        if(isWhitelist){
            require(whitelist[msg.sender], "You are not permitted to participate in this LGE");
        }
        require(!_isOver());                                                        //Require LGE is still going on
        emit ethRaised(msg.sender,msg.value);
        totalETHContributed += msg.value;                                           //Increase total value of ETH raised
        contributerList.push(msg.sender);                                           //Push to list of contributers                                           
        contributers[msg.sender] = msg.value;                                       //Note how much was contributed
    }   

    /**
    * @dev function to add an array of addresses to the whitelist or remove them
    * @param _setStatus should be true if the users are to be whitelisted, and false if the users are to be blacklisted
     */
    function updateWhitelist(address[] memory _list, bool _setStatus)external onlyOwner{
        require(isWhitelist, "This is not a whitelist LGE");
        for(uint i = 0; i < _list.length; i++){
            whitelist[_list[i]] = _setStatus;
        }
    }

    /**
    * @dev sweep function removes tokens in contract and sends em to owner
    * @notice sweep can only be prefomed after LGE so as to aleviate rug concerns
    * function is mostly for tokens sent by mistake, or for things with LP tokens
    * @param _token to sweep
     */
    function sweep(address _token) external onlyOwner{
        require(_isOver(), "LGE must be complete");
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(owner(), bal);
    }
    /**
    * @dev at end of LGE the liquidity is sent to uniswap
    * @param _timeout is the uniswap addLiquidityEth timeout param (30 usually works for me)
     */
    function endLGE(uint256 _timeout) public{
        //requires
        require(_isOver());                                                         //Require LGE is over
        require(!LGEComplete);                                                      //Require LGE is not already completed
        LGEComplete = true;                                                         //Set LGE to complete

        token.approve(address(UniswapV2Router02),LGESupply);                         //Approve LGE tokens to be sent off

        UniswapV2Router02.addLiquidityETH                                           //Send the liquidity to Uniswap
        {value:address(this).balance}                                               //Ammount of ETH to send
        (             
            address(this),                                                          //Address of non-eth token
            LGESupply,                                                              //Ammount of tokens
            0,  //For these refer to                                                                    
            0,  //Uniswap docs
            LPTokenReceiver,                                                        //Recipitent of tokens
            block.timestamp+_timeout);                                                          //Timeout to revert
       
    }

    /**
    * @dev returns true if LGE is over 
    */
    function _isOver() private view returns(bool){
        if(block.timestamp >= endTime){
            return true;
        }else{
            return false;
        }
    }

}