// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "../../lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IUniswapV2Pair } from "../../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import { UniswapVault } from "../vaults/uniswap/UniswapVault.sol";

import { BasicVaultTest } from "./utils/VaultUtils.sol";
import { TestToken } from "./mocks/TestToken.sol";
import { C } from "./utils/Constants.sol";

contract UniswapVaultTest is BasicVaultTest {
    UniswapVault public uniswapVaultImpl;

    /////////////////// DEFINE VIRTUAL FUNCTIONS ///////////////////////////
    function createTokensAndDexPair() internal override {
        token0 = IERC20(address(new TestToken("Test Token 0", "TT0")));
        token1 = IERC20(address(new TestToken("Test Token 1", "TT1")));
        pair = IUniswapV2Pair(factory.createPair(address(token0), address(token1)));

        getToken0(trader, amount);
        getToken1(trader, amount);

        vm.startPrank(trader);

        token0.approve(address(router), amount);
        token1.approve(address(router), amount);
        router.addLiquidity(address(token0), address(token1), amount, amount, 0, 0, trader, block.timestamp);
        vm.stopPrank();
    }

    function deployVault() internal override returns (address vault) {
        uniswapVaultImpl = new UniswapVault();
        vault = address(
            new TransparentUpgradeableProxy(
                address(uniswapVaultImpl),
                address(proxyAdmin),
                abi.encodeWithSignature(
                    "initialize(address,uint256,address,address,uint256,uint256,address,address)",
                    address(core),
                    0,
                    address(token0),
                    address(token1),
                    10_000,
                    500,
                    address(factory),
                    address(router)
                )
            )
        );
    }

    function getToken0(address user, uint256 amount) internal override {
        TestToken(address(token0)).giveTokensTo(user, amount);
    }

    function getToken1(address user, uint256 amount) internal override {
        TestToken(address(token1)).giveTokensTo(user, amount);
    }

    /////////////////// TESTS SPECIFIC TO THIS DEPLOYMENT ///////////////////////
    function test_50PercentIncreaseInPrice() public {
        depositToken0();
        depositToken1();
        advance();

        adjustPoolRatio((C.RAY * 150) / 100);
        advance();

        assertEq(vault.epochToToken0Rate(2), C.RAY);
        assertTrue(vault.epochToToken1Rate(2) > (C.RAY * 94) / 100);
    }

    function test_300PercentIncreaseInPrice() public {
        depositToken0();
        depositToken1();
        advance();

        adjustPoolRatio(C.RAY * 3);
        advance();

        assertEq(vault.epochToToken0Rate(2), C.RAY);
        assertTrue(vault.epochToToken1Rate(2) > (C.RAY * 74) / 100);
    }

    function test_600PercentIncreaseInPrice() public {
        depositToken0();
        depositToken1();
        advance();

        adjustPoolRatio(C.RAY * 6);
        advance();

        assertEq(vault.epochToToken0Rate(2), C.RAY);
        assertTrue(vault.epochToToken1Rate(2) > (C.RAY * 56) / 100);
    }

    function test_25PercentDecreaseInPrice() public {
        depositToken0();
        depositToken1();
        advance();

        adjustPoolRatio((C.RAY * 75) / 100);
        advance();

        assertEq(vault.epochToToken0Rate(2), C.RAY);
        assertTrue(vault.epochToToken1Rate(2) > (C.RAY * 94) / 100);
    }

    function test_50PercentDecreaseInPrice() public {
        depositToken0();
        depositToken1();
        advance();

        adjustPoolRatio((C.RAY * 50) / 100);
        advance();

        assertEq(vault.epochToToken0Rate(2), C.RAY);
        assertTrue(vault.epochToToken1Rate(2) > (C.RAY * 41) / 100);
    }

    function test_95PercentDecreaseInPrice() public {
        depositToken0();
        depositToken1();
        advance();

        adjustPoolRatio((C.RAY * 5) / 100);
        advance();

        assertTrue(vault.epochToToken0Rate(2) > (C.RAY * 33) / 100);
        assertEq(vault.epochToToken1Rate(2), (C.RAY * 5) / 100);
    }

    function test_thoroughBalanceCheck() public {
        depositToken0();
        depositToken1();
        advance();

        assertEq(getToken0UserDeposited(), amount);
        assertEq(getToken1UserDeposited(), amount);
        assertEq(getToken0UserPendingDeposit(), 0);
        assertEq(getToken1UserPendingDeposit(), 0);
        assertEq(getToken0UserClaimable(), 0);
        assertEq(getToken1UserClaimable(), 0);
        assertEq(getToken0UserWithdrawRequests(), 0);
        assertEq(getToken1UserWithdrawRequests(), 0);

        assertEq(getToken0Active(), amount);
        assertEq(getToken1Active(), amount);
        assertEq(getToken0Reserves(), 0);
        assertEq(getToken1Reserves(), 0);
        assertEq(getToken0DepositRequests(), 0);
        assertEq(getToken1DepositRequests(), 0);
        assertEq(getToken0WithdrawRequests(), 0);
        assertEq(getToken1WithdrawRequests(), 0);
        assertEq(getToken0Claimable(), 0);
        assertEq(getToken1Claimable(), 0);

        withdrawToken0();
        withdrawToken1();

        assertEq(getToken0UserDeposited(), amount);
        assertEq(getToken1UserDeposited(), amount);
        assertEq(getToken0UserPendingDeposit(), 0);
        assertEq(getToken1UserPendingDeposit(), 0);
        assertEq(getToken0UserClaimable(), 0);
        assertEq(getToken1UserClaimable(), 0);
        assertEq(getToken0UserWithdrawRequests(), amount);
        assertEq(getToken1UserWithdrawRequests(), amount);

        assertEq(getToken0Active(), amount);
        assertEq(getToken1Active(), amount);
        assertEq(getToken0Reserves(), 0);
        assertEq(getToken1Reserves(), 0);
        assertEq(getToken0DepositRequests(), 0);
        assertEq(getToken1DepositRequests(), 0);
        assertEq(getToken0WithdrawRequests(), amount);
        assertEq(getToken1WithdrawRequests(), amount);
        assertEq(getToken0Claimable(), 0);
        assertEq(getToken1Claimable(), 0);

        advance();

        assertEq(getToken0UserDeposited(), 0);
        assertEq(getToken1UserDeposited(), 0);
        assertEq(getToken0UserPendingDeposit(), 0);
        assertEq(getToken1UserPendingDeposit(), 0);
        assertEq(getToken0UserClaimable(), amount);
        assertEq(getToken1UserClaimable(), amount);
        assertEq(getToken0UserWithdrawRequests(), 0);
        assertEq(getToken1UserWithdrawRequests(), 0);

        assertEq(getToken0Active(), 0);
        assertEq(getToken1Active(), 0);
        assertEq(getToken0Reserves(), 0);
        assertEq(getToken1Reserves(), 0);
        assertEq(getToken0DepositRequests(), 0);
        assertEq(getToken1DepositRequests(), 0);
        assertEq(getToken0WithdrawRequests(), 0);
        assertEq(getToken1WithdrawRequests(), 0);
        assertEq(getToken0Claimable(), amount);
        assertEq(getToken1Claimable(), amount);

        claimToken0();
        claimToken1();

        assertEq(getToken0UserClaimable(), 0);
        assertEq(getToken1UserClaimable(), 0);

        assertEq(getToken0Claimable(), 0);
        assertEq(getToken1Claimable(), 0);
    }

    function test_collectProtocolFeeAfterProfit() public {
        vm.prank(governor);
        core.setProtocolFee(1000);

        depositToken0();
        depositToken1();
        advance();

        simulateFees(amount, amount);
        withdrawToken0();
        withdrawToken1();

        advance();

        (uint256 token0Fees, uint256 token1Fees) = vault.feesAccrued();
        assertTrue(token0Fees > 0);
        assertEq(token1Fees, 0);

        vault.collectFees();
        assertEq(token0.balanceOf(feeTo), token0Fees);
        assertEq(token1.balanceOf(feeTo), token1Fees);
    }
}
