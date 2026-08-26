// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {GetPriorityFeeLibrary} from "../../src/lib/GetPriorityFeeLibrary.sol";

// -----------------------------------------------------------------------
//
// Unit tests for GetPriorityFeeLibrary.getPriorityFee
// (tx.gasprice - block.basefee, floored at 0).
//
// getPriorityFee is internal view (reads tx.gasprice/block.basefee), so
// it can be called directly from this test contract after setting
// vm.fee(...) / vm.txGasPrice(...) — no hook deployment needed.
//
// Note:
// Both vm.fee() and vm.txGasPrice() are limited to uint64 values,
// so fuzz tests use uint64 for both baseFee and gasPrice.
// -----------------------------------------------------------------------

contract GetPriorityFeeLibraryTest is Test {
    function test_GetPriorityFee_GasPriceAboveBaseFee_ReturnsDifference()
        public
    {
        vm.fee(10 gwei);
        vm.txGasPrice(15 gwei);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertEq(priorityFee, 5 gwei);
    }

    function test_GetPriorityFee_GasPriceEqualsBaseFee_ReturnsZero()
        public
    {
        vm.fee(10 gwei);
        vm.txGasPrice(10 gwei);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertEq(
            priorityFee,
            0,
            "equal gasprice/basefee must floor to 0, not revert"
        );
    }

    function test_GetPriorityFee_GasPriceBelowBaseFee_ReturnsZeroWithoutUnderflow()
        public
    {
        // Models a legacy tx (or a base-fee spike between submission and
        // inclusion) where tx.gasprice ends up below block.basefee. A
        // naive tx.gasprice - block.basefee would underflow and revert;
        // the library must instead floor to 0.

        vm.fee(10 gwei);
        vm.txGasPrice(3 gwei);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertEq(priorityFee, 0);
    }

    function test_GetPriorityFee_ZeroBaseFee_ReturnsFullGasPrice()
        public
    {
        vm.fee(0);
        vm.txGasPrice(7 gwei);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertEq(priorityFee, 7 gwei);
    }

    function test_GetPriorityFee_BothZero_ReturnsZero() public {
        vm.fee(0);
        vm.txGasPrice(0);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertEq(priorityFee, 0);
    }

    function test_GetPriorityFee_LargeValues_NoOverflow() public {
        // Both vm.fee() and vm.txGasPrice() are limited to uint64.
        // Use the largest valid value for both.

        uint256 baseFee = type(uint64).max - 1000;
        uint256 gasPrice = type(uint64).max;

        vm.fee(baseFee);
        vm.txGasPrice(gasPrice);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertEq(priorityFee, 1000);
    }

    function testFuzz_GetPriorityFee_MatchesFlooredSubtraction(
        uint64 baseFee,
        uint64 gasPrice
    ) public {
        vm.fee(baseFee);
        vm.txGasPrice(gasPrice);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();
        uint256 expected = gasPrice > baseFee ? gasPrice - baseFee : 0;

        assertEq(
            priorityFee,
            expected,
            "must equal max(gasPrice - baseFee, 0)"
        );
    }

    function testFuzz_GetPriorityFee_NeverReverts(
        uint64 baseFee,
        uint64 gasPrice
    ) public {
        vm.fee(baseFee);
        vm.txGasPrice(gasPrice);

        // The call itself succeeding (no revert/underflow) is the
        // assertion here, regardless of the returned value.

        GetPriorityFeeLibrary.getPriorityFee();
    }

    function testFuzz_GetPriorityFee_ResultNeverExceedsGasPrice(
        uint64 baseFee,
        uint64 gasPrice
    ) public {
        vm.fee(baseFee);
        vm.txGasPrice(gasPrice);

        uint256 priorityFee = GetPriorityFeeLibrary.getPriorityFee();

        assertLe(
            priorityFee,
            gasPrice,
            "the tip can never exceed the total gas price paid"
        );
    }
}