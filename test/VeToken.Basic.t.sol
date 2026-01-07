// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseTest.t.sol"; // Import the base test contract
import "forge-std/Test.sol"; // Import Foundry's test utilities

contract VeTokenBasicTest is BaseTest {

    // Test the initial state of the VeToken contract
    function test_deploy_initial_state() public {
        // Check if the veToken contract is deployed correctly
        assertEq(address(veToken), address(token));  // Check if token address is correctly passed
        //assertEq(veToken.maxLockTime(), MAX_LOCK_TIME);  // Check if the max lock time is set correctly
    }

    // Test creating a lock successfully
    function test_create_lock_success() public {
        uint256 lockAmount = 100 ether;  // Amount to lock
        uint256 lockDuration = 30 days;  // Lock duration

        // Alice creates a lock
        vm.prank(alice);  // Simulate as Alice
        veToken.createLock(lockAmount, lockDuration);

        // Check if the lock amount and duration are correct
        assertEq(veToken.lockedBalance(alice), lockAmount);
        assertEq(veToken.lockedUntil(alice), block.timestamp + lockDuration);
    }

    // Test extending the lock duration successfully
    function test_extend_lock_duration() public {
        uint256 lockAmount = 100 ether;  // Lock amount
        uint256 initialLockDuration = 30 days;  // Initial lock duration
        uint256 extensionDuration = 15 days;  // Duration to extend by

        // Alice creates a lock
        vm.prank(alice);  // Simulate as Alice
        veToken.createLock(lockAmount, initialLockDuration);

        // Extend the lock duration
        vm.prank(alice);  // Simulate as Alice
        veToken.extendLockDuration(extensionDuration);

        // Check if the lock duration is updated
        uint256 newLockUntil = veToken.lockedUntil(alice);
        assertEq(newLockUntil, block.timestamp + initialLockDuration + extensionDuration);
    }

    // Test extending the lock amount successfully
    function test_extend_lock_amount() public {
        uint256 lockAmount = 100 ether;  // Lock amount
        uint256 lockDuration = 30 days;  // Lock duration

        // Alice creates a lock
        vm.prank(alice);  // Simulate as Alice
        veToken.createLock(lockAmount, lockDuration);

        // Extend the lock amount
        uint256 additionalAmount = 50 ether;
        vm.prank(alice);  // Simulate as Alice
        veToken.extendLockAmount(additionalAmount);

        // Check if the locked amount is updated correctly
        assertEq(veToken.lockedBalance(alice), lockAmount + additionalAmount);
    }

    // Test withdrawing after the lock expires
    function test_withdraw_after_expiry() public {
        uint256 lockAmount = 100 ether;  // Lock amount
        uint256 lockDuration = 1 hours;  // Lock duration (1 hour for testing purposes)

        // Alice creates a lock
        vm.prank(alice);  // Simulate as Alice
        veToken.createLock(lockAmount, lockDuration);

        // Fast forward time to make the lock expire
        vm.warp(block.timestamp + lockDuration + 1);  // Set the time to after lock expiry

        // Alice withdraws the locked tokens after the expiry
        uint256 initialBalance = token.balanceOf(alice);
        vm.prank(alice);  // Simulate as Alice
        veToken.withdraw();

        // Check if Alice's balance has increased by the locked amount
        uint256 finalBalance = token.balanceOf(alice);
        assertEq(finalBalance, initialBalance + lockAmount);  // Alice should receive the locked amount
    }
}