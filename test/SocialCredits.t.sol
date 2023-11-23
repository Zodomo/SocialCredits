// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import "../src/SocialCredits.sol";
import {IUniswapV2Factory} from "../lib/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract SocialCreditsTest is Test {
    uint256 internal constant _ROLE_0 = 1 << 0;
    uint256 internal constant _ROLE_1 = 1 << 1;
    uint256 internal constant _ROLE_2 = 1 << 2;
    uint256 internal constant _ROLE_3 = 1 << 3;
    uint256 internal constant _ROLE_4 = 1 << 4;
    uint256 internal constant _ROLE_5 = 1 << 5;
    uint256 internal constant _ROLE_6 = 1 << 6;

    SocialCredits public token;
    address public constant factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public weth = IUniswapV2Router02(router).WETH();
    address public miya = makeAddr("Miya");

    receive() external payable {}

    function setUp() public {
        token = new SocialCredits("Zodomo's Social Credits", "ZSC", 1_000_000_000 ether, address(this));
        vm.deal(address(this), 250 ether);
    }

    function testGeneral() public {
        token.mint(address(this), 1_000 ether);
        require(token.maxSupply() == 1_000_000_000 ether, "maxSupply error");
        require(token.totalSupply() == 1_000 ether, "totalSupply error");
        require(token.balanceOf(address(this)) == 1_000 ether, "balanceOf error");
        require(token.totalAllocated() == 0, "totalAllocated error");
        token.allocate(miya, 5_000 ether);
        require(token.totalAllocated() == 5_000 ether, "totalAllocated error");
        vm.prank(miya);
        token.mint(miya, 5_000 ether);
        require(token.maxSupply() == 1_000_000_000 ether, "maxSupply error");
        require(token.totalSupply() == 6_000 ether, "totalSupply error");
        require(token.balanceOf(miya) == 5_000 ether, "balanceOf error");
        require(token.totalAllocated() == 0, "totalAllocated error");
        token.transfer(miya, 100 ether);
        require(token.balanceOf(address(this)) == 900 ether, "balanceOf error");
        require(token.balanceOf(miya) == 5_100 ether, "balanceOf error");
        vm.prank(miya);
        vm.expectRevert(SocialCredits.Locked.selector);
        token.transfer(address(1), 100 ether);
        token.toggleLock();
        vm.prank(miya);
        token.transfer(address(1), 100 ether);
        require(token.balanceOf(address(1)) == 100 ether, "balanceOf error");
        require(token.balanceOf(miya) == 5_000 ether, "balanceOf error");
        vm.prank(address(1));
        token.approve(address(this), 100 ether);
        token.burn(address(1), 100 ether);
        require(token.balanceOf(address(1)) == 0, "balanceOf error");
        require(token.totalSupply() == 5_900 ether, "totalSupply error");
        require(token.maxSupply() == 999_999_900 ether, "maxSupply error");
    }

    function createPair() public returns (address pair) {
        pair = IUniswapV2Factory(factory).createPair(address(token), weth);
    }

    function mintTokens(uint256 _amount) public {
        token.mint(address(this), _amount);
    }

    function addLiquidity(uint256 _amountToken, uint256 _amountETH) public returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        token.approve(router, _amountToken);
        (amountToken, amountETH, liquidity) = IUniswapV2Router02(router).addLiquidityETH{ value: _amountETH }(
            address(token),
            _amountToken,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function removeLiquidity(uint256 _liquidity) public returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = IUniswapV2Router02(router).removeLiquidityETH(
            address(token),
            _liquidity,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function testAddLiquidity(uint256 _amountToken, uint256 _amountETH) public {
        vm.assume(_amountToken >= 1 ether);
        vm.assume(_amountToken <= 1_000_000_000 ether);
        vm.assume(_amountETH >= 0.0001 ether);
        vm.assume(_amountETH <= 100 ether);
        createPair();
        mintTokens(_amountToken);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = addLiquidity(_amountToken, _amountETH);
        require(amountToken == _amountToken, "token add error");
        require(amountETH == _amountETH, "ETH add error");
        require(liquidity > 0, "no LP tokens received");
    }

    function testRemoveLiquidity(uint256 _amountToken, uint256 _amountETH) public {
        vm.assume(_amountToken >= 0.0001 ether);
        vm.assume(_amountToken <= 100 ether);
        vm.assume(_amountETH >= 0.0001 ether);
        vm.assume(_amountETH <= 100 ether);
        address pair = createPair();
        token.setLockExemptSender(router, true);
        token.setLockExemptSender(pair, true);
        mintTokens(_amountToken);
        (,, uint256 liquidity) = addLiquidity(_amountToken, _amountETH);
        IERC20(pair).approve(router, liquidity);
        (uint256 amountToken, uint256 amountETH) = removeLiquidity(liquidity);
        require(amountToken > 0, "token remove error");
        require(amountETH > 0, "ETH remove error");
    }

    function testBuy(uint256 _amount) public {
        vm.assume(_amount >= 0.0001 ether);
        vm.assume(_amount <= 100 ether);
        vm.deal(miya, 100 ether);
        address pair = createPair();
        token.setLockExemptSender(router, true);
        token.setLockExemptSender(pair, true);
        mintTokens(100_000_000 ether);
        addLiquidity(100_000_000 ether, 100 ether);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);
        vm.prank(miya);
        IUniswapV2Router02(router).swapExactETHForTokens{ value: _amount }(
            1,
            path,
            miya,
            block.timestamp
        );
        require(token.balanceOf(miya) > 0, "buy transfer error");
    }

    function testSell(uint256 _amount) public {
        vm.assume(_amount >= 0.0001 ether);
        vm.assume(_amount <= 100 ether);
        vm.deal(miya, 100 ether);
        address pair = createPair();
        token.setLockExemptSender(router, true);
        token.setLockExemptSender(pair, true);
        mintTokens(100_000_000 ether);
        addLiquidity(100_000_000 ether, 100 ether);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);
        vm.startPrank(miya);
        IUniswapV2Router02(router).swapExactETHForTokens{ value: _amount }(
            1,
            path,
            miya,
            block.timestamp
        );
        uint256 ethBalance = address(miya).balance;
        uint256 tokenBalance = token.balanceOf(miya);
        token.approve(router, tokenBalance);
        vm.stopPrank();
        token.toggleLock();
        path[0] = address(token);
        path[1] = weth;
        vm.prank(miya);
        IUniswapV2Router02(router).swapExactTokensForETH(
            tokenBalance,
            1,
            path,
            miya,
            block.timestamp
        );
        require(token.balanceOf(miya) == 0, "sell balance error");
        require(address(miya).balance > ethBalance, "sell transfer error");
    }

    function testSellRevert(uint256 _amount) public {
        vm.assume(_amount >= 0.0001 ether);
        vm.assume(_amount <= 100 ether);
        vm.deal(miya, 100 ether);
        address pair = createPair();
        token.setLockExemptSender(router, true);
        token.setLockExemptSender(pair, true);
        mintTokens(100_000_000 ether);
        addLiquidity(100_000_000 ether, 100 ether);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);
        vm.startPrank(miya);
        IUniswapV2Router02(router).swapExactETHForTokens{ value: _amount }(
            1,
            path,
            miya,
            block.timestamp
        );
        uint256 tokenBalance = token.balanceOf(miya);
        token.approve(router, tokenBalance);
        path[0] = address(token);
        path[1] = weth;
        vm.expectRevert(bytes("TransferHelper: TRANSFER_FROM_FAILED"));
        IUniswapV2Router02(router).swapExactTokensForETH(
            tokenBalance,
            1,
            path,
            miya,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testTransferRevert(address _recipient, uint256 _amount) public {
        vm.assume(_recipient != miya);
        vm.assume(_recipient != address(0));
        vm.assume(_recipient != address(this));
        vm.assume(_recipient != address(token));
        vm.assume(_recipient != address(router));
        vm.assume(_recipient != address(factory));
        vm.assume(_amount >= 1 ether);
        vm.assume(_amount <= 100_000_000 ether);
        token.mint(miya, _amount);
        vm.prank(_recipient);
        vm.expectRevert(SocialCredits.Locked.selector);
        token.transfer(_recipient, _amount);
    }

    function testRolesAll(address _addr, uint256 _amount) public {
        vm.assume(_addr != miya);
        vm.assume(_addr != address(0));
        vm.assume(_addr != address(this));
        vm.assume(_addr != address(token));
        vm.assume(_addr != address(router));
        vm.assume(_addr != address(factory));
        vm.assume(_amount >= 1 ether);
        vm.assume(_amount <= 100_000_000 ether);
        token.grantRoles(_addr, _ROLE_0);
        token.grantRoles(_addr, _ROLE_1);
        token.grantRoles(_addr, _ROLE_2);
        token.grantRoles(_addr, _ROLE_3);
        token.grantRoles(_addr, _ROLE_4);
        vm.startPrank(_addr);
        token.mint(_addr, _amount);
        token.allocate(miya, _amount);
        token.toggleLock();
        token.reduceMaxSupply(_amount);
        token.setLockExemptSender(miya, true);
        token.setLockExemptRecipient(miya, true);
        vm.stopPrank();
        require(token.balanceOf(_addr) == _amount, "mint amount error");
        require(token.getAllocation(miya) == _amount, "allocation amount error");
        require(token.totalAllocated() == _amount, "totalAllocation amount error");
        require(token.unlocked(), "unlocked status error");
        require(token.maxSupply() == 1_000_000_000 ether - _amount, "maxSupply amount error");
        require(token.hasAllRoles(miya, _ROLE_5), "lock exempt sender status error");
        require(token.hasAllRoles(miya, _ROLE_6), "lock exempt recipient status error");
        token.renounceOwnership();
        vm.prank(_addr);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.toggleLock();
    }
}
