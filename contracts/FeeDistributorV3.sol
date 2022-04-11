// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INICEToken.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/ILottery.sol";
import "../interfaces/IBankroll.sol";
import "./GalacticChef.sol";

contract FeeDistributorV3 is Ownable {
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

    uint256 public constant DIVISOR = 10000; // 100.00%

    INICEToken public immutable crush;
    INICEToken public immutable nice;
    address public immutable deadWallet =
        0x000000000000000000000000000000000000dEaD;
    address public immutable chef;
    address public immutable lockWallet;
    address public immutable bankroll;
    address public marketingWallet;
    address public lottery;
    IPancakeRouter public routerCrush;
    IPancakeRouter public routerNice;

    mapping(uint256 => FeeData) public feeData;
    mapping(uint256 => address[]) public tokenPath; // token Composition if SingleAsset length = 1, if LP length = 2
    mapping(uint256 => address[]) public token0Path; // LP TOKEN 0 TO WBNB
    mapping(uint256 => address[]) public token1Path; // LP TOKEN 1 TO WBNB

    event EditFeeOfPool(uint256 _pid);
    event LockLiquidity(address indexed _burnToken, uint256 _amount);
    event BurnLiquidity(address indexed _burnToken, uint256 _amount);
    event UpdateLottery(address _newLottery, address _oldLottery);
    event UpdateMarketing(address _newWallet, address _oldWallet);
    event FundMarketing(address indexed _wallet, uint256 amount);
    event UpdateRouter(
        address _newRouter,
        address _oldRouter,
        bool _niceRouter
    );

    constructor(
        address _router,
        address _nice,
        address _crush,
        address _chef,
        address _lock,
        address _bankroll,
        address _marketing
    ) {
        require(
            _router != address(0) &&
                _nice != address(0) &&
                _crush != address(0) &&
                _chef != address(0) &&
                _lock != address(0) &&
                _bankroll != address(0) &&
                _marketing != address(0),
            "No zero address"
        );
        crush = INICEToken(_crush);
        nice = INICEToken(_nice);

        chef = _chef;
        lockWallet = _lock;
        bankroll = _bankroll;
        marketingWallet = _marketing;
        routerCrush = IPancakeRouter(_router);
        routerNice = IPancakeRouter(_router);
    }

    receive() external payable {}

    fallback() external payable {}

    /// @notice Swaps amount of BNB to CRUSH or NICE
    /// @param _bnb the amount of BNB to swap
    /// @param isNice selects between NICE and CRUSH
    /// @return _tokenReceived amount of token that is available now
    function swapForToken(uint256 _bnb, bool isNice)
        internal
        returns (uint256 _tokenReceived)
    {
        require(_bnb <= address(this).balance, "Balance not available"); // dev: ETH balance doesn't match available balance
        address[] memory path = new address[](2);
        INICEToken token = isNice ? nice : crush;
        IPancakeRouter router = isNice ? routerNice : routerCrush;
        path[0] = router.WETH();
        path[1] = address(token);
        router.swapExactETHForTokens{value: _bnb}(
            0, // We get what we can
            path,
            address(this),
            block.timestamp
        );
        _tokenReceived = token.balanceOf(address(this));
    }

    function addorEditFee(
        uint256 _pid, //ID TO ADD/EDIT
        uint256[3] calldata _niceFees, // 0 buyback BURN, 1 liquidity PERMANENT, 2 liquidity LOCK
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
        emit EditFeeOfPool(_pid);
    }

    /// @notice from the POOL ID check which token is wETH and return the other one
    /// @param _pid the Pool ID token path to check
    function getNotEthToken(uint256 _pid)
        internal
        view
        returns (
            INICEToken token,
            address[] memory path,
            bool hasFees
        )
    {
        if (tokenPath[_pid][0] != routerCrush.WETH()) {
            token = INICEToken(tokenPath[_pid][0]);
            path = token0Path[_pid];
            hasFees = feeData[_pid].token0Fees;
        } else {
            token = INICEToken(tokenPath[_pid][1]);
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
        approveLiquiditySpend(_pid, feeInfo);

        // SWAP WITH ONE TOKEN ALREADY WETH
        if (
            tokenPath[_pid][0] == routerNice.WETH() ||
            tokenPath[_pid][1] == routerNice.WETH()
        ) {
            INICEToken nonEthToken;
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
            INICEToken(tokenPath[_pid][0]).approve(
                address(feeInfo.router),
                tokenA * 2
            );
            INICEToken(tokenPath[_pid][1]).approve(
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

    /// @notice adds the values of two arrays of length 3 and 5 respectively.
    /// @param _ar1 is the array of length 3
    /// @param _ar2 is the array of length 5
    /// @dev this is used to prevent Stack too deep error on Add/Edit Fee
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

    /// @notice Get the paths either for frontend or server information
    /// @param _pid The pool Id to check for
    /// @return path The token Path to BNB.. if LP the token composition
    /// @return path0 the token0 path to BNB for LP token0
    /// @return path1 the token1 path to BNB fro LP token1
    function getPath(uint256 _pid)
        external
        view
        returns (
            address[] memory path,
            address[] memory path0,
            address[] memory path1
        )
    {
        path = tokenPath[_pid];
        path0 = token0Path[_pid];
        path1 = token1Path[_pid];
    }

    /// @notice Simplify approving liquidity spend by router
    /// @param _pid the pool ID to get the data from
    /// @param feeInfo feeInfo to pull token router from
    function approveLiquiditySpend(uint256 _pid, FeeData storage feeInfo)
        internal
    {
        address factory = feeInfo.router.factory();
        address pair = IPancakeFactory(factory).getPair(
            tokenPath[_pid][0],
            tokenPath[_pid][1]
        );
        INICEToken pairToken = INICEToken(pair);
        uint256 balance = pairToken.balanceOf(address(this));
        require(balance > 0, "No balance"); // dev: No LP tokens available, please send some
        pairToken.approve(address(feeInfo.router), balance);
    }

    /// @notice get the BNB used to spread for swap and keep some for Liquidity
    /// @param _pid pool Id to get the feeInfo
    /// @param currentBalance Balance to distribute
    /// @param isNice determine to get either nice or crush values
    /// @dev Please note that liquidity amount is divided in two since only half of that goes to liquidity
    /// @return _bnbForToken amount of BNB used to swap for token
    /// @return _bnbLiqPerm amount of BNB used for Permanent Liquidity
    /// @return _bnbLiqLock amount of BNB used for Liquidity that will be locked
    function feeSpread(
        uint256 _pid,
        uint256 currentBalance,
        bool isNice
    )
        internal
        view
        returns (
            uint256 _bnbForToken,
            uint256 _bnbLiqPerm,
            uint256 _bnbLiqLock
        )
    {
        FeeData storage feeInfo = feeData[_pid];
        if (isNice) {
            _bnbForToken = (currentBalance * feeInfo.niceFees[0]) / DIVISOR;
            _bnbLiqPerm =
                (currentBalance * feeInfo.niceFees[1]) /
                (2 * DIVISOR);
            _bnbLiqLock =
                (currentBalance * feeInfo.niceFees[2]) /
                (2 * DIVISOR);
            _bnbForToken += _bnbLiqLock + _bnbLiqPerm;
        } else {
            uint256 tokenFees = feeInfo.crushFees[0] +
                feeInfo.crushFees[1] +
                feeInfo.crushFees[2];
            _bnbForToken = (currentBalance * tokenFees) / DIVISOR;
            _bnbLiqPerm =
                (currentBalance * feeInfo.crushFees[3]) /
                (2 * DIVISOR);
            _bnbLiqLock =
                (currentBalance * feeInfo.crushFees[4]) /
                (2 * DIVISOR);
        }
    }

    /// @notice Receive fee tokens and distribute them
    /// @param _pid The pool ID that will get the fees
    /// @param amount the amount of tokens received
    /// @dev IF WE HAVE NO AMOUNT, DO NOTHING!!!
    function receiveFees(uint256 _pid, uint256 amount) external {
        FeeData storage feeInfo = feeData[_pid];
        if (feeInfo.initialized != true) return;
        // Exchange Token for ETH
        if (token0Path[_pid].length > 0)
            removeLiquidityAndSwapETH(_pid, amount);
        else swapForEth(_pid, feeInfo, amount);

        uint256 bnbBalance = address(this).balance;
        // IF PRICE IS BELOW IDO
        // SWAP ALL FOR NICE AND BURN

        // Get Fee spread
        // CRUSH FIRST
        uint256 tokenAmountUsed;
        (
            uint256 tokenAmount,
            uint256 permAmount,
            uint256 lockAmount
        ) = feeSpread(_pid, bnbBalance, false);
        if (tokenAmount > 0) {
            swapForToken(tokenAmount, false);
            tokenAmountUsed = crush.balanceOf(address(this));
            if (lockAmount + permAmount > 0) {
                tokenAmountUsed =
                    (tokenAmountUsed * (permAmount + lockAmount)) /
                    (tokenAmount + permAmount + lockAmount);
                addAndDistributeLiquidity(
                    tokenAmountUsed,
                    permAmount,
                    lockAmount,
                    false
                );
                tokenAmountUsed = crush.balanceOf(address(this));
            }
            if (tokenAmountUsed > 0) {
                tokenAmount =
                    feeInfo.crushFees[0] +
                    feeInfo.crushFees[1] +
                    feeInfo.crushFees[2];
                //We're just reusing variables  to save stack depth
                //LOTTERY
                permAmount =
                    (tokenAmountUsed * feeInfo.crushFees[2]) /
                    tokenAmount;
                if (lottery != address(0) && permAmount > 0) {
                    crush.approve(lottery, permAmount);
                    IBitcrushLottery(lottery).addToPool(permAmount);
                }
                //STAKING
                lockAmount =
                    (tokenAmountUsed * feeInfo.crushFees[1]) /
                    tokenAmount;
                if (bankroll != address(0) && lockAmount > 0) {
                    crush.approve(bankroll, lockAmount);
                    IBitcrushBankroll(bankroll).addUserLoss(lockAmount);
                }
                // BURN THE REST
                tokenAmountUsed = crush.balanceOf(address(this));
                crush.burn(tokenAmountUsed);
            }
        }
        // NICE SECOND
        (tokenAmount, permAmount, lockAmount) = feeSpread(
            _pid,
            bnbBalance,
            true
        );
        if (tokenAmount > 0) swapForToken(tokenAmount, true);
        if (lockAmount + permAmount > 0) {
            tokenAmountUsed = nice.balanceOf(address(this));
            tokenAmountUsed =
                (tokenAmountUsed * (permAmount + lockAmount)) /
                (tokenAmount + permAmount + lockAmount);
            addAndDistributeLiquidity(
                tokenAmountUsed,
                permAmount,
                lockAmount,
                true
            );
        }
        tokenAmount = nice.balanceOf(address(this));
        if (tokenAmount > 0) {
            //BURN IT ALL
            nice.burn(tokenAmount);
        }
        bnbBalance = address(this).balance;
        if (bnbBalance > 0) {
            (bool success, ) = payable(marketingWallet).call{value: bnbBalance}(
                ""
            );
            if (success) emit FundMarketing(marketingWallet, bnbBalance);
        }
    }

    /// @notice Exchange token for BNB
    /// @param _pid The id of the pool to get the tokenPath to BNB
    /// @param feeInfo All fee info data, it's type storage to use internally on the receiveFees fn
    /// @param amount The amount of tokens to swap
    /// @dev This works only for straight ERC20 contracts
    function swapForEth(
        uint256 _pid,
        FeeData storage feeInfo,
        uint256 amount
    ) internal {
        INICEToken token = INICEToken(tokenPath[_pid][0]);
        require(token.balanceOf(address(this)) > 0, "Wallet empty"); // dev: NO LP, Wallet empty, please send funds
        token.approve(address(feeInfo.router), amount);
        if (feeInfo.hasFees)
            feeInfo.router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                0,
                tokenPath[_pid],
                address(this),
                block.timestamp
            );
        else
            feeInfo.router.swapExactTokensForETH(
                amount,
                0,
                tokenPath[_pid],
                address(this),
                block.timestamp
            );
    }

    /// @notice addLiquidity and send the liquidity to either burn or lock
    /// @param tokenAmount the amount of TOKEN to change into liquidity
    /// @param permanentLiq the amount of relative liquidity to be sent to deadWallet
    /// @param lockLiq amount of liquidity to be sent to lock
    function addAndDistributeLiquidity(
        uint256 tokenAmount,
        uint256 permanentLiq,
        uint256 lockLiq,
        bool isNice
    ) internal {
        IPancakeRouter router = isNice ? routerNice : routerCrush;
        INICEToken token = isNice ? nice : crush;
        uint256 ethValue = permanentLiq + lockLiq;
        token.approve(address(router), tokenAmount);
        (, , uint256 liquidity) = router.addLiquidityETH{value: ethValue}(
            address(token),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
        IPancakeFactory factory = IPancakeFactory(router.factory());
        address ETH = router.WETH();
        INICEToken liqToken = INICEToken(factory.getPair(address(token), ETH));
        uint256 liqAmount;
        if (permanentLiq > 0) {
            liqAmount = (liquidity * permanentLiq) / (permanentLiq + lockLiq);
            bool success = liqToken.transfer(deadWallet, liqAmount);
            if (success) emit BurnLiquidity(address(token), liqAmount);
        }
        if (lockLiq > 0) {
            liquidity = liqToken.balanceOf(address(this));
            bool success = liqToken.transfer(lockWallet, liquidity);
            if (success) emit LockLiquidity(address(token), liquidity);
        }
    }

    function editLottery(address _lotteryAddress) external onlyOwner {
        require(
            _lotteryAddress != lottery && _lotteryAddress != address(0),
            "Invalid address"
        ); // dev: Lottery can't be  same address
        emit UpdateLottery(_lotteryAddress, lottery);
        lottery = _lotteryAddress;
    }

    function editMarketing(address _marketingAddress) external onlyOwner {
        require(
            _marketingAddress != marketingWallet &&
                _marketingAddress != address(0),
            "Invalid address"
        ); // dev: Lottery can't be  same address
        emit UpdateMarketing(_marketingAddress, marketingWallet);
        marketingWallet = _marketingAddress;
    }

    function editRouter(address _newRouter, bool isNice) external onlyOwner {
        require(_newRouter != address(0), "No zero address");
        if (isNice) {
            require(_newRouter != address(routerNice), "Invalid Address"); // dev: can't add same router
            emit UpdateRouter(_newRouter, address(routerNice), isNice);
            routerNice = IPancakeRouter(_newRouter);
        } else {
            require(_newRouter != address(routerCrush), "Invalid Address"); // dev: can't add same router
            emit UpdateRouter(_newRouter, address(routerCrush), isNice);
            routerCrush = IPancakeRouter(_newRouter);
        }
    }
}
