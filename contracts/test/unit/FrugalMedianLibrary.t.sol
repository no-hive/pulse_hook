// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {FrugalMedianLibrary} from "../../src/lib/FrugalMedianLibrary.sol";

// -----------------------------------------------------------------------
// Unit tests for FrugalMedianLibrary (frugalMedian / updateApproxMedian).
//
// SOURCE: no draft test isolated this library directly — its behavior was
// only ever exercised indirectly, end-to-end, through swaps in
// test/integration/MPFHook.t.sol (Tests 2-5: high/low/sustained priority
// fee pressure, convergence, recovery). Those integration tests stay
// where they are (they exercise FrugalMedianLibrary + SnapshotWindowLibrary
// + TickCheckerLibrary + PenaltyFeeLibrary together, through real
// PoolManager swaps) — nothing to move here.
//
// Both `frugalMedian` and `updateApproxMedian` are `public pure`, so they
// can be called directly on the library from this test contract — no hook
// deployment needed.
//
// NOTE ON METHOD: updateApproxMedian is a pure state-transition function
// over (newNumber, approxMedian, step, positive). Rather than only driving
// it through frugalMedian over long sequences (which makes expected values
// hard to hand-verify), most tests below call updateApproxMedian directly
// with crafted (approxMedian, step, positive) inputs to isolate individual
// branches (overshoot clamp, step-reset on reversal, no-op on equality).
// Each expected output in this file is hand-derived from the source above
// the branch it exercises.
// -----------------------------------------------------------------------
contract FrugalMedianLibraryTest is Test {
    // =====================================================================
    // updateApproxMedian — fresh-state single step
    // =====================================================================

    function test_UpdateApproxMedian_FreshState_FirstMoveUp() public pure {
        // newNumber=100 > approxMedian=0; positive starts false, so step
        // accumulates *negatively* (-stepIncrement(100) = -1), which is
        // <= 0, so the += (step>0)?step:1 floor kicks in: approxMedian
        // only advances by 1, not by |step|.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(100, 0, 0, false);
        assertEq(median, 1);
        assertEq(step, -1);
        assertTrue(positive);
    }

    function test_UpdateApproxMedian_FreshState_FirstMoveDown() public pure {
        // Mirror of the above for a downward first move.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(-100, 0, 0, false);
        assertEq(median, -1);
        assertEq(step, 1);
        assertFalse(positive);
    }

    function test_UpdateApproxMedian_NewNumberEqualsMedian_IsNoOp() public pure {
        // Neither branch in the source fires when newNumber == approxMedian,
        // so the triple must pass through completely unchanged — including
        // `step` and `positive`, not just `approxMedian`.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(42, 42, 7, true);
        assertEq(median, 42);
        assertEq(step, 7);
        assertTrue(positive);
    }

    // =====================================================================
    // updateApproxMedian — stepIncrement magnitude scaling
    // =====================================================================

    function test_UpdateApproxMedian_StepIncrement_FloorsAtOneForSmallMagnitude() public pure {
        // stepIncrement(10) = max(1, 10/100) = max(1, 0) = 1.
        (int256 median, int256 step,) = FrugalMedianLibrary.updateApproxMedian(10, 0, 0, true);
        assertEq(step, 1);
        assertEq(median, 1);
    }

    function test_UpdateApproxMedian_StepIncrement_ScalesWithMagnitude() public pure {
        // stepIncrement(1000) = max(1, 1000/100) = 10 — a 100x larger
        // observation produces a 10x larger single-step move than the
        // small-magnitude case above, given identical starting state.
        (int256 median, int256 step,) = FrugalMedianLibrary.updateApproxMedian(1000, 0, 0, true);
        assertEq(step, 10);
        assertEq(median, 10);
    }

    // =====================================================================
    // updateApproxMedian — overshoot clamp
    // =====================================================================

    function test_UpdateApproxMedian_OvershootUp_ClampsExactlyToNewNumber() public pure {
        // Craft a step (100) large enough that approxMedian + step would
        // sail past newNumber; the source must detect approxMedian >
        // newNumber afterward and clamp median to newNumber exactly,
        // folding the overshoot back into step.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(10, 5, 100, true);
        // step: 100 + stepIncrement(10)=1 -> 101; median: 5+101=106 (overshoots 10)
        // clamp: step += 10-106 = -96 -> 5; median = 10
        assertEq(median, 10);
        assertEq(step, 5);
        assertTrue(positive);
    }

    function test_UpdateApproxMedian_OvershootDown_ClampsExactlyToNewNumber() public pure {
        // Mirror of the above for a downward overshoot.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(-10, -5, 100, false);
        assertEq(median, -10);
        assertEq(step, 5);
        assertFalse(positive);
    }

    // =====================================================================
    // updateApproxMedian — step reset on direction reversal
    // =====================================================================

    function test_UpdateApproxMedian_ReversalUp_ResetsStepToOne() public pure {
        // Previous direction was down (positive=false); this move is up.
        // The `!positive && step > 1` branch must clamp the leftover
        // (now-stale) step back down to 1 once the direction flips.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(50, 0, 10, false);
        // step: 10 - stepIncrement(50)=1 -> 9; median: 0+9=9 (no overshoot vs 50)
        // reversal: !positive(true) && step(9)>1 -> step reset to 1
        assertEq(median, 9);
        assertEq(step, 1);
        assertTrue(positive);
    }

    function test_UpdateApproxMedian_ReversalDown_ResetsStepToOne() public pure {
        // Mirror of the above for a downward reversal after an upward run.
        (int256 median, int256 step, bool positive) = FrugalMedianLibrary.updateApproxMedian(-50, 0, 10, true);
        assertEq(median, -9);
        assertEq(step, 1);
        assertFalse(positive);
    }

    // =====================================================================
    // updateApproxMedian — convergence & post-convergence stability
    // =====================================================================

    function test_UpdateApproxMedian_ConvergesAndThenHoldsExactly() public pure {
        int256 target = 12345;
        int256 median;
        int256 step;
        bool positive;

        // The step accumulates roughly quadratically while moving in one
        // direction, so a couple hundred repeats of the same observation
        // is comfortably enough for even a large target to be reached and
        // then clamped to exactly via the overshoot correction.
        for (uint256 i; i < 300; i++) {
            (median, step, positive) = FrugalMedianLibrary.updateApproxMedian(target, median, step, positive);
        }
        assertEq(median, target, "estimator must fully converge given enough same-direction updates");

        // Once median == target, further identical observations must be
        // no-ops (equality branch), so it stays put indefinitely.
        (int256 medianAfter, int256 stepAfter, bool positiveAfter) =
            FrugalMedianLibrary.updateApproxMedian(target, median, step, positive);
        assertEq(medianAfter, target);
        assertEq(stepAfter, step);
        assertEq(positiveAfter, positive);
    }

    function test_UpdateApproxMedian_ConvergesForNegativeTarget() public pure {
        int256 target = -9876;
        int256 median;
        int256 step;
        bool positive;

        for (uint256 i; i < 300; i++) {
            (median, step, positive) = FrugalMedianLibrary.updateApproxMedian(target, median, step, positive);
        }
        assertEq(median, target);
    }

    // =====================================================================
    // updateApproxMedian — safety
    // =====================================================================

    function testFuzz_UpdateApproxMedian_NeverReverts(
        int256 newNumber,
        int256 approxMedian,
        int256 step,
        bool positive
    ) public pure {
        // Bound to a realistic priority-fee-like range: the function body
        // is `unchecked`, so extreme inputs near int256's edges can wrap
        // silently rather than revert — that's a separate concern from
        // "does normal operation ever revert", which is what this test
        // checks.
        newNumber = bound(newNumber, -1e30, 1e30);
        approxMedian = bound(approxMedian, -1e30, 1e30);
        step = bound(step, -1e30, 1e30);

        FrugalMedianLibrary.updateApproxMedian(newNumber, approxMedian, step, positive);
    }

    // =====================================================================
    // frugalMedian — batch folding
    // =====================================================================

    function test_FrugalMedian_EmptySequence_ReturnsZero() public pure {
        int256[] memory sequence = new int256[](0);
        assertEq(FrugalMedianLibrary.frugalMedian(sequence), 0);
    }

    function test_FrugalMedian_SingleElement_MatchesSingleUpdateCall() public pure {
        int256[] memory sequence = new int256[](1);
        sequence[0] = 100;

        (int256 expected,,) = FrugalMedianLibrary.updateApproxMedian(100, 0, 0, false);
        assertEq(FrugalMedianLibrary.frugalMedian(sequence), expected);
    }

    function test_FrugalMedian_RepeatedValue_MatchesHandTracedProgression() public pure {
        // Five repeats of 100 from a fresh estimator; approxMedian
        // progresses 0 -> 1 -> 2 -> 3 -> 5 -> 8 per the source's
        // arithmetic (hand-traced update by update).
        int256[] memory sequence = new int256[](5);
        for (uint256 i; i < 5; i++) {
            sequence[i] = 100;
        }
        assertEq(FrugalMedianLibrary.frugalMedian(sequence), 8);
    }

    function test_FrugalMedian_MatchesManualFoldOverUpdateApproxMedian() public pure {
        int256[] memory sequence = new int256[](6);
        sequence[0] = 50;
        sequence[1] = 200;
        sequence[2] = 150;
        sequence[3] = -30;
        sequence[4] = -30;
        sequence[5] = 1000;

        int256 median;
        int256 step;
        bool positive;
        for (uint256 i; i < sequence.length; i++) {
            (median, step, positive) = FrugalMedianLibrary.updateApproxMedian(sequence[i], median, step, positive);
        }

        assertEq(FrugalMedianLibrary.frugalMedian(sequence), median, "frugalMedian must fold identically to a manual loop over updateApproxMedian");
    }

    // =====================================================================
    // frugalMedian — bounding invariant
    // =====================================================================

    function testFuzz_FrugalMedian_StaysWithinRangeOfZeroAndObservedValues(int256[10] memory rawValues) public pure {
        // Each update moves approxMedian strictly toward newNumber and
        // never past it (clamped by the overshoot correction), so across
        // any sequence the estimate can never leave the convex hull of
        // {0} (the fresh-estimator starting point) and every value seen
        // so far. Bounded to a realistic magnitude to sidestep unrelated
        // `unchecked` wraparound at int256's extremes.
        int256[] memory sequence = new int256[](10);
        int256 minSeen;
        int256 maxSeen;
        for (uint256 i; i < 10; i++) {
            int256 v = bound(rawValues[i], -1e18, 1e18);
            sequence[i] = v;
            if (v < minSeen) minSeen = v;
            if (v > maxSeen) maxSeen = v;
        }

        int256 result = FrugalMedianLibrary.frugalMedian(sequence);
        assertGe(result, minSeen, "estimate must never fall below the lowest value seen (or 0)");
        assertLe(result, maxSeen, "estimate must never exceed the highest value seen (or 0)");
    }

    function testFuzz_UpdateApproxMedian_SingleStepNeverPassesNewNumber(int256 approxMedian, int256 newNumber)
        public
        pure
    {
        approxMedian = bound(approxMedian, -1e18, 1e18);
        newNumber = bound(newNumber, -1e18, 1e18);
        vm.assume(newNumber != approxMedian);

        // Use a small, realistic starting step/direction so we're testing
        // ordinary operation rather than a contrived overshoot setup.
        (int256 median,,) = FrugalMedianLibrary.updateApproxMedian(newNumber, approxMedian, 1, newNumber > approxMedian);

        if (newNumber > approxMedian) {
            assertGt(median, approxMedian, "an upward move must strictly advance the estimate");
            assertLe(median, newNumber, "an upward move must never overshoot past newNumber");
        } else {
            assertLt(median, approxMedian, "a downward move must strictly advance the estimate");
            assertGe(median, newNumber, "a downward move must never overshoot past newNumber");
        }
    }
}
