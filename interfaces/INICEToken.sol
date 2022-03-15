// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INICEToken {
    //BEP 20 Functions

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev See {BEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev See {BEP20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {BEP20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    /// @notice burns from msg.sender's wallet, adds to totalBurned
    /// @param amount is the amount to mint
    function burn(uint256 amount) external;

    /**
     * @dev Bridge and minter Functions
     */

    /// @notice Sets Bridge when it's ready. This is the bridge that will be able to use onlyBridge functions.
    /// @param bridgeAddress is the address of the bridge on this chain
    function setBridge(address bridgeAddress) external;

    /// @notice mint function
    /// @param account is the target address
    /// @param amount is the amount to mint
    function mint(address account, uint256 amount) external returns (bool);

    /// @notice Allows bridge to burn from its own wallet. User must be msg.sender.
    /// @param account is the address of the bridge on this chain
    /// @param amount is the amount to burn from sender wallet
    function bridgeBurn(address account, uint256 amount)
        external
        returns (bool);

    /// @notice Allows bridge to burn from a user's wallet with previous approval
    /// @param account is the address of the user that wants to transfer tokens
    /// @param amount is the amount to burn from the user wallet. Must be <= than the amount approved by user.
    function bridgeBurnFrom(address account, uint256 amount)
        external
        returns (bool);

    /// @notice Allows owner to assign minter privileges to other addresses
    /// @param newMinter is the address of desired minter
    function toggleMinter(address newMinter) external;

    // EVENTS

    /// BEP20 events
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// Editing minters map
    event MintersEdit(address minterAddress, bool status);

    /// Setting bridge for the contract
    event SetBridge(address bridgeAddress);
}
