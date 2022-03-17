// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./GalacticChef.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter.sol";

//import "../interfaces/IFeeDistributor.sol";
///@dev use interface IFeeDistributor

contract FeeDistributor is Ownable {
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for IERC20;

    struct FeeData {
        /** Fees in array are as follows
         * [0](bbb) Buy back and Burn (NICE | CRUSH) CHECK THAT SELECTED TOKEN HAS BEEN BURNED IN TOKEN CONTRACT REVISAR TOTAL SUPPLY
         * [1](bbd) Buy back and DISTRIBUTE (CRUSH) SENDS CRUSH TO BANKSTAKING
         * [2](bbl) Buy back and LOTTERY (CRUSH) SENDS CRUSH TO LOTTERY POOL
         * [3](lqPermanent) PERMANENT LIQUIDITY (NICE | CRUSH)/BNB
         * [4](lqLock) LOCKED LIQUIDITY (NICE | CRUSH)/BNB
         * 0-4 need to be <= 100% Whatever is left, we send to marketing wallet
         * REST - MARKETING FUNDS -> BNB
         **/
        uint256[5] niceFees;
        uint256[5] crushFees;
        bool initialized; // Fail transactions where fees have not been added
        bool hasFees; // If token charges fees on transfers need to use swapTokensForEthSupportingFeesOnTransferToken function instead
        bool token0Fees; // FOR LP IN CASE IT HAS FEES
        bool token1Fees; // FOR LP IN CASE ITS TOKEN HAS FEES
        /**
            if it's an LP token we need to remove that Liquidity
            else it's a Single asset token and have to swap it for core ETH (BNB)
            before buying anything else.
        **/
        IPancakeRouter router; // main router for this token
    }
    address public immutable baseToken; // wBNB || wETH || etc
    address public CRUSH;
    address public NICE;
    address public crushLiquidity; // for swapping / adding Liquidity
    address public niceLiquidity; // for swapping / adding Liquidity
    address public immutable deadWallet =
        0x000000000000000000000000000000000000dEaD;
    IPancakeRouter public tokenRouter; //used for CRUSH and NICE

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
        teamWallet = msg.sender;
        // _idoPrice must be NICE/BNB NOT BNB/NICE
        idoPrice = _idoPrice;
    }

    function addorEditFee(
        uint256 _pid, //ID TO ADD/EDIT
        uint256[5] calldata _niceFees, // 0 buyback BURN, 1 buyback DISTRIBUTE, 2 buyback LOTTERY, 3 liquidity PERMANENT, 4 liquidity LOCK
        uint256[5] calldata _crushFees, // 0 buyback BURN, 1 buyback DISTRIBUTE, 2 buyback LOTTERY, 3 liquidity PERMANENT, 4 liquidity LOCK
        bool hasFees, // TOKEN CHARGES FEES ON TRANSFER
        address router, //swap router address
        bool token0Fees,
        bool token1Fees,
        // If is LP -> tokenAddresses that compose the pair CRUSH/BUSD -> [ CRUSH_ADDRESS, BUSD_ADDRESS]
        // If ERC20 token [ CRUSH_ADDRESS, wBNB] -> Path to ETH
        address[] calldata _tokens,
        address[] calldata _token0Path, // LP TOKEN 0 PATH TO wBNB
        address[] calldata _token1Path // LP TOKEN 1 PATH to wBNB
    ) external onlyOwner {
        require(
            _niceFees[0] +
                _niceFees[1] +
                _niceFees[2] +
                _niceFees[3] +
                _niceFees[4] +
                _crushFees[0] +
                _crushFees[1] +
                _crushFees[2] +
                _crushFees[3] +
                _crushFees[4] <=
                DIVISOR,
            "Incorrect Fee distribution"
        );
        require(router != address(0), "Incorrect Router");
        require(_tokens.length > 0, "need a path to base");
        feeData[_pid] = FeeData(
            _niceFees,
            _crushFees,
            hasFees,
            token0Fees,
            token1Fees,
            IPancakeRouter(router)
        );
        tokenPath[_fees[0]] = _tokens;
        token0Path[_fees[0]] = _token0Path;
        token1Path[_fees[0]] = _token1Path;
        if (!feeData[_pid].initialized) feeData[_pid].initialized = true;
        emit AddPoolFee(_fees[0]);
    }

    /// @notice Function that distributes fees to the respective flows
    /// @dev This function requires funds to be sent beforehand to this contract
    function receiveFees(uint256 _pid, uint256 _amount) external onlyChef {
        FeeData storage feeInfo = feeData[_pid];

        (, , , IERC20 token, , , bool isLP) = chef.poolInfo(_pid);
        token.safeTransferFrom(address(chef), address(this), _amount);
        // Check if token was received
        require(token.balanceOf(address(this)) >= _amount, "send funds");
        // REQUIRE THAT FEES ARE NEEDED TO BE TAKEN, ELSE TRANSFER TO OWNER
        uint256 wBNBtoWorkWith;
        // IS LP TOKEN ?
        if (isLP) {
            token.approve(address(feeInfo.router), _amount);
            // remove liquidity
            removeLiquidityAndSwapETH(_pid, amount, token);
        } else {
            // NO SWAP ERC FLOW
            feeInfo.hasFees
                ? feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        _amount,
                        0, // We get what we can
                        tokenPath[_pid], // Token PATH of ERC is already path to WETH
                        address(this),
                        block.timestamp
                    )
                : feeInfo.router.swapExactTokensForETH(
                    _amount,
                    0, // We get what we can
                    tokenPath[_pid], // Token PATH of ERC is already path to WETH
                    address(this),
                    block.timestamp
                );
        }
        // GET PORTION AMOUNTS
        distrubuteFees(feeInfo);
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

    function swapForETH(
        uint256 inputAmount,
        address[] storage path,
        FeeData storage feeInfo
    ) internal returns (uint256 amountLeft, uint256 wBnbReturned) {
        uint256[] memory swapAmounts = feeInfo.router.getAmountsOut(
            inputAmount,
            path
        );
        IERC20(path[0]).approve(address(router), inputAmount);
        swapAmounts = feeInfo.router.swapExactTokensForETH(
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

    function getBuybackFee(FeeData storage feeInfo)
        internal
        returns (uint256 _bbFees)
    {
        return feeInfo.bbb + feeInfo.bbd + feeInfo.bbl;
    }

    function getLiquidityFee(FeeData storage feeInfo)
        internal
        returns (uint256 _bbFees)
    {
        return feeInfo.bbb + feeInfo.bbd + feeInfo.bbl;
    }

    function getNotEthToken(uint256 _pid)
        internal
        view
        returns (
            IERC20 token,
            address[] memory path,
            bool hasFees
        )
    {
        if (tokenPath[_pid][0] != router.WETH()) {
            token = IERC20(tokenPath[_pid][0]);
            path = token0Path[_pid];
            hasFees = feeData[_pid].token0Fees;
        } else {
            token = IERC20(tokenPath[_pid][1]);
            path = token1Path[_pid];
        }
    }

    function removeLiquidityAndSwapETH(
        uint256 _pid,
        uint256 amount,
        IERC20 token
    ) internal returns (uint256) {
        FeeData storage feeInfo = feeData[_pid];
        // SWAP WITH ONE TOKEN ALREADY WETH
        if (
            tokenPath[_pid][0] == router.WETH() ||
            tokenPath[_pid][1] == router.WETH()
        ) {
            (
                IERC2O token,
                address[] memory path,
                bool tokenFees
            ) = getNotEthToken(_pid);
            (uint256 tokensLeft, ) = feeInfo.hasFees
                ? feeInfo
                    .router
                    .removeLiquidityETHSupportingFeeOnTransferTokens(
                        address(token),
                        amount,
                        0,
                        0,
                        address(this),
                        block.timestamp
                    )
                : feeInfo.router.removeLiquidityETH(
                    address(token),
                    amount,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            token.approve(address(feeInfo.router), tokensLeft);
            if (tokenFees) {
                feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        tokensLeft,
                        0,
                        path,
                        address(this),
                        block.timestamp
                    );
            } else {
                feeInfo.router.swapExactTokensForETH(
                    tokensLeft,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
            }
        }
        // SWAP WITH NO TOKENS BEING WETH
        else {
            (uint256 tokenA, uint256 tokenB) = feeInfo.hasFees
                ? feeInfo.router.removeLiquiditySupportingFeeOnTransferTokens(
                    tokenPath[_pid][0],
                    tokenPath[_pid][1],
                    amount,
                    0,
                    0,
                    address(this),
                    block.timestamp
                )
                : feeInfo.router.removeLiquidity(
                    tokenPath[_pid][0],
                    tokenPath[_pid][1],
                    amount,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            // Approve tokens for swap
            IERC20(tokenPath[_pid][0]).approve(address(feeInfo.router), tokenA);
            IERC20(tokenPath[_pid][1]).approve(address(feeInfo.router), tokenB);
            // Swap token A
            feeInfo.token0Fees
                ? feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        tokenA,
                        0,
                        token0Path[_pid],
                        address(this),
                        block.timestamp
                    )
                : feeInfo.router.swapExactTokensForETH(
                    tokenA,
                    0,
                    token0Path[_pid],
                    address(this),
                    block.timestamp
                );
            // Swap token B
            feeInfo.token1Fees
                ? feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        tokenB,
                        0,
                        token1Path[_pid],
                        address(this),
                        block.timestamp
                    )
                : feeInfo.router.swapExactTokensForETH(
                    tokenB,
                    0,
                    token1Path[_pid],
                    address(this),
                    block.timestamp
                );
            //Returns total ETH got
            return address(this).balance;
        }
    }

    function distributeFees(FeeData storage feeInfo) internal {
        uint256 totalCrush;
        uint256 totalNice;
        uint256 crushFees;
        uint256 niceFees;
        uint256 bnbForCrush;
        uint256 bnbForNice;
        uint256 swapAmountCrush;
        uint256 swapAmountNice;

        for (uint8 x = 0; x < 5; x++) {
            crushFees += feeInfo.crushFees[x];
            totalCrush = x < 3
                ? feeInfo.crushFees[x]
                : feeInfo.crushFees[x] / 2;
            niceFees += feeInfo.niceFees[x];
            totalNice = x < 3 ? feeInfo.niceFees[x] : feeInfo.niceFees[x] / 2;
        }
        bnbForCrush = (address(this).balance * crushFees) / DIVISOR;
        bnbForNice = (address(this).balance * niceFees) / DIVISOR;

        swapAmountCrush = (bnbForCrush * totalCrush) / crushFees;
        swapAmountNice = (bnbForNice * totalNice) / niceFees;

        // Swap for CRUSH
        tokenRouter.swapExactETHForTokens{value: swapAmountCrush}(
            0,
            [tokenRouter.WETH(), CRUSH],
            address(this),
            block.timestamp
        );
        bnbForCrush -= swapAmountCrush;
        bnbForNice -= swapAmountNice;
        tokenAndLiquidityDistribution(
            CRUSH,
            feeInfo,
            crushFees,
            false,
            bnbForCrush
        );
        // Swap for NICE
        tokenRouter.swapExactETHForTokens{value: swapAmountNice}(
            0,
            [tokenRouter.WETH(), NICE],
            address(this),
            block.timestamp
        );
        tokenAndLiquidityDistribution(
            NICE,
            feeInfo,
            niceFees,
            true,
            bnbForNice
        );
    }

    function tokenAndLiquidityDistribution(
        address token,
        FeeData storage feeInfo,
        uint256 totalFees,
        bool isNice,
        uint256 liquidityETH
    ) internal {
        ERC20Burnable mainToken = ERC20Burnable(token);
        uint256[5] memory fees = isNice ? feeInfo.niceFees : feeInfo.crushFees;
        uint256 currentBalance = mainToken.balanceOf(address(this));
        uint256 amountToUse = (currentBalance * fees[0]) / totalFees;
        if (amountToUse > 0) mainToken.burn(amountToUse);
        amountToUse = (currentBalance * fees[1]) / totalFees;
        if (amountToUse > 0) {
            if (isNice) {}
        }
    }
}
