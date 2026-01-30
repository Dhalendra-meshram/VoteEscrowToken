// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVeToken} from "./interfaces/IVeToken.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract VeToken is IVeToken {
    using SafeTransferLib for ERC20;

    // -----------------------------
    // CONSTANTS
    // -----------------------------
    uint256 constant WEEK = 1 weeks;
    uint256 constant MAXTIME = 4 * 365 days;
    uint256 constant POINT_SLOT = 10;
    uint256 constant SLOPE_CHANGES_SLOT = 11;

    // -----------------------------
    // STORAGE
    // -----------------------------
    mapping(address => LockedBalance) internal lockedBalances;
    mapping(uint256 => Point) public pointHistory;   // global checkpoints
    mapping(uint256 => int128) public slopeChanges;  // slope changes at timestamps
    uint256 public override epoch;
    address public immutable TOKEN;

    // -----------------------------
    // CONSTRUCTOR
    // -----------------------------
    constructor(address token_) {
        TOKEN = token_;
    }

    // -----------------------------
    // USER ACTIONS
    // -----------------------------
    function createLock(uint256 value, uint256 unlockTime) external override {
        require(value > 0, "Value must be > 0");

        // intended weekly floor rounding
        // forge-lint: disable-next-line(divide-before-multiply)
        uint256 unlockWeek = (unlockTime / WEEK) * WEEK;

        require(unlockWeek > block.timestamp, "Must lock in future");
        require(unlockWeek <= block.timestamp + MAXTIME, "Max 4 years");

        ERC20(TOKEN).safeTransferFrom(msg.sender, address(this), value);

        LockedBalance memory newLock = lockedBalances[msg.sender];

        // safe: amount added is always < total ERC20 supply
        // forge-lint: disable-next-line(unsafe-typecast)
        newLock.amount += int128(int256(value));

        newLock.end = unlockWeek;
        lockedBalances[msg.sender] = newLock;

        _checkpoint(msg.sender, LockedBalance({amount:0, end:0}), newLock);
        emit Deposit(msg.sender, value, unlockWeek, 1, block.timestamp);
    }

    function increaseAmount(uint256 value) external override {
        require(value > 0, "Value must be > 0");

        LockedBalance memory oldLocked = lockedBalances[msg.sender];
        require(oldLocked.amount > 0, "No existing lock");
        require(oldLocked.end > block.timestamp, "Lock expired");

        LockedBalance memory newLocked = oldLocked;

        // forge-lint: disable-next-line(unsafe-typecast)
        newLocked.amount += int128(int256(value));

        lockedBalances[msg.sender] = newLocked;

        ERC20(TOKEN).safeTransferFrom(msg.sender, address(this), value);

        _checkpoint(msg.sender, oldLocked, newLocked);
        emit Deposit(msg.sender, value, newLocked.end, 2, block.timestamp);
    }

    function increaseUnlockTime(uint256 unlockTime) external override {
        LockedBalance memory oldLocked = lockedBalances[msg.sender];
        require(oldLocked.amount > 0, "No existing lock");
        require(oldLocked.end > block.timestamp, "Lock expired");

        // intended weekly rounding
        // forge-lint: disable-next-line(divide-before-multiply)
        uint256 unlockWeek = (unlockTime / WEEK) * WEEK;

        require(unlockWeek > oldLocked.end, "Can only extend lock");
        require(unlockWeek <= block.timestamp + MAXTIME, "Max 4 years");

        LockedBalance memory newLocked = oldLocked;
        newLocked.end = unlockWeek;

        lockedBalances[msg.sender] = newLocked;
        _checkpoint(msg.sender, oldLocked, newLocked);

        emit Deposit(msg.sender, 0, unlockWeek, 3, block.timestamp);
    }

    function withdraw() external override {
        LockedBalance memory oldLocked = lockedBalances[msg.sender];
        require(oldLocked.amount > 0, "No lock found");
        require(block.timestamp >= oldLocked.end, "Lock not expired");

        lockedBalances[msg.sender] = LockedBalance({amount:0, end:0});
        _checkpoint(msg.sender, oldLocked, LockedBalance({amount:0, end:0}));

        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 value = uint256(int256(oldLocked.amount));

        ERC20(TOKEN).safeTransfer(msg.sender, value);
        emit Withdraw(msg.sender, value, block.timestamp);
    }

    // -----------------------------
    // VIEW FUNCTIONS
    // -----------------------------
    function locked(address user) external view override returns (LockedBalance memory) {
        return lockedBalances[user];
    }

    function balanceOf(address user) external view override returns (uint256) {
        LockedBalance memory lock_ = lockedBalances[user];
        if (block.timestamp >= lock_.end) return 0;

        return
            // safe: lock_.amount always positive & < int128 max
            (uint256(int256(lock_.amount)) * (lock_.end - block.timestamp)) /
            MAXTIME;
    }

    function balanceOfAt(address user, uint256 timestamp)
        external
        view
        override
        returns (uint256)
    {
        LockedBalance memory lock_ = lockedBalances[user];
        if (timestamp >= lock_.end || lock_.amount == 0) return 0;

        return
            (uint256(int256(lock_.amount)) * (lock_.end - timestamp)) /
            MAXTIME;
    }

    function totalSupply() external view override returns (uint256) {
        Point memory lastPoint = pointHistory[epoch];

        // forge-lint: disable-next-line(unsafe-typecast)
        int128 bias =
            lastPoint.bias -
            lastPoint.slope *
            int128(
                int256(block.timestamp - lastPoint.ts)
            );

        if (bias < 0) bias = 0;

        // rename warns t_i → tI
        // forge-lint: disable-next-line(divide-before-multiply)
        uint256 tI = (lastPoint.ts / WEEK) * WEEK;

        while (tI < block.timestamp) {
            tI += WEEK;

            int128 dSlope = slopeChanges[tI];

            // safe because MAXTIME < int128 max
            // forge-lint: disable-next-line(unsafe-typecast)
            // Casting to int256 is safe because (block.timestamp - tI) is always < MAXTIME (4 years)
// forge-lint: disable-next-line(unsafe-typecast)
int256 elapsed = int256(block.timestamp - tI);

// Casting to int128 is safe because elapsed < 4 years < int128 max range
// forge-lint: disable-next-line(unsafe-typecast)
int128 elapsed128 = int128(elapsed);

bias -= dSlope * elapsed128;


            if (bias < 0) bias = 0;
        }

        // bias is clamped to ≥ 0 above
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint256(int256(bias));
    }

    function getLastUserSlope(address user) external view override returns (int128) {
        LockedBalance memory lock_ = lockedBalances[user];
        if (lock_.amount == 0 || block.timestamp >= lock_.end) return 0;

        // forge-lint: disable-next-line(unsafe-typecast)
        return lock_.amount / int128(int256(MAXTIME));
    }

    function getPointHistory(uint256 index) external view override returns (Point memory) {
        return pointHistory[index];
    }

    // -----------------------------
    // BLOCK-BASED BALANCE
    // -----------------------------
    function balanceOfAtBlock(address user, uint256 blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber <= block.number, "Block in future");

        LockedBalance memory lock_ = lockedBalances[user];
        if (lock_.amount == 0 || blockNumber >= lock_.end) return 0;

        uint256 _epoch = epoch;
        Point memory lastPoint = pointHistory[_epoch];

        while (_epoch > 0 && pointHistory[_epoch].blk > blockNumber) {
            _epoch--;
            lastPoint = pointHistory[_epoch];
        }

        uint256 dt = 0;

        if (_epoch < epoch) {
            Point memory nextPoint = pointHistory[_epoch + 1];

            uint256 blockDiff = nextPoint.blk - lastPoint.blk;
            uint256 timeDiff = nextPoint.ts - lastPoint.ts;

            dt = (blockNumber - lastPoint.blk) * timeDiff / blockDiff;
        }

        uint256 targetTime = lastPoint.ts + dt;
        if (targetTime >= lock_.end) return 0;

        return
            (uint256(int256(lock_.amount)) * (lock_.end - targetTime)) /
            MAXTIME;
    }

    // -----------------------------
    // INTERNALS
    // -----------------------------
    function _checkpoint(
        address user,
        LockedBalance memory oldLocked,
        LockedBalance memory newLocked
    ) internal {
        Point memory uOld;
        Point memory uNew;

        if (oldLocked.end > block.timestamp && oldLocked.amount > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            uOld.slope = oldLocked.amount / int128(int256(MAXTIME));

            // forge-lint: disable-next-line(unsafe-typecast)
            uOld.bias = uOld.slope * int128(int256(oldLocked.end - block.timestamp));

            _setSlopeChange(oldLocked.end, -uOld.slope);
        }

        if (newLocked.end > block.timestamp && newLocked.amount > 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            uNew.slope = newLocked.amount / int128(int256(MAXTIME));

            // forge-lint: disable-next-line(unsafe-typecast)
            uNew.bias = uNew.slope * int128(int256(newLocked.end - block.timestamp));

            _setSlopeChange(newLocked.end, uNew.slope);
        }

        uNew.ts = block.timestamp;
        uNew.blk = block.number;

        _packAndStore(user, 0, uNew);

        emit UserCheckpoint(user, uNew.bias, uNew.slope, uNew.ts, uNew.blk);

        Point memory lastPoint = pointHistory[epoch];
        lastPoint.slope += (uNew.slope - uOld.slope);
        lastPoint.bias += (uNew.bias - uOld.bias);

        if (lastPoint.slope < 0) lastPoint.slope = 0;
        if (lastPoint.bias < 0) lastPoint.bias = 0;

        epoch++;
        pointHistory[epoch] = lastPoint;

        emit GlobalCheckpoint(epoch, lastPoint.bias, lastPoint.slope, lastPoint.ts, lastPoint.blk);
    }

    function _setSlopeChange(uint256 ts, int128 slopeDelta) internal {
        slopeChanges[ts] += slopeDelta;
        emit SlopeChange(ts, slopeDelta, slopeChanges[ts]);
    }

    function _packAndStore(address user, uint256 idx, Point memory p) internal {
        assembly {
            mstore(0x00, user)
            mstore(0x20, POINT_SLOT)
            let base := keccak256(0x00, 0x40)

            let slot0 := add(base, mul(idx, 2))
            let packed0 :=
                or(
                    and(mload(p), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
                    shl(128, and(mload(add(p,32)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
                )
            sstore(slot0, packed0)

            let packed1 :=
                or(
                    shl(40, mload(add(p,96))),
                    and(mload(add(p,64)), 0xFFFFFFFFFF)
                )
            sstore(add(slot0,1), packed1)
        }
    }
}

