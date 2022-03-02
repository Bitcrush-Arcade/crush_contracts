// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import './GalacticChef.sol';

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}
interface IPancakeRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

contract FeeDistributor is Ownable{
  using SafeERC20 for ERC20Burnable;
  using SafeERC20 for IERC20;

  struct FeeData{
    uint buyback;
    uint liquidity;
    uint team;
    bool[2] tokenToUse;
    /**
      if it's an LP token we can definitely burn it to get the contained tokens
      else it's a Single asset token and have to swap it for base eth token 
      before buying anything else.
     tokenToUse[0] token to buyback and burn
      is it CRUSH (false) or NICE (true)
     tokenToUse[1] token to get liquidity for
      is it CRUSH/BNB(false) or NICE/BNB (true)
    **/
    IPancakeRouter router; // main router for this token
    address[] tokens; // Tokens to swap to/from to get to wBNB
    address[] token0path; // maybe it wont be necessary
    address[] token1path; // maybe it wont be necessary
  }
  address public immutable baseToken; // wBNB || wETH || etc
  address[] public crushPath; // [0]wBNB to [1]CRUSH
  address[] public nicePath; // [0]wBNB to [1]NICE
  address public crushLiquidity; // for swapping / adding Liquidity
  address public niceLiquidity; // for swapping / adding Liquidity
  address public immutable deadWallet = 0x000000000000000000000000000000000000dEaD;
  IPancakeRouter public tokenRouter;
  uint public immutable idoPrice;
  address public teamWallet;


  uint constant public DIVISOR = 10000;
  GalacticChef public chef;

  mapping( uint => FeeData ) feeData;

  event AddPoolFee(uint indexed _pid);
  event EditFee(uint indexed _pid, uint bb, uint liq, uint team);
  event UpdateRouter(uint indexed _pid, address router);
  event UpdatePath(uint indexed _pid, address router);

  modifier onlyChef {
    require( msg.sender == address(chef), "onlyChef");
    _;
  }

  constructor(address _chef, address _baseWrapped, uint _idoPrice){
    chef = GalacticChef(_chef);
    baseToken = _baseWrapped;
    // _idoPrice must be NICE/BNB NOT BNB/NICE
    idoPrice = _idoPrice;
  }

  /// @notice Function that distributes fees to the respective flows
  /// @dev This function requires funds to be sent beforehand to this contract
  function receiveFees(uint _pid, uint _amount) external onlyChef{
    (,,,IERC20 token,,,bool isLP) = chef.poolInfo(_pid);
    token.safeTransferFrom( address(chef), address(this), _amount);
    // Check if token was received
    require(token.balanceOf(address(this)) >= _amount, "send funds");
    FeeData storage feeInfo = feeData[_pid];
    uint wBNBtoWorkWith;
    // IS LP TOKEN ?
    if(isLP){
      IPancakePair lp = IPancakePair( address(token));
      uint[]memory minAmounts = feeInfo.router.getAmountsOut(_amount, feeInfo.tokens);
      // YES SWAP LP FLOW
      lp.approve(address(feeInfo.router), _amount);
      // remove liquidity
      (uint returnedA, uint returnedB) = feeInfo.router.removeLiquidity(
        feeInfo.tokens[0],
        feeInfo.tokens[1],
        _amount,
        minAmounts[0], //A AMOUNT
        minAmounts[1], //B AMOUNT
        address(this),
        block.timestamp + 5 // recommended by arishali
      );
      // swap token0 for wBNB
      if(feeInfo.tokens[0]!= baseToken){
        minAmounts = feeInfo.router.getAmountsOut(returnedA, feeInfo.token0path);
        minAmounts = feeInfo.router.swapExactTokensForTokens(
          returnedA,
          minAmounts[feeInfo.token0path.length - 1],
          feeInfo.token0path,
          address(this),
          block.timestamp + 10 //maybe since we already spent 5 secs on prev
        );
        wBNBtoWorkWith += minAmounts[ minAmounts.length -1];
      }
      else
        wBNBtoWorkWith += returnedA;
      // swap token1 for wBNB (if necessary)
      if(feeInfo.tokens[1]!= baseToken){
        minAmounts = feeInfo.router.getAmountsOut(returnedB, feeInfo.token1path);
        minAmounts = feeInfo.router.swapExactTokensForTokens(
          returnedB,
          minAmounts[feeInfo.token1path.length - 1],
          feeInfo.token0path,
          address(this),
          block.timestamp + 10 //maybe since we already spent 5 secs on prev
        );
        wBNBtoWorkWith += minAmounts[ minAmounts.length -1];
      }
      else
        wBNBtoWorkWith += returnedB;
    }
    else{
      // NO SWAP ERC FLOW
      uint[] memory minAmount = feeInfo.router.getAmountsOut(_amount, feeInfo.token0path);
      minAmount = feeInfo.router.swapExactTokensForTokens(
        _amount,
        minAmount[minAmount.length -1],
        feeInfo.token0path,
        address(this),
        block.timestamp + 5
      );
      wBNBtoWorkWith += minAmount[ minAmount.length -1];
    }
    // GET PORTION AMOUNTS
    getFeesAndDistribute(wBNBtoWorkWith, feeInfo);
  }

  /// @notice math to figure out the distribution portions of wBNB to use and swap
  function getFeesAndDistribute(
    uint _wBnb,
    FeeData storage _feeInfo
  ) internal {
    uint workBnb = _wBnb;
    uint buyback = _wBnb * _feeInfo.buyback / DIVISOR;
    uint liquidity;
    uint bnbLiquidity;
    uint niceGot;
    uint crushGot;
    uint _team;
    IPancakePair crushLiq = IPancakePair(crushLiquidity);
    IPancakePair niceLiq = IPancakePair(niceLiquidity);
    // IS Nice above IDO?
    if(checkPrice()){
      //PROCEED
      bnbLiquidity = _feeInfo.team > 0 
        ? _wBnb * _feeInfo.liquidity / DIVISOR 
        : _wBnb - buyback;
      liquidity = bnbLiquidity/2;
      niceGot = (_feeInfo.tokenToUse[0] ? 0 : buyback) + (_feeInfo.tokenToUse[1] ? 0 : liquidity);
      crushGot = (_feeInfo.tokenToUse[0] ? buyback : 0) + (_feeInfo.tokenToUse[1] ? liquidity : 0);
      bnbLiquidity = (_feeInfo.tokenToUse[1] ? crushGot : niceGot);
      if(niceGot > 0){
        (niceGot,_team) = swapWrapForToken(niceGot, niceLiq, nicePath);
        workBnb -= _team;
      }
      if(crushGot > 0){
        (crushGot,_team) = swapWrapForToken(crushGot, crushLiq, crushPath);
        workBnb -= _team;
      }
    }
    else{
      //FULL BUYBACK OF NICE
      (niceGot,_team) = swapWrapForToken(_wBnb, niceLiq, nicePath);
      workBnb -= _team;
    }
    // ADD LIQUIDITY AND BURN (TRANSFER TO DEAD ADDRESS)
    if(liquidity > 0){
      uint tokensForLiquidity = (liquidity * 1e12) / bnbLiquidity;
      if(_feeInfo.tokenToUse[1]){
        // add liquidity to NICE
        tokensForLiquidity = niceGot * tokensForLiquidity / 1e12;
        (bnbLiquidity, tokensForLiquidity, liquidity) = tokenRouter.addLiquidity(
          nicePath[0],
          nicePath[1],
          liquidity,
          niceGot * tokensForLiquidity / 1e12,
          liquidity*100/DIVISOR,
          niceGot*100/DIVISOR,
          address(this),
          block.timestamp + 5
        );
        niceGot -= tokensForLiquidity;
        workBnb -= bnbLiquidity;
        // transfer liquidity to dead wallet
        niceLiq.transfer(deadWallet, liquidity);
      }
      else{
        // add liquidity to NICE
        tokensForLiquidity = crushGot * tokensForLiquidity / 1e12;
        (bnbLiquidity, tokensForLiquidity, liquidity) = tokenRouter.addLiquidity(
          nicePath[0],
          nicePath[1],
          liquidity,
          crushGot * tokensForLiquidity / 1e12,
          liquidity*100/DIVISOR,
          crushGot*100/DIVISOR,
          address(this),
          block.timestamp + 5
        );
        crushGot -= tokensForLiquidity;
        workBnb -= bnbLiquidity;
        // transfer liquidity to dead wallet
        crushLiq.transfer(deadWallet, liquidity);
      }
    }
    if(niceGot > 0){
      ERC20Burnable(nicePath[1]).burn(niceGot);
    }
    if(crushGot > 0){
      ERC20Burnable(crushPath[1]).burn(crushGot);
    }

    if(workBnb > 0)
      IERC20(baseToken).transfer(teamWallet,workBnb);

  }

  function swapWrapForToken(
    uint _amountWBnb,
    IPancakePair _pair,
    address[] memory path
  ) internal 
    returns(
      uint tokensReceived,
      uint _wBnbUsed
    )
  {
    (uint res0, uint res1,) = _pair.getReserves();
    uint minToGet = tokenRouter.getAmountOut(_amountWBnb, res0, res1);
    uint[] memory swappedTokens = tokenRouter.swapExactTokensForTokens(
      _amountWBnb,
      minToGet,
      path,
      address(this),
      block.timestamp + 5
    );
    tokensReceived = swappedTokens[swappedTokens.length -1];
    _wBnbUsed = swappedTokens[0];
  }
  /// @notice Check that current Nice Price is above IDO
  /// @dev 
  function checkPrice() public view returns (bool _aboveIDO){
    (uint reserve0, uint reserve1, ) = IPancakePair(niceLiquidity).getReserves();
    reserve1 = reserve1 > 0 ? reserve1 : 1; //just in case
    _aboveIDO = (reserve0 * 1 ether/ reserve1) > idoPrice;
  } 


}