// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./GalacticChef.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter.sol";

contract FeeDistributor is Ownable {
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for IERC20;

    struct FeeData {
        uint256 buyback;
        uint256 liquidity;
        uint256 team;
        bool bbNice;
        bool liqNice;
        /**
            if it's an LP token we can definitely burn it to get the contained tokens
            else it's a Single asset token and have to swap it for base eth token 
            before buying anything else.
            bbNice token to buyback and burn
            is it CRUSH (false) or NICE (true)
            liqNice token to get liquidity for
            is it CRUSH/BNB(false) or NICE/BNB (true)
        **/
        IPancakeRouter router; // main router for this token
        uint256 slippage;
    }
    address public immutable baseToken; // wBNB || wETH || etc
    address[] public crushPath; // [0]wBNB to [1]CRUSH
    address[] public nicePath; // [0]wBNB to [1]NICE
    address public crushLiquidity; // for swapping / adding Liquidity
    address public niceLiquidity; // for swapping / adding Liquidity
    address public immutable deadWallet =
        0x000000000000000000000000000000000000dEaD;
    IPancakeRouter public tokenRouter;
    uint256 public immutable idoPrice;
    address public teamWallet;

    uint256 public constant DIVISOR = 10000;
    GalacticChef public chef;

    mapping(uint256 => FeeData) public feeData;
    mapping(uint256 => address[]) public tokenPath; // RECEIVED TOKEN TO WBNB
    mapping(uint256 => address[]) public token0Path; // LP TOKEN 0 TO WBNB
    mapping(uint256 => address[]) public token1Path; // LP TOKEN 1 TO WBNB

    event AddPoolFee(uint256 indexed _pid);
    event EditFee(uint256 indexed _pid, uint256 bb, uint256 liq, uint256 team);
    event UpdateRouter(uint256 indexed _pid, address router);
    event UpdatePath(uint256 indexed _pid, address router);
    event UpdateTeamWallet(address _teamW);
    event UpdateRouter(address _router);
    event UpdateCore(bool isNice, address liquidity, uint256 pathSize);

    modifier onlyChef() {
        require(msg.sender == address(chef), "onlyChef");
        _;
    }

    constructor(
        address _chef,
        address _baseWrapped,
        uint256 _idoPrice
    ) {
        require(
            _chef != address(0) && _baseWrapped != address(0),
            "Zero address"
        );
        chef = GalacticChef(_chef);
        baseToken = _baseWrapped;
        // _idoPrice must be NICE/BNB NOT BNB/NICE
        idoPrice = _idoPrice;
    }

    function addorEditFee(
        uint256[5] calldata _fees, // 0 pid, 1 buyback, 2 liquidity, 3 team, 4 slippage
        bool _bbNice,
        bool _liqNice,
        address router,
        address[] calldata _tokens,
        address[] calldata _token0Path,
        address[] calldata _token1Path
    ) external onlyOwner {
        require(
            _fees[1] + _fees[2] + _fees[3] == DIVISOR,
            "Incorrect Fee distribution"
        );
        require(router != address(0), "Incorrect Router");
        require(_tokens.length > 0, "need a path to base");
        require(_fees[4] >= 50 && _fees[4] <= 2000, "slippage too low");
        feeData[_fees[0]] = FeeData(
            _fees[1],
            _fees[2],
            _fees[3],
            _bbNice,
            _liqNice,
            IPancakeRouter(router),
            _fees[4]
        );
        tokenPath[_fees[0]] = _tokens;
        token0Path[_fees[0]] = _token0Path;
        token1Path[_fees[0]] = _token1Path;
        emit AddPoolFee(_fees[0]);
    }

    /// @notice Function that distributes fees to the respective flows
    /// @dev This function requires funds to be sent beforehand to this contract
    function receiveFees(uint256 _pid, uint256 _amount) external onlyChef {
        (, , , IERC20 token, , , bool isLP) = chef.poolInfo(_pid);
        token.safeTransferFrom(address(chef), address(this), _amount);
        // Check if token was received
        require(token.balanceOf(address(this)) >= _amount, "send funds");
        FeeData storage feeInfo = feeData[_pid];
        uint256 wBNBtoWorkWith;
        // IS LP TOKEN ?
        if (isLP) {
            // YES SWAP LP FLOW;
            uint256[] memory minAmounts = feeInfo.router.getAmountsOut(
                _amount,
                tokenPath[_pid]
            );

            token.approve(address(feeInfo.router), _amount);
            // remove liquidity
            (uint256 returnedA, uint256 returnedB) = feeInfo
                .router
                .removeLiquidity(
                    tokenPath[_pid][0],
                    tokenPath[_pid][1],
                    _amount,
                    minAmounts[0], //A AMOUNT
                    minAmounts[1], //B AMOUNT
                    address(this),
                    block.timestamp + 5 // recommended by arishali
                );
            // swap token0 for wBNB
            if (tokenPath[_pid][0] != baseToken) {
                (minAmounts[0], minAmounts[1]) = swapForWrap(
                    returnedA,
                    token0Path[_pid],
                    feeInfo
                );
                if (returnedA - minAmounts[0] > 0)
                    IERC20(tokenPath[_pid][0]).transfer(
                        deadWallet,
                        returnedA - minAmounts[0]
                    );
                wBNBtoWorkWith += minAmounts[1];
            } else wBNBtoWorkWith += returnedA;
            // swap token1 for wBNB (if necessary)
            if (tokenPath[_pid][1] != baseToken) {
                (minAmounts[0], minAmounts[1]) = swapForWrap(
                    returnedB,
                    token1Path[_pid],
                    feeInfo
                );
                if (returnedA - minAmounts[0] > 0)
                    IERC20(tokenPath[_pid][1]).transfer(
                        deadWallet,
                        returnedB - minAmounts[0]
                    );
                wBNBtoWorkWith += minAmounts[1];
            } else wBNBtoWorkWith += returnedB;
        } else {
            // NO SWAP ERC FLOW
            uint256[] memory minAmount = feeInfo.router.getAmountsOut(
                _amount,
                token0Path[_pid]
            );
            minAmount = feeInfo.router.swapExactTokensForTokens(
                _amount,
                minAmount[minAmount.length - 1] *
                    ((DIVISOR - feeInfo.slippage) / DIVISOR),
                token0Path[_pid],
                address(this),
                block.timestamp + 5
            );
            wBNBtoWorkWith += minAmount[minAmount.length - 1];
        }
        // GET PORTION AMOUNTS
        getFeesAndDistribute(wBNBtoWorkWith, feeInfo);
    }

    /// @notice math to figure out the distribution portions of wBNB to use and swap
    function getFeesAndDistribute(uint256 _wBnb, FeeData storage _feeInfo)
        internal
    {
        uint256 workBnb = _wBnb;
        uint256 buyback = (_wBnb * _feeInfo.buyback) / DIVISOR;
        uint256 liquidity;
        uint256 bnbLiquidity;
        uint256 niceGot;
        uint256 crushGot;
        uint256 _team;
        IPancakePair crushLiq = IPancakePair(crushLiquidity);
        IPancakePair niceLiq = IPancakePair(niceLiquidity);
        // IS Nice above IDO?
        if (checkPrice()) {
            //PROCEED
            bnbLiquidity = _feeInfo.team > 0
                ? (_wBnb * _feeInfo.liquidity) / DIVISOR
                : _wBnb - buyback;
            liquidity = bnbLiquidity / 2;
            niceGot =
                (_feeInfo.bbNice ? 0 : buyback) +
                (_feeInfo.liqNice ? 0 : liquidity);
            crushGot =
                (_feeInfo.bbNice ? buyback : 0) +
                (_feeInfo.liqNice ? liquidity : 0);
            bnbLiquidity = (_feeInfo.liqNice ? crushGot : niceGot);
            if (niceGot > 0) {
                (niceGot, _team) = swapWrapForToken(niceGot, niceLiq, nicePath);
                workBnb -= _team;
            }
            if (crushGot > 0) {
                (crushGot, _team) = swapWrapForToken(
                    crushGot,
                    crushLiq,
                    crushPath
                );
                workBnb -= _team;
            }
        } else {
            //FULL BUYBACK OF NICE
            (niceGot, _team) = swapWrapForToken(_wBnb, niceLiq, nicePath);
            workBnb -= _team;
        }
        // ADD LIQUIDITY AND BURN (TRANSFER TO DEAD ADDRESS)
        if (liquidity > 0) {
            uint256 tokensForLiquidity = (liquidity * 1e12) / bnbLiquidity;
            if (_feeInfo.liqNice) {
                // add liquidity to NICE
                tokensForLiquidity = (niceGot * tokensForLiquidity) / 1e12;
                (bnbLiquidity, tokensForLiquidity, liquidity) = tokenRouter
                    .addLiquidity(
                        nicePath[0],
                        nicePath[1],
                        liquidity,
                        (niceGot * tokensForLiquidity) / 1e12,
                        (liquidity * 100) / DIVISOR,
                        (niceGot * 100) / DIVISOR,
                        address(this),
                        block.timestamp + 5
                    );
                niceGot -= tokensForLiquidity;
                workBnb -= bnbLiquidity;
                // transfer liquidity to dead wallet
                niceLiq.transfer(deadWallet, liquidity);
            } else {
                // add liquidity to NICE
                tokensForLiquidity = (crushGot * tokensForLiquidity) / 1e12;
                (bnbLiquidity, tokensForLiquidity, liquidity) = tokenRouter
                    .addLiquidity(
                        nicePath[0],
                        nicePath[1],
                        liquidity,
                        (crushGot * tokensForLiquidity) / 1e12,
                        (liquidity * 100) / DIVISOR,
                        (crushGot * 100) / DIVISOR,
                        address(this),
                        block.timestamp + 5
                    );
                crushGot -= tokensForLiquidity;
                workBnb -= bnbLiquidity;
                // transfer liquidity to dead wallet
                crushLiq.transfer(deadWallet, liquidity);
            }
        }
        if (niceGot > 0) {
            ERC20Burnable(nicePath[1]).burn(niceGot);
        }
        if (crushGot > 0) {
            ERC20Burnable(crushPath[1]).burn(crushGot);
        }

        if (workBnb > 0) IERC20(baseToken).transfer(teamWallet, workBnb);
    }

    /// @notice simplify swap request
    /// @dev ONLY FOR NICE AND CRUSH SWAPPING
    function swapWrapForToken(
        uint256 _amountWBnb,
        IPancakePair _pair,
        address[] memory path
    ) internal returns (uint256 tokensReceived, uint256 _wBnbUsed) {
        (uint256 res0, uint256 res1, ) = _pair.getReserves();
        uint256 minToGet = tokenRouter.getAmountOut(_amountWBnb, res0, res1);
        uint256[] memory swappedTokens = tokenRouter.swapExactTokensForTokens(
            _amountWBnb,
            (minToGet * 990) / 1000,
            path,
            address(this),
            block.timestamp + 5
        );
        tokensReceived = swappedTokens[swappedTokens.length - 1];
        _wBnbUsed = swappedTokens[0];
    }

    /// @notice Check that current Nice Price is above IDO
    /// @dev 
    function checkPrice() public view returns (bool _aboveIDO) {
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(niceLiquidity)
            .getReserves();
        reserve1 = reserve1 > 0 ? reserve1 : 1; //just in case
        _aboveIDO = ((reserve0 * 1 ether) / reserve1) > idoPrice;
    }

    function swapForWrap(
        uint256 inputAmount,
        address[] storage path,
        FeeData storage feeInfo
    ) internal returns (uint256 amountLeft, uint256 wBnbReturned) {
        uint256[] memory swapAmounts = feeInfo.router.getAmountsOut(
            inputAmount,
            path
        );
        swapAmounts = feeInfo.router.swapExactTokensForTokens(
            inputAmount,
            swapAmounts[path.length - 1] *
                ((DIVISOR - feeInfo.slippage) / DIVISOR),
            path,
            address(this),
            block.timestamp + 10
        );
        amountLeft = inputAmount - swapAmounts[0];
        wBnbReturned = swapAmounts[swapAmounts.length - 1];
    }

    function setBaseRouter(address _newRouter) external onlyOwner {
        require(_newRouter != address(0), "No zero");
        tokenRouter = IPancakeRouter(_newRouter);
        emit UpdateRouter(_newRouter);
    }

    function setBaseRouting(
        bool _isNice,
        address _liquidity,
        address[] calldata _path
    ) external onlyOwner {
        require(_liquidity != address(0), "No zero");
        require(_path.length > 1, "at least 2 tokens");
        if (_isNice) {
            niceLiquidity = _liquidity;
            nicePath = _path;
        } else {
            crushLiquidity = _liquidity;
            crushPath = _path;
        }
        emit UpdateCore(_isNice, _liquidity, _path.length);
    }

    function setTeamWallet(address _newTeamW) external onlyOwner {
        require(_newTeamW != address(0), "Cant pay 0");
        teamWallet = _newTeamW;
        emit UpdateTeamWallet(_newTeamW);
    }
}
