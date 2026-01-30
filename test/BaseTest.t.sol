// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VeToken.sol";
import "./Mocks/MockERC20.sol";


abstract contract BaseTest is Test {
    VeToken internal ve;
    MockERC20 internal token;

    address internal alice;
    address internal bob;

    uint256 internal constant INITIAL_BALANCE = 1_000 ether;
    uint256 internal constant WEEK = 1 weeks;

    function setUp() public virtual {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new MockERC20("Test Token", "TEST", 18);

        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);

        ve = new VeToken(address(token));

        vm.label(address(token), "ERC20");
        vm.label(address(ve), "VeToken");
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
    }
}
