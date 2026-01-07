// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVeToken {
    // ----------------------------------------------------------------
    // DATA STRUCTURES
    // ----------------------------------------------------------------

    /**
     * @notice The 'Point' struct used for math.
     * @dev    In storage, this is packed into 2 slots.
     */
    struct Point {
        int128 bias;    // Voting power at this point
        int128 slope;   // Decay rate
        uint256 ts;     // Timestamp of checkpoint
        uint256 blk;    // Block number
    }

    /**
     * @notice User's Lock Receipt
     */
    struct LockedBalance {
        int128 amount;  // Total tokens locked
        uint256 end;    // Unlock timestamp
    }

    // ----------------------------------------------------------------
    // EVENTS
    // ----------------------------------------------------------------
    
    event Deposit(
        address indexed provider,
        uint256 value,
        uint256 indexed locktime,
        int128 type_,
        uint256 ts
    );

    event Withdraw(
        address indexed provider,
        uint256 value,
        uint256 ts
    );

    event Supply(
        uint256 prevSupply,
        uint256 supply
    );

    event UserCheckpoint(
        address indexed user,
        int128 bias,
        int128 slope,
        uint256 timestamp,
        uint256 blockNumber
    );

    event GlobalCheckpoint(
        uint256 indexed epoch,
        int128 bias,
        int128 slope,
        uint256 timestamp,
        uint256 blockNumber
    );

    event SlopeChange(
        uint256 indexed timestamp,
        int128 slopeDelta,
        int128 newSlope
    );

    // ----------------------------------------------------------------
    // USER ACTIONS
    // ----------------------------------------------------------------

    function createLock(uint256 _value, uint256 unlockTime) external;

    function increaseAmount(uint256 _value) external;

    function increaseUnlockTime(uint256 unlockTime) external;

    function withdraw() external;

    // ----------------------------------------------------------------
    // VIEWS
    // ----------------------------------------------------------------

    /**
     * @notice Get current voting power for a user.
     */
    function balanceOf(address _addr) external view returns (uint256);

    /**
     * @notice Get voting power at a specific block number.
     * @dev    Matches VeToken.balanceOfAtBlock()
     */
    function balanceOfAt(address _addr, uint256 _block)
        external
        view
        returns (uint256);

    /**
     * @notice Get total supply of voting power.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Get the most recent user slope.
     */
    function getLastUserSlope(address _addr) external view returns (int128);

    /**
     * @notice Get user's lock info.
     */
    function locked(address _addr) external view returns (LockedBalance memory);

    /**
     * @notice Get current Epoch.
     */
    function epoch() external view returns (uint256);

    /**
     * @notice Get global history checkpoint.
     */
    function getPointHistory(uint256 index) external view returns (Point memory);
}
