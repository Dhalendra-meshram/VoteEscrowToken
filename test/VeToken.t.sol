// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseTest.t.sol";

contract VeTokenTest is BaseTest {

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_initial_state() public {
    assertEq(ve.TOKEN(), address(token));
    assertEq(ve.epoch(), 0);
}


    /*//////////////////////////////////////////////////////////////
                        CREATE LOCK
    //////////////////////////////////////////////////////////////*/

    function test_create_lock_sets_voting_power() public {
        uint256 amount = 100 ether;
        uint256 unlockTime = block.timestamp + 8 weeks;

        vm.startPrank(alice);
        token.approve(address(ve), amount);
        ve.createLock(amount, unlockTime);
        vm.stopPrank();

        IVeToken.LockedBalance memory lock = ve.locked(alice);

        assertEq(uint256(int256(lock.amount)), amount);
        assertGt(ve.balanceOf(alice), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    VOTING POWER DECAY
    //////////////////////////////////////////////////////////////*/

    function test_voting_power_decays_over_time() public {
        uint256 amount = 100 ether;
        uint256 unlockTime = block.timestamp + 12 weeks;

        vm.startPrank(alice);
        token.approve(address(ve), amount);
        ve.createLock(amount, unlockTime);

        uint256 powerStart = ve.balanceOf(alice);

        vm.warp(block.timestamp + 6 weeks);
        uint256 powerMid = ve.balanceOf(alice);

        assertLt(powerMid, powerStart);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                EXTENDING LOCK INCREASES POWER
    //////////////////////////////////////////////////////////////*/

    function test_extend_lock_increases_voting_power() public {
        uint256 amount = 100 ether;

        vm.startPrank(alice);
        token.approve(address(ve), amount);
        ve.createLock(amount, block.timestamp + 4 weeks);

        uint256 powerBefore = ve.balanceOf(alice);

        ve.increaseUnlockTime(block.timestamp + 16 weeks);
        uint256 powerAfter = ve.balanceOf(alice);

        assertGt(powerAfter, powerBefore);
        vm.stopPrank();
    }

    
   function test_balanceOf_matches_manual_calculation() public {
    uint256 amount = 100 ether;
    uint256 unlockTime = block.timestamp + 8 weeks;

    vm.startPrank(alice);
    token.approve(address(ve), amount);
    ve.createLock(amount, unlockTime);

    // Mirror contract rounding
    uint256 roundedUnlock =
        (unlockTime / 1 weeks) * 1 weeks;

    uint256 expected =
        (amount * (roundedUnlock - block.timestamp)) /
        (4 * 365 days);

    uint256 actual = ve.balanceOf(alice);

    // Allow 1 slope unit of error (rounding + timestamp drift)
    uint256 slope = amount / (4 * 365 days);

    assertApproxEqAbs(actual, expected, slope);
    vm.stopPrank();
}




    /*//////////////////////////////////////////////////////////////
                HISTORICAL BLOCK QUERY (ADVANCED)
    //////////////////////////////////////////////////////////////*/

    function test_balance_of_at_block() public {
        uint256 amount = 100 ether;

        vm.startPrank(alice);
        token.approve(address(ve), amount);
        ve.createLock(amount, block.timestamp + 8 weeks);

        uint256 snapshotBlock = block.number;

        vm.roll(block.number + 20);
        vm.stopPrank();

        uint256 pastBalance = ve.balanceOfAtBlock(alice, snapshotBlock);
        assertGt(pastBalance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function test_withdraw_after_expiry() public {
        uint256 amount = 100 ether;
        uint256 unlockTime = block.timestamp + 2 weeks;

        vm.startPrank(alice);
        token.approve(address(ve), amount);
        ve.createLock(amount, unlockTime);

        vm.warp(unlockTime + 1);
        ve.withdraw();
        vm.stopPrank();

        assertEq(token.balanceOf(alice), INITIAL_BALANCE);
        assertEq(ve.balanceOf(alice), 0);
    }

 /*//////////////////////////////////////////////////////////////
                        FUZZTEST
    //////////////////////////////////////////////////////////////*/

    function testFuzz_createLock_producesVotingPower(
    uint256 amount,
    uint256 lockWeeks
) public {
    // Bound fuzzed values
    amount = bound(amount, 1 ether, 500 ether);
    lockWeeks = bound(lockWeeks, 1, 208); // up to 4 years

    uint256 unlockTime = block.timestamp + lockWeeks * 1 weeks;

    vm.startPrank(alice);
    token.approve(address(ve), amount);
    ve.createLock(amount, unlockTime);

    uint256 power = ve.balanceOf(alice);

    assertGt(power, 0);
    assertLe(power, amount); // voting power <= locked amount
    vm.stopPrank();
}
}