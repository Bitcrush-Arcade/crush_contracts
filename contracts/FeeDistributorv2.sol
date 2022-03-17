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

contract FeeDistributorV2 is Ownable {
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
    address public immutable baseToken; // wBNB || wETH || etc
    address public CRUSH;
    address public NICE;
    address public immutable deadWallet =
        0x000000000000000000000000000000000000dEaD;
    IPancakeRouter public tokenRouter; //used for CRUSH and NICE
    address public niceLiquidity;
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
        uint256 _idoPrice,
        address _nicePair
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
        niceLiquidity = _nicePair;
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
        emit AddPoolFee(_pid);
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
        // GET PORTION AMOUNTS
        distributeFees(feeInfo);
    }

    /// @notice Check that current Nice Price is above IDO
    /// @dev 
    function checkPrice() public view returns (bool _aboveIDO) {
        (uint256 reserve0, uint256 reserve1, ) = IPancakePair(niceLiquidity)
            .getReserves();
        reserve1 = reserve1 > 0 ? reserve1 : 1; //just in case
        _aboveIDO = ((reserve0 * 1 ether) / reserve1) > idoPrice;
    }

    function setBaseRouter(address _newRouter) external onlyOwner {
        require(_newRouter != address(0), "No zero");
        tokenRouter = IPancakeRouter(_newRouter);
        emit UpdateRouter(_newRouter);
    }

    function setTeamWallet(address _newTeamW) external onlyOwner {
        require(_newTeamW != address(0), "Cant pay 0");
        teamWallet = _newTeamW;
        emit UpdateTeamWallet(_newTeamW);
    }

    function getBuybackFee(FeeData storage feeInfo, bool isNice)
        internal
        returns (uint256 _bbFees)
    {
        return 0;
        // TODO!!!!!!!
    }

    function getLiquidityFee(FeeData storage feeInfo)
        internal
        returns (uint256 _bbFees)
    {
        // TODO!!!!
        return 0;
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
        if (tokenPath[_pid][0] != tokenRouter.WETH()) {
            token = IERC20(tokenPath[_pid][0]);
            path = token0Path[_pid];
            hasFees = feeData[_pid].token0Fees;
        } else {
            token = IERC20(tokenPath[_pid][1]);
            path = token1Path[_pid];
        }
    }

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
            IERC20(tokenPath[_pid][0]).approve(address(feeInfo.router), tokenA);
            IERC20(tokenPath[_pid][1]).approve(address(feeInfo.router), tokenB);
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
        address[] memory path;
        path[0] = tokenRouter.WETH();
        path[1] = CRUSH;
        // Swap for CRUSH
        tokenRouter.swapExactETHForTokens{value: swapAmountCrush}(
            0,
            path,
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

    function tokenAndLiquidityDistribution(
        address token,
        FeeData storage feeInfo,
        uint256 totalFees,
        bool isNice,
        uint256 liquidityETH
    ) internal {
        ERC20Burnable mainToken = ERC20Burnable(token);
        uint256 currentBalance = mainToken.balanceOf(address(this));
        uint256 usedFee = isNice ? feeInfo.niceFees[0] : feeInfo.crushFees[0];
        uint256 amountToUse = (currentBalance * usedFee) / totalFees;
        if (amountToUse > 0) mainToken.burn(amountToUse);
        usedFee = isNice ? 0 : feeInfo.crushFees[1];
        amountToUse = (currentBalance * usedFee) / totalFees;
        if (amountToUse > 0) {
            if (isNice) {}
        }
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

    function updatePaths(
        uint256 id,
        address[] calldata _path,
        address[] calldata _path1,
        address[] calldata _path2
    ) internal {
        tokenPath[id] = _path;
        token0Path[id] = _path1;
        token1Path[id] = _path2;
    }
}
