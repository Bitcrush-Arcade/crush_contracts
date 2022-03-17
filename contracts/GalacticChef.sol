// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NICEToken.sol";
import "../interfaces/IFeeDistributor.sol";

//import "../interfaces/IGalacticChef.sol";
///@dev use interface IGalacticChef

contract GalacticChef is Ownable, ReentrancyGuard {
    using SafeERC20 for NICEToken;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; //Staked Amount
        uint256 accClaim; //ClaimedReward accumulation
    }

    struct PoolInfo {
        bool poolType;
        uint256 mult;
        uint256 fee;
        IERC20 token;
        uint256 accRewardPerShare;
        uint256 lastRewardTs;
        bool isLP;
    }
    /// Timestamp Specific
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 constant SECONDS_PER_HOUR = 60 * 60;
    uint256 constant SECONDS_PER_MINUTE = 60;
    int256 constant OFFSET19700101 = 2440588;
    /*
     ** We have two different types of pools: Regular False, Third True
     ** Nice has a fixed emission given per second due to tokenomics
     ** So we decided to give a FIXED percentage reward to some pools
     ** REGULAR pools distribute the remaining reward amongst their allocation
     ** Third Party doesn't keep track of the user's info, but rather only keeps track of the rewards being given.
     */
    /*
     ** Reward Calculation:
     ** Fixed Pool Rewards = Emission*allocation / PERCENT
     ** Regular Pool Rewards = Emission*( 1e12 - fixedAlloc*1e12/PERCENT) * allocation/regularAlloc / 1e12
     ** 1e12 is used to cover for fraction issues
     */
    /*
     ** Emission Distrubution
     ** Treasury: 5% of total YEARLY emissions
     ** DeFi: All Pools and farms added here ->  30% of All emissions minus treasury
     ** P2E: 70% of all Emissions minus treasury
     ** Percentages will be able to be edited depending on needs
     */
    // These Values use FEE_DIV BASE as 100%
    uint256 public defiPercent = 3000; //init 30%
    uint256 public p2ePercent = 7000; // init 70%
    uint256 public treasuryPercent = 500; // init 5%

    uint256 public constant PERCENT = 1e12; // Divisor for percentage calculations
    uint256 public constant FEE_DIV = 10000; // Divisor for fee percentage 100.00
    uint256 public constant maxMult = 1000000; // Max Multiplier 100.0000
    uint256 public currentMax; // The current multiplier total. Always <= maxMult
    address public feeAddress; // Address where fees will be sent to for Distribution/Reallocation

    // The number of chains where a GalacticChef exists. This helps have a consistent emission across all chains.
    uint256 public chains;
    // Time when Chef will start emitting Tokens
    uint256 public immutable chefStart;
    // Emissions per second. Since we'll have multiple Chefs across chains the emission set per second
    uint256 public immutable initMax = 2000000000 ether; // 1st year will emmit 1.5B tokens since 500M have a purpose already
    uint256 public immutable initDiff = 500000000 ether;
    uint256 public poolCounter;
    uint256 public nonDefiLastRewardTransfer;

    // Reward Token
    NICEToken public NICE;

    // FEE distribution
    IFeeDistributor public feeDistributor;
    address public treasury;
    address public p2e;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // PID => USER_ADDRESS => userInfo
    mapping(uint256 => PoolInfo) public poolInfo; // PID => PoolInfo
    mapping(uint256 => address) public tpPools; //  PID => poolAddress
    mapping(address => uint256) public tokenPools; // tokenAddress => poolId

    event PoolAdded(
        address token,
        uint256 multiplier,
        uint256 fee,
        bool _type,
        uint256 _pid
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event UpdatePools(uint256[] pid, uint256[] mult);
    event UpdatePool(uint256 indexed pid, uint256 mult, uint256 fee);
    event UpdateEmissions(uint256 amount);
    event FeeAddressEdit(address _newAddress, bool _isContract);
    event UpdateTreasury(address _newAddress);
    event UpdateP2E(address _newAddress);
    event ChainUpdate(uint256 _chainAmount);

    event LogEvent(uint256 number, string data);

    constructor(
        address _niceToken,
        address _treasury,
        address _p2e,
        uint256 _chains
    ) {
        NICE = NICEToken(_niceToken);
        feeAddress = msg.sender;
        chains = _chains;
        chefStart = block.timestamp + 6 hours;
        treasury = _treasury;
        p2e = _p2e;
        nonDefiLastRewardTransfer = chefStart;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(
            _treasury != address(0) && _treasury != address(0xdEad),
            "No Zero Address"
        );
        treasury = _treasury;
        emit UpdateTreasury(_treasury);
    }

    function setP2E(address _p2e) external onlyOwner {
        require(
            _p2e != address(0) && _p2e != address(0xdEad),
            "No Zero Address"
        );
        p2e = _p2e;
        emit UpdateP2E(_p2e);
    }

    /// @notice Add Farm of a specific token
    /// @param _token the token that will be collected, Taken as address since ThirdParty pools will handle their own logic
    /// @param _mult the multiplier the pool will have
    /// @param _fee the fee to deposit on the pool
    /// @param _isLP is the token an LP token
    /// @param _type is it a regular pool or a third party pool ( TRUE = ThirdParty )
    /// @param _pidEdit is it a regular pool or a third party pool ( TRUE = ThirdParty )
    /// @param _pidMulEdit is it a regular pool or a third party pool ( TRUE = ThirdParty )
    function addPool(
        address _token,
        uint256 _mult,
        uint256 _fee,
        bool _type,
        bool _isLP,
        uint256[] calldata _pidEdit,
        uint256[] calldata _pidMulEdit
    ) external onlyOwner {
        require(_pidEdit.length == _pidMulEdit.length, "add: wrong edits");
        require(_fee < 5001, "add: invalid fee");
        require(tokenPools[_token] == 0, "add: token repeated");
        //update multipliers and current Max
        updateMultipliers(_pidEdit, _pidMulEdit);
        require(currentMax + _mult <= maxMult, "add: wrong multiplier");
        currentMax = currentMax + _mult;
        poolCounter++;
        if (block.timestamp < chefStart)
            poolInfo[poolCounter] = PoolInfo(
                _type,
                _mult,
                _fee,
                IERC20(_token),
                0,
                chefStart,
                _isLP
            );
        else
            poolInfo[poolCounter] = PoolInfo(
                _type,
                _mult,
                _fee,
                IERC20(_token),
                0,
                block.timestamp,
                _isLP
            );
        tokenPools[_token] = poolCounter;
        if (_type) tpPools[poolCounter] = _token;
        emit PoolAdded(_token, _mult, _fee, _type, poolCounter);
    }

    // Make sure multipliers match
    /// @notice update the multipliers used
    /// @param _pidEdit pool Id Array
    /// @param _pidMulEdit multipliers edit array
    /// @dev both param arrays must have matching lengths
    function updateMultipliers(
        uint256[] calldata _pidEdit,
        uint256[] calldata _pidMulEdit
    ) internal {
        if (_pidEdit.length == 0) return;
        // updateValues
        uint256 newMax = currentMax;
        for (uint256 i = 0; i < _pidEdit.length; i++) {
            require(
                address(poolInfo[_pidEdit[i]].token) != address(0),
                "mult: nonexistent pool"
            );
            //Update the pool reward per share before editing the multiplier
            updatePool(_pidEdit[i]);
            newMax = newMax - poolInfo[_pidEdit[i]].mult + _pidMulEdit[i];
            //decrease old val and increase new val
            poolInfo[_pidEdit[i]].mult = _pidMulEdit[i];
        }
        require(newMax <= maxMult, "mult: exceeds max");
        currentMax = newMax;
    }

    /// @notice this is for frontend only, calculates the pending reward for a particular user in a specific pool.
    /// @param _user User to calculate rewards to
    /// @param _pid Pool Id to calculate rewards of
    function pendingRewards(address _user, uint256 _pid)
        external
        view
        returns (uint256 _pendingRewards)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        if (user.amount == 0) {
            return 0;
        }
        uint256 updatedPerShare = pool.accRewardPerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTs && tokenSupply > 0) {
            uint256 multiplier = getTimeEmissions(pool) * pool.mult;
            uint256 maxMultiplier = currentMax * tokenSupply * PERCENT;
            updatedPerShare = updatedPerShare + (multiplier / maxMultiplier);
        }
        _pendingRewards = updatedPerShare * user.amount - user.accClaim;
    }

    /// @notice Update the accRewardPerShare for a specific pool
    /// @param _pid Pool Id to update the accumulated rewards
    function updatePool(uint256 _pid) public {
        distributeNonDefi();
        PoolInfo storage pool = poolInfo[_pid];
        uint256 selfBal = pool.token.balanceOf(address(this));
        if (
            pool.mult == 0 ||
            selfBal == 0 ||
            block.timestamp <= pool.lastRewardTs
        ) {
            pool.lastRewardTs = block.timestamp;
            return;
        }
        uint256 maxMultiplier = currentMax * selfBal;
        uint256 periodReward = (getTimeEmissions(pool) * pool.mult) /
            maxMultiplier;
        pool.lastRewardTs = block.timestamp;
        pool.accRewardPerShare = pool.accRewardPerShare + periodReward;
    }

    /// @notice getCurrentEmissions allows external users to get the current reward emissions
    /// It Uses getTimeEmissions to get the current emissions for the pool between last reward emission and current emission
    /// @param _pid Pool Id  from which we need emissions calculated
    /// @return _emissions emissions for the given pool between
    function getCurrentEmissions(uint256 _pid)
        public
        view
        returns (uint256 _emissions)
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.token) == address(0) || pool.mult == 0) return 0;
        _emissions = getTimeEmissions(pool);
    }

    /// @notice getCurrentEmissions calculates the current rewards between last reward emission and current emission timestamps
    /// The function takes into account if that period is within the same year since deployment or it spans across two different years, since the emission rate changes yearly
    /// @param _pool Pool Id  from which we need emissions calculated
    /// @return _emissions reward token emissions calculated between the last reward emission and the current emission
    function getTimeEmissions(PoolInfo storage _pool)
        internal
        view
        returns (uint256 _emissions)
    {
        uint256 poolYearDiff = (_pool.lastRewardTs - chefStart) / 365 days;
        if (poolYearDiff > 4 || block.timestamp < chefStart) return 0;
        uint256 yearDiff = (block.timestamp - chefStart) / 365 days;
        // If a Year has passed since pool lastRewardTS
        uint256 defiEmission;
        (, defiEmission, ) = getAllEmissions(poolYearDiff);
        if (yearDiff > poolYearDiff) {
            uint256 baseYear = yearDiff * 365 days + chefStart;
            uint256 timeDiff = baseYear - _pool.lastRewardTs;
            _emissions += (defiEmission * timeDiff * PERCENT) / chains;
            //Calculate nextYear's
            (, defiEmission, ) = getAllEmissions(yearDiff);
            timeDiff = block.timestamp - baseYear;
            _emissions += (defiEmission * timeDiff * PERCENT) / chains;
        } else {
            _emissions =
                (initMax * (block.timestamp - _pool.lastRewardTs) * PERCENT) /
                chains;
        }
    }

    function getYearlyEmissions(uint256 _yearsPassed)
        public
        view
        returns (uint256 _emission, uint256 _treasuryEmission)
    {
        if (_yearsPassed > 4) return (0, 0);
        _treasuryEmission =
            (initMax * treasuryPercent) /
            (FEE_DIV * (2**_yearsPassed));
        _emission =
            (initMax - _treasuryEmission - (_yearsPassed == 0 ? initDiff : 0)) /
            (2**_yearsPassed);
    }

    function getSecondEmissions(uint256 _yearsPassed)
        public
        view
        returns (uint256 _emission, uint256 _tEmission)
    {
        (uint256 others, uint256 _treasury) = getYearlyEmissions(_yearsPassed);
        _emission = others / SECONDS_PER_YEAR;
        _tEmission = _treasury / SECONDS_PER_YEAR;
    }

    function getAllEmissions(uint256 _yearsPassed)
        public
        view
        returns (
            uint256 _treasury,
            uint256 _defi,
            uint256 _p2e
        )
    {
        (uint256 _othersPerSec, uint256 _treasuryPerSec) = getSecondEmissions(
            _yearsPassed
        );
        _treasury = _treasuryPerSec;
        _p2e = (_othersPerSec * p2ePercent) / FEE_DIV;
        _defi = (_othersPerSec * defiPercent) / FEE_DIV;
    }

    function distributeNonDefi() public {
        if (block.timestamp <= nonDefiLastRewardTransfer) return;
        uint256 lastYearDiff = (nonDefiLastRewardTransfer - chefStart) /
            365 days;
        uint256 yearDiff = (block.timestamp - chefStart) / 365 days;
        uint256 totalTreasury;
        uint256 totalP2E;
        uint256 timeDiff;
        (uint256 _treasury, , uint256 _p2e) = getAllEmissions(lastYearDiff);
        if (yearDiff > lastYearDiff) {
            uint256 baseYear = yearDiff * 365 days + chefStart;
            timeDiff = baseYear - nonDefiLastRewardTransfer;
            totalTreasury = _treasury * timeDiff;
            totalP2E = _p2e * timeDiff;
            // Get for year change
            (_treasury, , _p2e) = getAllEmissions(yearDiff);
            timeDiff = block.timestamp - baseYear;
            totalTreasury += _treasury * timeDiff;
            totalP2E += _p2e * timeDiff;
        } else {
            timeDiff = block.timestamp - nonDefiLastRewardTransfer;
            totalTreasury = _treasury * timeDiff;
            totalP2E = _p2e * timeDiff;
        }

        nonDefiLastRewardTransfer = block.timestamp;
        NICE.mint(treasury, totalTreasury);
        NICE.mint(p2e, totalP2E);
    }

    /// @notice Update all pools accPerShare
    /// @dev this might be expensive to call...
    function massUpdatePools() public {
        for (uint256 id = 1; id <= poolCounter; id++) {
            emit LogEvent(id, "pool update");
            if (poolInfo[id].mult == 0) continue;
            if (!poolInfo[id].poolType) updatePool(id);
            else _mintRewards(id);
        }
    }

    /// @notice This is for Third party pools only. This handles the reward.
    /// @param _pid ID of the third party pool that requests minted rewards
    /// @return _rewardsGiven Amount of rewards minted to the third party pool
    function mintRewards(uint256 _pid)
        external
        nonReentrant
        returns (uint256 _rewardsGiven)
    {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.poolType && tpPools[_pid] == msg.sender, "Not tp pool");
        _rewardsGiven = _mintRewards(_pid);
    }

    /// @notice Internal function that Mints the amount of rewards calculated between last emission and current emission
    /// @param _pid ID of the third party pool that requests minted rewards
    /// @return _minted Amount of rewards minted to the pool
    function _mintRewards(uint256 _pid) internal returns (uint256 _minted) {
        distributeNonDefi();
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTs) return 0;
        _minted = (getTimeEmissions(pool) * pool.mult) / (currentMax * PERCENT);
        pool.lastRewardTs = block.timestamp;
        NICE.mint(address(pool.token), _minted);
    }

    /// @notice Allows user to deposit pool token to chef. Transfers rewards to user.
    /// @param _amount Amount of pool tokens to stake
    /// @param _pid Pool ID which indicates the type of token
    function deposit(uint256 _amount, uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.mult > 0, "Deposit: Pool disabled");
        require(!pool.poolType, "Deposit: Tp Pool");
        updatePool(_pid);
        //Harvest Rewards
        if (user.amount > 0) {
            uint256 pending = ((user.amount * pool.accRewardPerShare) /
                PERCENT) - user.accClaim;
            if (pending > 0) NICE.mint(msg.sender, pending);
        }
        uint256 usedAmount = _amount;
        if (usedAmount > 0) {
            if (pool.fee > 0) {
                usedAmount = (usedAmount * pool.fee) / FEE_DIV;
                if (address(feeDistributor) == address(0))
                    pool.token.safeTransferFrom(
                        address(msg.sender),
                        feeAddress,
                        usedAmount
                    );
                else {
                    pool.token.approve(address(feeDistributor), usedAmount);
                    try feeDistributor.receiveFees(_pid, usedAmount) {
                        emit LogEvent(usedAmount, "Success Fee Distribution");
                    } catch {
                        emit LogEvent(usedAmount, "Failed Fee Distribution");
                        pool.token.safeTransferFrom(
                            address(msg.sender),
                            feeAddress,
                            usedAmount
                        );
                        pool.token.approve(address(feeDistributor), 0);
                    }
                }
                usedAmount = _amount - usedAmount;
            }
            user.amount = user.amount + usedAmount;
            pool.token.safeTransferFrom(
                address(msg.sender),
                address(this),
                usedAmount
            );
        }
        user.accClaim = (user.amount * pool.accRewardPerShare) / PERCENT;
        emit Deposit(msg.sender, _pid, _amount);
    }

    /// @notice Withdraws pool token from chef. Transfers rewards to user.
    /// @param _amount Amount of pool tokens to withdraw.
    /// @param _pid Pool ID which indicates the type of token
    function withdraw(uint256 _amount, uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(!pool.poolType, "Withdraw: Tp Pool");
        require(user.amount >= _amount, "Withdraw: invalid amount");
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accRewardPerShare) /
            PERCENT -
            user.accClaim;
        if (pending > 0) {
            NICE.mint(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.token.safeTransfer(address(msg.sender), _amount);
        }
        user.accClaim = (user.amount * pool.accRewardPerShare) / PERCENT;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /// @notice Emergency withdraws all the pool tokens from chef. In this case there's no reward.
    /// @param _pid Pool ID which indicates the type of token
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(!pool.poolType, "withdraw: Tp Pool");
        require(user.amount > 0, "Withdraw: invalid amount");
        uint256 _amount = user.amount;
        userInfo[_pid][msg.sender] = UserInfo(0, 0);
        pool.token.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    /// @notice Edits the pool multiplier and updates pools with new params
    /// @param _pidEdit Pool ID
    /// @param _pidMulEdit New multiplier
    function editPoolMult(
        uint256[] calldata _pidEdit,
        uint256[] calldata _pidMulEdit
    ) external onlyOwner {
        updateMultipliers(_pidEdit, _pidMulEdit);
        emit UpdatePools(_pidEdit, _pidMulEdit);
    }

    /// @notice Edits pool fee and updates pools with new params
    /// @param _pid Pool Id
    /// @param _fee New pool fee
    function editPoolFee(uint256 _pid, uint256 _fee) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        require(address(pool.token) != address(0), "edit: invalid");
        require(_fee <= 2500, "edit: high fee");
        pool.fee = _fee;
        emit UpdatePool(_pid, pool.mult, _fee);
    }

    /// @notice Edits the amount of chains to which emissions are split
    /// This factor is used in the emissions calculation
    /// @param _addOrSubstract TRUE = ADD ; FALSE = SUBSTRACT
    function editChains(bool _addOrSubstract) external onlyOwner {
        massUpdatePools();
        chains = _addOrSubstract ? chains + 1 : chains - 1;
        require(chains > 0, "Cant be zero chains");
        emit ChainUpdate(chains);
    }

    /// @notice Edit the address used to Receive Fees
    /// @param _feeReceiver the Address to use
    /// @param _isContract if the address is a FeeDistributor Contract
    /// @dev remove of contract is achievable by adding the Address 0 to it and setting _isContract to True
    function editFeeAddress(address _feeReceiver, bool _isContract)
        external
        onlyOwner
    {
        if (_isContract) feeDistributor = IFeeDistributor(_feeReceiver);
        else {
            require(_feeReceiver != address(0), "set receiver");
            feeAddress = _feeReceiver;
        }
        emit FeeAddressEdit(_feeReceiver, _isContract);
    }
}
