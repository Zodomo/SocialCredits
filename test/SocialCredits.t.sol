// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {SocialCredits} from "../src/SocialCredits.sol";

contract SocialCreditsTest is Test {
    SocialCredits public token;
    address public bobby = makeAddr("BOBBY");

    function setUp() public {
        token = new SocialCredits("Zodomo's Social Credits", "ZSC", 1_000_000_000 ether, address(this));
    }

    function testGeneral() public {
        token.mint(address(this), 1_000 ether);
        require(token.maxSupply() == 1_000_000_000 ether, "maxSupply error");
        require(token.totalSupply() == 1_000 ether, "totalSupply error");
        require(token.balanceOf(address(this)) == 1_000 ether, "balanceOf error");
        require(token.totalAllocated() == 0, "totalAllocated error");
        token.allocate(bobby, 5_000 ether);
        require(token.totalAllocated() == 5_000 ether, "totalAllocated error");
        vm.prank(bobby);
        token.mint(bobby, 5_000 ether);
        require(token.maxSupply() == 1_000_000_000 ether, "maxSupply error");
        require(token.totalSupply() == 6_000 ether, "totalSupply error");
        require(token.balanceOf(bobby) == 5_000 ether, "balanceOf error");
        require(token.totalAllocated() == 0, "totalAllocated error");
        token.transfer(bobby, 100 ether);
        require(token.balanceOf(address(this)) == 900 ether, "balanceOf error");
        require(token.balanceOf(bobby) == 5_100 ether, "balanceOf error");
        vm.prank(bobby);
        vm.expectRevert(SocialCredits.Locked.selector);
        token.transfer(address(1), 100 ether);
        token.toggleLock();
        vm.prank(bobby);
        token.transfer(address(1), 100 ether);
        require(token.balanceOf(address(1)) == 100 ether, "balanceOf error");
        require(token.balanceOf(bobby) == 5_000 ether, "balanceOf error");
        vm.prank(address(1));
        token.approve(address(this), 100 ether);
        token.burn(address(1), 100 ether);
        require(token.balanceOf(address(1)) == 0, "balanceOf error");
        require(token.totalSupply() == 5_900 ether, "totalSupply error");
        require(token.maxSupply() == 999_999_900 ether, "maxSupply error");
    }
}
