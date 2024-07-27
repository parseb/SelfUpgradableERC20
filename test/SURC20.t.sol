// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SUERC20.sol";

contract SUERC20Test is Test {
    SUERC20 public token;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        token = new SUERC20("Test Token", "TEST", 1000000e18);
    }

    function testInitialState() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), 1000000e18);
        assertEq(token.balanceOf(owner), 1000000e18);
        assertEq(token.currentImplementation(), address(token));
        assertEq(token.totalSupportForImplementation(address(token)), 1000000e18);
        assertEq(token.supportedImplementation(owner), address(token));
    }

    function testSupportImplementation() public {
        address newImpl = address(new MockImplementation());
        vm.startPrank(owner);
        token.transfer(user1, 600000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(newImpl);
        assertEq(token.supportedImplementation(user1), newImpl);
        assertEq(token.totalSupportForImplementation(newImpl), 600000e18);
        assertEq(token.currentImplementation(), newImpl);
        vm.stopPrank();
    }

    function testWithdrawSupport() public {
        address newImpl = address(new MockImplementation());
        vm.startPrank(owner);
        token.transfer(user1, 400000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(newImpl);
        assertEq(token.supportedImplementation(user1), newImpl);
        assertEq(token.totalSupportForImplementation(newImpl), 400000e18);

        token.withdrawSupport();
        assertEq(token.supportedImplementation(user1), address(0));
        assertEq(token.totalSupportForImplementation(newImpl), 0);
        vm.stopPrank();
    }

    function testSupportAdjustmentOnTransfer() public {
        address newImpl = address(new MockImplementation());
        vm.startPrank(owner);
        token.transfer(user1, 600000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(newImpl);
        assertEq(token.totalSupportForImplementation(newImpl), 600000e18);

        token.transfer(user2, 300000e18);
        assertEq(token.totalSupportForImplementation(newImpl), 300000e18);
        vm.stopPrank();
    }

    function testMajorityNotReached() public {
        address newImpl = address(new MockImplementation());
        vm.startPrank(owner);
        token.transfer(user1, 400000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(newImpl);
        assertEq(token.supportedImplementation(user1), newImpl);
        assertEq(token.totalSupportForImplementation(newImpl), 400000e18);
        assertEq(token.currentImplementation(), address(token)); // Implementation should not change
        vm.stopPrank();
    }

    function testChangingSupportMultipleTimes() public {
        address newImpl1 = address(new MockImplementation());
        address newImpl2 = address(new MockImplementation());
        vm.startPrank(owner);
        token.transfer(user1, 600000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(newImpl1);
        assertEq(token.supportedImplementation(user1), newImpl1);
        assertEq(token.totalSupportForImplementation(newImpl1), 600000e18);
        assertEq(token.currentImplementation(), newImpl1);

        token.supportImplementation(newImpl2);
        assertEq(token.supportedImplementation(user1), newImpl2);
        assertEq(token.totalSupportForImplementation(newImpl1), 0);
        assertEq(token.totalSupportForImplementation(newImpl2), 600000e18);
        assertEq(token.currentImplementation(), newImpl2);
        vm.stopPrank();
    }

    function testFallbackFunctionality() public {
        MockImplementation mockImpl = new MockImplementation();
        
        vm.startPrank(owner);
        token.transfer(user1, 600000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(address(mockImpl));
        vm.stopPrank();

        // Now the mockImpl is the current implementation
        assertEq(token.currentImplementation(), address(mockImpl));

        // Call a function that doesn't exist in SUERC20
        // It should be forwarded to the mock implementation
        (bool success, bytes memory result) = address(token).call(abi.encodeWithSignature("mockFunction()"));
        
        assertTrue(success);
        assertEq(abi.decode(result, (string)), "Mock function called");
    }

    function testSupportZeroAddress() public {
        vm.expectRevert("Invalid implementation");
        token.supportImplementation(address(0));
    }

    function testSupportNonContractAddress() public {
        vm.expectRevert("Invalid implementation");
        token.supportImplementation(address(0x1234));
    }

    function testWithdrawSupportWithoutSupporting() public {
        vm.startPrank(user1);
        vm.expectRevert("No supported implementation");
        token.withdrawSupport();
        vm.stopPrank();
    }

function testSupportDistribution() public {
    address newImpl = address(new MockImplementation());
    vm.startPrank(owner);
    token.transfer(user1, token.balanceOf(owner) / 2 + 1);
    // token.transfer(user2, 110000e18);
    // token.transfer(user3, 100000e18);
    vm.stopPrank();

    vm.prank(user1);
    token.supportImplementation(newImpl);
    assertEq(token.currentImplementation(), address(newImpl)); // Still original as no majority


}

    function testTransferAllTokens() public {
        address newImpl = address(new MockImplementation());
        vm.startPrank(owner);
        token.transfer(user1, 600000e18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.supportImplementation(newImpl);
        assertEq(token.totalSupportForImplementation(newImpl), 600000e18);

        token.transfer(user2, 600000e18);
        assertEq(token.totalSupportForImplementation(newImpl), 0);
        vm.stopPrank();
    }

    function testMultipleImplementationProposals() public {
        address newImpl1 = address(new MockImplementation());
        address newImpl2 = address(new MockImplementation());
        address newImpl3 = address(new MockImplementation());

        vm.startPrank(owner);
        token.transfer(user1, 300000e18);
        token.transfer(user2, 300000e18);
        token.transfer(user3, 300000e18);
        vm.stopPrank();

        vm.prank(user1);
        token.supportImplementation(newImpl1);

        vm.prank(user2);
        token.supportImplementation(newImpl2);

        vm.prank(user3);
        token.supportImplementation(newImpl3);

        assertEq(token.totalSupportForImplementation(newImpl1), 300000e18);
        assertEq(token.totalSupportForImplementation(newImpl2), 300000e18);
        assertEq(token.totalSupportForImplementation(newImpl3), 300000e18);
        assertEq(token.currentImplementation(), address(token)); // Should still be the original implementation
    }

function testImplementationChangeAfterWithdrawal() public {
    address newImpl1 = address(new MockImplementation());
    address newImpl2 = address(new MockImplementation());

    vm.startPrank(owner);
    token.transfer(user1, 600000e18);
    token.transfer(user2, 300000e18);
    vm.stopPrank();

    vm.prank(user1);
    token.supportImplementation(newImpl1);
    assertEq(token.currentImplementation(), newImpl1);

    vm.prank(user2);
    token.supportImplementation(newImpl2);
    assertEq(token.currentImplementation(), newImpl1); // Still newImpl1 as it has majority

    vm.prank(user1);
    token.withdrawSupport();

    // After withdrawal, newImpl2 should have the highest support, but not majority
    // So the implementation should remain newImpl1
    assertEq(token.currentImplementation(), newImpl1);

    // User1 now supports newImpl2
    vm.prank(user1);
    token.supportImplementation(newImpl2);
    
    // Now newImpl2 should become the current implementation
    assertEq(token.currentImplementation(), newImpl2);
}


}

contract MockImplementation {
    function mockFunction() external pure returns (string memory) {
        return "Mock function called";
    }
}