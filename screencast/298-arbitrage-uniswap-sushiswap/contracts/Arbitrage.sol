pragma solidity ^0.6.6;

import './UniswapV2Library.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IERC20.sol';

contract Arbitrage {
  address public factory; //info about diff liquidity pools in exchange
  uint constant deadline = 10 days;
  IUniswapV2Router02 public sushiRouter; //central smart contract in sushiswap ecosystem that is used to execute trades in sushiswap liquidity pools

  constructor(address _factory, address _sushiRouter) public {
    factory = _factory;  
    sushiRouter = IUniswapV2Router02(_sushiRouter);
  }

  /*
     The method we call when we spot price differences in different exchanges 
  */
  function startArbitrage(address token0, address token1, uint amount0, uint amount1) external 
  {
    //the address of the pair smart-contract of uniswap for the two tokens
    //the token order in the parameters doesn't matter
    address pairAddress = IUniswapV2Factory(factory).getPair(token0, token1);
    
    //this line makes sure the pair smartcontract actually exists 
    //the pair smartcontract is the liquidity pool of uniswap where the trading actually happens
    require(pairAddress != address(0), 'This pool does not exist');
    
    //this line initiates the flash loan
    //one of the 'amounts' = 0; if one of the 'amounts' !=0 then it's the amount of the token you want to borrow
    //the 'address(this)' is the address of where we want to receive the token that we borrow
     IUniswapV2Pair(pairAddress).swap( amount0, amount1, address(this), bytes('not empty') ); 
     
    }

  /*
      @params: 
              _sender => the address that triggered the flashloan
              _amounts => one of the 'amounts' = 0;;;  if one of the 'amounts' != 0 then it's the amount of the token you want to borrow
              
  */
  function uniswapV2Call(address _sender, uint _amount0, uint _amount1, bytes calldata _data) external 
  {
    address[] memory path = new address[](2);
    
    //the amount of token that we borrowed - can be amount0 or amount1 - one of them = 0
    uint amountToken = _amount0 == 0 ? _amount1 : _amount0;
    
    //addresses of the two tokens in the liquidity pool of uniswap 
    address token0 = IUniswapV2Pair(msg.sender).token0();
    address token1 = IUniswapV2Pair(msg.sender).token1();

    //make sure the call comes from one of the pair contracts of Uniswap 
    require( msg.sender == UniswapV2Library.pairFor(factory, token0, token1), 'Unauthorized'); 
    
    //make sure one of the amounts = 0
    require(_amount0 == 0 || _amount1 == 0);

  
    /*
        populate the path array of the addresses - Here we define the direction of the trade 
    */
    path[0] = _amount0 == 0 ? token1 : token0; //if _amount0 = 0, then we are seling token1 for token0 ON SUSHISWAP 
    path[1] = _amount0 == 0 ? token0 : token1;

    IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);
    
    token.approve(address(sushiRouter), amountToken);

    uint amountRequired = UniswapV2Library.getAmountsIn(
      factory, 
      amountToken, 
      path
    )[0];
    uint amountReceived = sushiRouter.swapExactTokensForTokens(
      amountToken, 
      amountRequired, 
      path, 
      msg.sender, 
      deadline
    )[1];

    IERC20 otherToken = IERC20(_amount0 == 0 ? token0 : token1);
    otherToken.transfer(msg.sender, amountRequired);
    otherToken.transfer(tx.origin, amountReceived - amountRequired);
  }
}
