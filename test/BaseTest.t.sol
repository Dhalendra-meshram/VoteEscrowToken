// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VeToken.sol";
import "./mocks/MockERC20.sol";  // Correct path to MockERC20.sol

abstract contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                                CONTRACTS
    //////////////////////////////////////////////////////////////*/

    VeToken internal veToken;
    MockERC20 internal token;

    /*//////////////////////////////////////////////////////////////
                                USERS
    //////////////////////////////////////////////////////////////*/

    address internal alice;
    address internal bob;
    address internal attacker;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant INITIAL_BALANCE = 1_000 ether;
    uint256 internal constant MAX_LOCK_TIME = 4 * 365 days;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create test users
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        // Deploy mock ERC20 token
        token = new MockERC20("Test Token", "TEST", 18);

        // Mint tokens to users
        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);

        // Deploy veToken contract with only the token address
        veToken = new VeToken(address(token));  // Only pass the token address

        // Label addresses for readable traces
        vm.label(address(token), "ERC20_TOKEN");
        vm.label(address(veToken), "VE_TOKEN");
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(attacker, "ATTACKER");
    }
}
