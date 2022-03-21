// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IPancakeFactory.sol";

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

    IERC20 public immutable crush;
    IERC20 public immutable nice;

    IPancakeRouter public routerCrush;
    IPancakeRouter public routerNice;

    mapping(uint256 => FeeData) public feeData;
    mapping(uint256 => address[]) public tokenPath; // token Composition if SingleAsset length = 1, if LP length = 2
    mapping(uint256 => address[]) public token0Path; // LP TOKEN 0 TO WBNB
    mapping(uint256 => address[]) public token1Path; // LP TOKEN 1 TO WBNB

    event EditFeeOfPool(uint256 _pid);

    constructor(
        address _router,
        address _nice,
        address _crush
    ) {
        crush = IERC20(_crush);
        nice = IERC20(_nice);

        routerCrush = IPancakeRouter(_router);
        routerNice = IPancakeRouter(_router);
    }

    receive() external payable {}

    fallback() external payable {}

    function swapForToken(uint256 _bnb, bool isNice)
        public
        returns (uint256 _tokenReceived)
    {
        require(_bnb <= address(this).balance); // dev: ETH balance doesn't match available balance
        address[] memory path = new address[](2);
        IPancakeRouter router = isNice ? routerNice : routerCrush;
        path[0] = router.WETH();
        path[1] = isNice ? address(nice) : address(crush);
        router.swapExactETHForTokens{value: _bnb}(
            0, // We get what we can
            path,
            address(this),
            block.timestamp
        );
    }

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
        emit EditFeeOfPool(_pid);
    }

    /// @notice from the POOL ID check which token is wETH and return the other one
    /// @param _pid the Pool ID token path to check
    function getNotEthToken(uint256 _pid)
        public
        view
        returns (
            IERC20 token,
            address[] memory path,
            bool hasFees
        )
    {
        if (tokenPath[_pid][0] != routerCrush.WETH()) {
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
        public
        returns (uint256)
    {
        FeeData storage feeInfo = feeData[_pid];
        approveLiquiditySpend(_pid, feeInfo);

        // SWAP WITH ONE TOKEN ALREADY WETH
        if (
            tokenPath[_pid][0] == routerNice.WETH() ||
            tokenPath[_pid][1] == routerNice.WETH()
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

    function addArrays(uint256[3] calldata _ar1, uint256[5] calldata _ar2)
        public
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

    function approveLiquiditySpend(uint256 _pid, FeeData storage feeInfo)
        internal
    {
        address factory = feeInfo.router.factory();
        address pair = IPancakeFactory(factory).getPair(
            tokenPath[_pid][0],
            tokenPath[_pid][1]
        );
        IERC20 pairToken = IERC20(pair);
        uint256 balance = pairToken.balanceOf(address(this));
        pairToken.approve(address(feeInfo.router), balance);
    }
}
