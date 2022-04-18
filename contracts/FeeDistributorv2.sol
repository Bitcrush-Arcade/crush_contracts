// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./GalacticChef.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IBankroll.sol";
import "../interfaces/ILottery.sol";

//import "../interfaces/IFeeDistributor.sol";
///@dev use interface IFeeDistributor

contract FeeDistributorV2 is Ownable {
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for IERC20;

    struct FeeData {
        /** Fees in array are as follows [CRUSH] [NICE]
         * [0][0](bbb) Buy back and Burn (NICE | CRUSH) CHECK THAT SELECTED TOKEN HAS BEEN BURNED IN TOKEN CONTRACT REVISAR TOTAL SUPPLY
         * [1](bbd) Buy back and DISTRIBUTE (CRUSH) SENDS CRUSH TO BANKSTAKING
         * [2](bbl) Buy back and LOTTERY (CRUSH) SENDS CRUSH TO LOTTERY POOL
         * [3][1](lqPermanent) PERMANENT LIQUIDITY (NICE | CRUSH)/BNB
         * [4][2](lqLock) LOCKED LIQUIDITY (NICE | CRUSH)/BNB
         * 0-4 need to be <= 100% Whatever is left, we send to marketing wallet
         * REST - MARKETING FUNDS -> BNB
         **/
        uint256[3] niceFees;
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
    address public immutable CRUSH;
    address public immutable NICE;
    address public immutable deadWallet =
        0x000000000000000000000000000000000000dEaD;
    IPancakeRouter public tokenRouter; //used for CRUSH and NICE
    address public niceLiquidity;
    uint256 public idoPrice;
    address public teamWallet;
    address public lock;
    IBitcrushBankroll public immutable bankroll;
    IBitcrushLottery public lottery;

    bool public reachForIdo;

    uint256 public constant DIVISOR = 10000; // 100.00%
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
    event UpdateMainRouter(address _router);
    event FundsDistributed(uint256 amount, address _token);
    event TeamFundsDistributed(bool _success, uint256 amount);
    event UpdateTargetPrice(uint256 _target);
    event UpdateLotteryAddress(address _newLotteery, address _oldLottery);
    event SeachForTarget(bool _isOn);

    modifier onlyChef() {
        require(msg.sender == address(chef), "onlyChef");
        _;
    }

    constructor(
        address _chef,
        uint256 _idoPrice,
        address _nicePair,
        address _bankroll,
        address _lottery,
        address _lock,
        address _nice,
        address _crush
    ) {
        require(_chef != address(0), "Zero address");
        chef = GalacticChef(_chef);
        teamWallet = msg.sender;
        // _idoPrice must be NICE/BNB NOT BNB/NICE
        idoPrice = _idoPrice;
        niceLiquidity = _nicePair;
        // DISTRIBUTE CRUSH
        bankroll = IBitcrushBankroll(_bankroll);
        lottery = IBitcrushLottery(_lottery);
        CRUSH = _crush;
        NICE = _nice;
    }

    /*********************************
     *      INITIALIZE FEE POOL      *
     *********************************/

    function addorEditFee(
        uint256 _pid, //ID TO ADD/EDIT
        uint256[3] calldata _niceFees, // 0 buyback BURN, 1 buyback DISTRIBUTE, 2 buyback LOTTERY, 3 liquidity PERMANENT, 4 liquidity LOCK
        uint256[5] calldata _crushFees, // 0 buyback BURN, 1 buyback DISTRIBUTE, 2 buyback LOTTERY, 3 liquidity PERMANENT, 4 liquidity LOCK
        bool[3] calldata hasFees, // 0 token has Fees, 1 token0 has fees, 2 token1 has fees
        address router, //swap router address
        // If is LP -> tokenAddresses that compose the pair CRUSH/BUSD -> [ CRUSH_ADDRESS, BUSD_ADDRESS]
        // If ERC20 token [ CRUSH_ADDRESS, wBNB] -> Path to ETH
        address[] calldata _tokens,
        address[] calldata _token0Path, // LP TOKEN 0 PATH TO wBNB
        address[] calldata _token1Path // LP TOKEN 1 PATH to wBNB
    ) external onlyOwner {
        require(
            addArrays(_niceFees, _crushFees) <= DIVISOR,
            "Incorrect Fee distribution"
        );
        require(router != address(0), "Incorrect Router");
        require(_tokens.length > 0, "need a path to base");
        feeData[_pid] = FeeData(
            _niceFees,
            _crushFees,
            true,
            hasFees[0],
            hasFees[1],
            hasFees[2],
            IPancakeRouter(router)
        );
        updatePaths(_pid, _tokens, _token0Path, _token1Path);
        emit AddPoolFee(_pid);
    }

    /******************************
     *      FEE DISTRIBUTION      *
     ******************************/
    receive() external payable {}

    fallback() external payable {}

    /// @notice Function that distributes fees to the respective flows
    /// @dev This function requires funds to be sent beforehand to this contract
    function receiveFees(uint256 _pid, uint256 _amount) external onlyChef {
        FeeData storage feeInfo = feeData[_pid];
        require(feeInfo.initialized, "Not init");
        (, , , IERC20 token, , , bool isLP, ) = chef.poolInfo(_pid);
        token.safeTransferFrom(address(chef), address(this), _amount);
        // Check if token was received
        require(token.balanceOf(address(this)) >= _amount, "send funds");
        // REQUIRE THAT FEES ARE NEEDED TO BE TAKEN, ELSE TRANSFER TO OWNER
        // IS LP TOKEN ?
        token.approve(address(feeInfo.router), _amount * 2);
        if (isLP) {
            // remove liquidity
            removeLiquidityAndSwapETH(_pid, _amount);
        } else {
            // NO SWAP ERC FLOW
            if (feeInfo.hasFees)
                feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        _amount,
                        0, // We get what we can
                        tokenPath[_pid], // Token PATH of ERC is already path to WETH
                        address(this),
                        block.timestamp
                    );
            else
                feeInfo.router.swapExactTokensForETH(
                    _amount,
                    0, // We get what we can
                    tokenPath[_pid], // Token PATH of ERC is already path to WETH
                    address(this),
                    block.timestamp
                );
        }
        if (reachForIdo && checkPrice()) {
            // only buy back and burn NICE
            uint256 currentETH = address(this).balance;
            address[] memory nicePath;
            nicePath[0] = tokenRouter.WETH();
            nicePath[1] = NICE;
            tokenRouter.swapExactETHForTokens{value: currentETH}(
                0,
                nicePath,
                address(0),
                block.timestamp
            );
        } else {
            // With the ETH distribute AMOUNTS
            distributeFees(feeInfo);
        }
        emit FundsDistributed(_amount, address(token));
    }

    /// @notice Check that current Nice Price is above IDO
    /// @dev get IDO price for NICE
    function checkPrice() public view returns (bool _belowIDO) {
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(niceLiquidity)
            .getReserves();
        reserve1 = reserve1 > 0 ? reserve1 : 1; //just in case
        _belowIDO = ((reserve0 * 1 ether) / reserve1) < idoPrice;
    }

    /// @notice from the POOL ID check which token is wETH and return the other one
    /// @param _pid the Pool ID token path to check
    function getNotEthToken(uint256 _pid)
        internal
        view
        returns (
            IERC20 token,
            address[] memory path,
            bool hasFees
        )
    {
        if (tokenPath[_pid][0] != tokenRouter.WETH()) {
            token = IERC20(tokenPath[_pid][0]);
            path = token0Path[_pid];
            hasFees = feeData[_pid].token0Fees;
        } else {
            token = IERC20(tokenPath[_pid][1]);
            path = token1Path[_pid];
        }
    }

    /// @notice Remove Liquidity from pair token and swap for ETH
    /// @param _pid Pool ID  to get token Path
    function removeLiquidityAndSwapETH(uint256 _pid, uint256 amount)
        internal
        returns (uint256)
    {
        FeeData storage feeInfo = feeData[_pid];
        // SWAP WITH ONE TOKEN ALREADY WETH
        if (
            tokenPath[_pid][0] == tokenRouter.WETH() ||
            tokenPath[_pid][1] == tokenRouter.WETH()
        ) {
            IERC20 nonEthToken;
            address[] memory path;
            bool tokenFees;
            (nonEthToken, path, tokenFees) = getNotEthToken(_pid);
            if (feeInfo.hasFees)
                feeInfo.router.removeLiquidityETHSupportingFeeOnTransferTokens(
                    address(nonEthToken),
                    amount,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            else
                feeInfo.router.removeLiquidityETH(
                    address(nonEthToken),
                    amount,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            uint256 tokensLeft = nonEthToken.balanceOf(address(this));
            nonEthToken.approve(address(feeInfo.router), tokensLeft);
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
            (uint256 tokenA, uint256 tokenB) = feeInfo.router.removeLiquidity(
                tokenPath[_pid][0],
                tokenPath[_pid][1],
                amount,
                0,
                0,
                address(this),
                block.timestamp
            );
            // Approve tokens for swap
            IERC20(tokenPath[_pid][0]).approve(
                address(feeInfo.router),
                tokenA * 2
            );
            IERC20(tokenPath[_pid][1]).approve(
                address(feeInfo.router),
                tokenB * 2
            );
            // Swap token A
            if (feeInfo.token0Fees)
                feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        tokenA,
                        0,
                        token0Path[_pid],
                        address(this),
                        block.timestamp
                    );
            else
                feeInfo.router.swapExactTokensForETH(
                    tokenA,
                    0,
                    token0Path[_pid],
                    address(this),
                    block.timestamp
                );
            // Swap token B
            if (feeInfo.token1Fees)
                feeInfo
                    .router
                    .swapExactTokensForETHSupportingFeeOnTransferTokens(
                        tokenB,
                        0,
                        token1Path[_pid],
                        address(this),
                        block.timestamp
                    );
            else
                feeInfo.router.swapExactTokensForETH(
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
            totalCrush += x < 3
                ? feeInfo.crushFees[x]
                : feeInfo.crushFees[x] / 2;
            if (x < 3) {
                niceFees += feeInfo.niceFees[x];
                totalNice += x == 0
                    ? feeInfo.niceFees[x]
                    : feeInfo.niceFees[x] / 2;
            }
        }
        address[] memory path;
        path[0] = tokenRouter.WETH();
        path[1] = CRUSH;
        if (crushFees > 0) {
            bnbForCrush = (address(this).balance * crushFees) / DIVISOR;
            swapAmountCrush = (bnbForCrush * totalCrush) / crushFees;
            // Swap for CRUSH
            tokenRouter.swapExactETHForTokens{value: swapAmountCrush}(
                0,
                path,
                address(this),
                block.timestamp
            );
            bnbForCrush -= swapAmountCrush;
            tokenAndLiquidityDistribution(
                CRUSH,
                feeInfo,
                crushFees,
                false,
                bnbForCrush
            );
        }
        if (niceFees > 0) {
            bnbForNice = (address(this).balance * niceFees) / DIVISOR;
            swapAmountNice = (bnbForNice * totalNice) / niceFees;
            bnbForNice -= swapAmountNice;
            // Swap for NICE
            path[1] = NICE;
            tokenRouter.swapExactETHForTokens{value: swapAmountNice}(
                0,
                path,
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

        // If there's some ETH left, send to marketing wallet
        uint256 ethBal = address(this).balance;
        if (ethBal > 0) {
            (bool success, ) = payable(teamWallet).call{value: ethBal}("");
            emit TeamFundsDistributed(success, ethBal);
        }
    }

    function tokenAndLiquidityDistribution(
        address token,
        FeeData storage feeInfo,
        uint256 totalFees,
        bool isNice,
        uint256 liquidityETH
    ) internal {
        ERC20Burnable mainToken = ERC20Burnable(token);
        uint256 currentBalance = mainToken.balanceOf(address(this));
        // BUYBACK AND BURN
        uint256 usedFee = isNice ? feeInfo.niceFees[0] : feeInfo.crushFees[0];
        uint256 amountToUse = (currentBalance * usedFee) / totalFees;
        if (amountToUse > 0) mainToken.burn(amountToUse);
        // BUYBACK AND DISTRIBUTE TO STAKING POOL
        usedFee = isNice ? 0 : feeInfo.crushFees[1];
        amountToUse = (currentBalance * usedFee) / totalFees;
        if (amountToUse > 0) {
            mainToken.approve(address(bankroll), amountToUse * 2);
            bankroll.addUserLoss(amountToUse);
        }
        // BUYBACK AND LOTTERY
        usedFee = isNice ? 0 : feeInfo.crushFees[2];
        amountToUse = (currentBalance * usedFee) / totalFees;
        if (amountToUse > 0) {
            mainToken.approve(address(lottery), amountToUse * 2);
            lottery.addToPool(amountToUse);
        }
        // Since we'll send liquidity straight to the required addresses, addLiquidity needs to happen twice\
        currentBalance = mainToken.balanceOf(address(this));
        if (isNice)
            (totalFees, ) = liquidityFeeTotal(
                feeInfo.niceFees,
                feeInfo.crushFees
            );
        else
            (, totalFees) = liquidityFeeTotal(
                feeInfo.niceFees,
                feeInfo.crushFees
            );
        if (totalFees == 0) return;
        // PERMANENT LIQUIDITY
        usedFee = isNice ? feeInfo.niceFees[1] : feeInfo.crushFees[3];
        amountToUse = (currentBalance * usedFee) / totalFees;
        uint256 ethToUse = (liquidityETH * usedFee) / totalFees;
        if (amountToUse > 0) {
            mainToken.approve(address(tokenRouter), amountToUse * 2);
            tokenRouter.addLiquidityETH{value: ethToUse}(
                address(mainToken),
                amountToUse,
                0,
                0,
                deadWallet, // "burn" immediately
                block.timestamp
            );
        }
        // LOCK LIQUIDITY
        usedFee = isNice ? feeInfo.niceFees[2] : feeInfo.crushFees[4];
        amountToUse = (currentBalance * usedFee) / totalFees;
        ethToUse = (liquidityETH * usedFee) / totalFees;
        if (amountToUse > 0) {
            mainToken.approve(address(tokenRouter), amountToUse * 2);
            tokenRouter.addLiquidityETH{value: ethToUse}(
                address(mainToken),
                amountToUse,
                0,
                0,
                lock, // send Tokens to LOCK contract
                block.timestamp
            );
        }
    }

    /*************************
     *        GETTERS        *
     *************************/
    function getFees(uint256 _pid)
        external
        view
        returns (uint256[3] memory _niceFees, uint256[5] memory _crushFees)
    {
        _niceFees = feeData[_pid].niceFees;
        _crushFees = feeData[_pid].crushFees;
    }

    /*************************
     *        SETTERS        *
     *************************/
    /// @notice Update the main router used to spread liquidity
    /// @param _newRouter address of the router to migrate to
    /// @dev Requires the router to exist
    function setBaseRouter(address _newRouter) external onlyOwner {
        require(_newRouter != address(0), "No zero");
        tokenRouter = IPancakeRouter(_newRouter);
        emit UpdateMainRouter(_newRouter);
    }

    /// @notice Update the Marketing Wallet
    /// @param _newTeamW address to send funds to
    /// @dev requires address to be payable since it'll receive BNB(ETH) directly
    function setTeamWallet(address payable _newTeamW) external onlyOwner {
        require(_newTeamW != address(0), "Cant pay 0");
        teamWallet = _newTeamW;
        emit UpdateTeamWallet(_newTeamW);
    }

    /// @notice Update the paths used for a specific pool
    /// @param id the Pool ID
    /// @param _path path of the token, if LP, tokens that comprise it, else route to ETH
    /// @param _path1 if LP, token0 path to ETH, else empty;
    /// @param _path2 if LP, token1 path to ETH, else empty;
    function updatePaths(
        uint256 id,
        address[] calldata _path,
        address[] calldata _path1,
        address[] calldata _path2
    ) public onlyOwner {
        tokenPath[id] = _path;
        token0Path[id] = _path1;
        token1Path[id] = _path2;
    }

    /// @notice Update the Target Price to compare to for NICE buy back and burn only.
    /// @param _price new Target price to attempt to reach
    function updateIdoTarget(uint256 _price) external onlyOwner {
        require(_price > 0, "Invalid target");
        idoPrice = _price;
        emit UpdateTargetPrice(_price);
    }

    /// @notice Toggle between enabling and disabling NICE target price Search
    function enableTargetSearch(bool _enable) external onlyOwner {
        require(reachForIdo != _enable, "Already in state");
        reachForIdo = _enable;
        emit SeachForTarget(_enable);
    }

    function updateLottery(address _nLottery) external onlyOwner {
        require(_nLottery != address(0), "No Zero");
        emit UpdateLotteryAddress(_nLottery, address(lottery));
        lottery = IBitcrushLottery(_nLottery);
    }

    /*************************
     *      Calculations     *
     *************************/
    function liquidityFeeTotal(uint256[3] storage _ar1, uint256[5] storage _ar2)
        internal
        view
        returns (uint256 _liquidityNice, uint256 _liquidityCrush)
    {
        _liquidityNice = _ar1[1] + _ar1[2];
        _liquidityCrush = _ar2[3] + _ar2[4];
    }

    function addArrays(uint256[3] calldata _ar1, uint256[5] calldata _ar2)
        internal
        pure
        returns (uint256 _result)
    {
        for (uint8 i = 0; i < 5; i++) {
            _result += _ar2[i];
            if (i < 3) {
                _result += _ar1[i];
            }
        }
    }
}
