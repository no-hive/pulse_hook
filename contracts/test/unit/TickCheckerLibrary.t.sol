// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickCheckerLibrary} from "../../src/lib/TickCheckerLibrary.sol";

// -----------------------------------------------------------------------
// Unit tests for TickCheckerLibrary (movedEnoughToUpdate / requiredMovement).
//
// SOURCE: none of the three draft files test this gate in isolation —
// the tick-movement requirement was never directly exercised (the
// integration/fork drafts always used a fresh baseline tick, so the gate
// was implicitly satisfied on every swap's first observation). This is a
// real coverage gap worth flagging: the tick checker is the mechanism
// that stops dust-swap median manipulation, so it deserves dedicated
// tests here.
//
// TickCheckerLibrary.State holds mappings, so it must stay in storage;
// this test contract holds its own `State` slot and calls the library on
// it directly — no hook deployment needed for the movedEnoughToUpdate
// logic itself. requiredMovement is `pure` and callable directly with any
// liquidity value.
// -----------------------------------------------------------------------
contract TickCheckerLibraryTest is Test {
    using TickCheckerLibrary for TickCheckerLibrary.State;

    TickCheckerLibrary.State internal tickCheckerState;

    PoolId internal constant POOL_A = PoolId.wrap(bytes32(uint256(1)));
    PoolId internal constant POOL_B = PoolId.wrap(bytes32(uint256(2)));

    // =====================================================================
    // movedEnoughToUpdate
    // =====================================================================

    function test_MovedEnoughToUpdate_FirstObservation_AlwaysAccepts() public {
        // Arbitrary tick/liquidity — first observation for a pool has
        // nothing to compare against, so it must always accept and seed
        // the baseline, regardless of values.
        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 12345, 1);
        assertTrue(accepted, "first observation must be accepted");
    }

    function test_MovedEnoughToUpdate_FirstObservation_SetsBaselineToCurrentTick() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, -777, 1e21);

        // No public getter, so re-derive the baseline indirectly: a
        // second call with delta == 0 must now be rejected (assuming
        // requiredMovement(1e21) > 0, which it always is per MIN_TICK_THRESHOLD).
        bool secondCall = tickCheckerState.movedEnoughToUpdate(POOL_A, -777, 1e21);
        assertFalse(secondCall, "delta of 0 vs freshly-set baseline must be rejected");
    }

    function test_MovedEnoughToUpdate_RejectsBelowThreshold() public {
        // liquidity == REFERENCE_LIQUIDITY -> requiredMove == BASE_TICK_THRESHOLD (10)
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21); // seeds baseline at 0

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 5, 1e21); // delta = 5 < 10
        assertFalse(accepted, "delta below threshold must be rejected");
    }

    function test_MovedEnoughToUpdate_RejectedSwap_DoesNotMoveBaseline() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21); // baseline = 0

        tickCheckerState.movedEnoughToUpdate(POOL_A, 5, 1e21); // rejected, delta 5 < 10

        // Baseline should still be 0: a follow-up tick of 9 relative to 0
        // (delta 9, still < 10) must also be rejected. If the baseline had
        // been wrongly advanced to 5, delta vs 9 would be 4 either way —
        // so instead confirm via a tick that would only clear the
        // threshold from the *original* baseline.
        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 10, 1e21); // delta vs 0 = 10 (>=10)
        assertTrue(accepted, "delta of 10 vs original baseline 0 must be accepted");
    }

    function test_MovedEnoughToUpdate_AcceptsAtExactThreshold() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21); // baseline = 0, requiredMove = 10

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 10, 1e21); // delta == 10
        assertTrue(accepted, "delta exactly equal to requiredMove must be accepted (< is the reject condition, not <=)");
    }

    function test_MovedEnoughToUpdate_AcceptsAboveThreshold() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21);

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 50, 1e21); // delta = 50 > 10
        assertTrue(accepted, "delta above threshold must be accepted");
    }

    function test_MovedEnoughToUpdate_AcceptedSwap_AdvancesBaseline() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21); // baseline = 0
        tickCheckerState.movedEnoughToUpdate(POOL_A, 50, 1e21); // accepted, baseline -> 50

        // Next tick of 55 is only delta 5 from the *new* baseline (50), so
        // it must now be rejected even though it's delta 55 from the
        // original baseline.
        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 55, 1e21);
        assertFalse(accepted, "baseline must have advanced to the last accepted tick (50), not stayed at 0");
    }

    function test_MovedEnoughToUpdate_NegativeDirection_Accepted() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21);

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, -15, 1e21); // |delta| = 15 >= 10
        assertTrue(accepted, "negative-direction movement must use absolute delta");
    }

    function test_MovedEnoughToUpdate_NegativeDirection_Rejected() public {
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21);

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, -5, 1e21); // |delta| = 5 < 10
        assertFalse(accepted, "small negative-direction movement must still be rejected");
    }

    function test_MovedEnoughToUpdate_SequentialSwaps_TrackBaselineAcrossMultipleUpdates() public {
        assertTrue(tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 1e21), "seed"); // baseline = 0
        assertFalse(tickCheckerState.movedEnoughToUpdate(POOL_A, 4, 1e21), "delta 4 < 10"); // baseline stays 0
        assertFalse(tickCheckerState.movedEnoughToUpdate(POOL_A, 9, 1e21), "delta 9 < 10"); // baseline stays 0
        assertTrue(tickCheckerState.movedEnoughToUpdate(POOL_A, 12, 1e21), "delta 12 >= 10"); // baseline -> 12
        assertFalse(tickCheckerState.movedEnoughToUpdate(POOL_A, 15, 1e21), "delta 3 < 10 from new baseline 12");
        assertTrue(tickCheckerState.movedEnoughToUpdate(POOL_A, -5, 1e21), "delta 17 >= 10 from baseline 12"); // baseline -> -5
    }

    function test_MovedEnoughToUpdate_PoolsAreIndependent() public {
        // Establish and advance pool A's baseline far away from pool B's.
        tickCheckerState.movedEnoughToUpdate(POOL_A, 1000, 1e21);
        tickCheckerState.movedEnoughToUpdate(POOL_A, 1050, 1e21); // accepted, baseline -> 1050

        // Pool B has never been observed: its first call must still be
        // treated as a fresh baseline-seed, unaffected by pool A's state.
        bool poolBFirstCall = tickCheckerState.movedEnoughToUpdate(POOL_B, 1050, 1e21);
        assertTrue(poolBFirstCall, "pool B's first observation must be independent of pool A's baseline");

        // And pool A's threshold logic must still be evaluated against
        // its own baseline (1050), not pool B's.
        bool poolACall = tickCheckerState.movedEnoughToUpdate(POOL_A, 1055, 1e21); // delta 5 < 10
        assertFalse(poolACall, "pool A's gate must not be affected by pool B's activity");
    }

    function test_MovedEnoughToUpdate_ZeroLiquidity_UsesMaxThreshold() public {
        // requiredMovement(0) == MAX_TICK_THRESHOLD (200) per the explicit
        // liquidity == 0 branch.
        tickCheckerState.movedEnoughToUpdate(POOL_A, 0, 0);

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, 199, 0); // delta 199 < 200
        assertFalse(accepted, "at zero liquidity the gate should require the full MAX threshold");

        bool acceptedAtThreshold = tickCheckerState.movedEnoughToUpdate(POOL_A, 200, 0); // delta 200 == 200
        assertTrue(acceptedAtThreshold, "delta reaching the 200-tick max threshold must be accepted");
    }

    function testFuzz_MovedEnoughToUpdate_FirstObservationAlwaysAccepts(int24 tick, uint128 liquidity) public {
        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, tick, liquidity);
        assertTrue(accepted, "first observation must always accept regardless of tick/liquidity");
    }

    function testFuzz_MovedEnoughToUpdate_MatchesRequiredMovement(int16 baseline, int16 delta, uint128 liquidity)
        public
    {
        // Keep values well inside int24 range so the delta subtraction in
        // the library can't itself overflow and mask the behavior we're
        // testing.
        int24 baselineTick = int24(baseline);
        int24 movedTick = baselineTick + int24(delta);

        tickCheckerState.movedEnoughToUpdate(POOL_A, baselineTick, liquidity); // seed baseline

        int24 required = TickCheckerLibrary.requiredMovement(liquidity);
        int24 absDelta = int24(delta) < 0 ? -int24(delta) : int24(delta);

        bool accepted = tickCheckerState.movedEnoughToUpdate(POOL_A, movedTick, liquidity);
        assertEq(accepted, absDelta >= required, "acceptance must exactly match |delta| >= requiredMovement(liquidity)");
    }

    // =====================================================================
    // requiredMovement
    // =====================================================================

    function test_RequiredMovement_ZeroLiquidity_ReturnsMax() public pure {
        assertEq(TickCheckerLibrary.requiredMovement(0), TickCheckerLibrary.MAX_TICK_THRESHOLD);
    }

    function test_RequiredMovement_AtReferenceLiquidity_ReturnsBase() public pure {
        // sqrtReference / sqrtReference == 1 exactly, so this is the one
        // point where the scaling introduces no rounding error.
        int24 required = TickCheckerLibrary.requiredMovement(TickCheckerLibrary.REFERENCE_LIQUIDITY);
        assertEq(required, TickCheckerLibrary.BASE_TICK_THRESHOLD);
    }

    function test_RequiredMovement_VeryHighLiquidity_ClampsToMin() public pure {
        int24 required = TickCheckerLibrary.requiredMovement(type(uint128).max);
        assertEq(required, TickCheckerLibrary.MIN_TICK_THRESHOLD);
    }

    function test_RequiredMovement_VeryLowLiquidity_ClampsToMax() public pure {
        int24 required = TickCheckerLibrary.requiredMovement(1);
        assertEq(required, TickCheckerLibrary.MAX_TICK_THRESHOLD);
    }

    function test_RequiredMovement_DeeperThanReference_IsSmallerThanBase() public pure {
        // A pool well above REFERENCE_LIQUIDITY should require a smaller
        // (or equal, once clamped) tick move than a pool sitting exactly
        // at the reference.
        int24 required = TickCheckerLibrary.requiredMovement(TickCheckerLibrary.REFERENCE_LIQUIDITY * 100);
        assertLe(required, TickCheckerLibrary.BASE_TICK_THRESHOLD);
    }

    function test_RequiredMovement_ShallowerThanReference_IsLargerThanBase() public pure {
        int24 required = TickCheckerLibrary.requiredMovement(TickCheckerLibrary.REFERENCE_LIQUIDITY / 100);
        assertGe(required, TickCheckerLibrary.BASE_TICK_THRESHOLD);
    }

    function test_RequiredMovement_ResultAlwaysWithinConfiguredBounds() public pure {
        uint128[5] memory samples =
            [uint128(0), 1, TickCheckerLibrary.REFERENCE_LIQUIDITY, 1e30, type(uint128).max];

        for (uint256 i = 0; i < samples.length; i++) {
            int24 required = TickCheckerLibrary.requiredMovement(samples[i]);
            assertGe(required, TickCheckerLibrary.MIN_TICK_THRESHOLD, "must never fall below MIN_TICK_THRESHOLD");
            assertLe(required, TickCheckerLibrary.MAX_TICK_THRESHOLD, "must never exceed MAX_TICK_THRESHOLD");
        }
    }

    function testFuzz_RequiredMovement_AlwaysWithinBounds(uint128 liquidity) public pure {
        int24 required = TickCheckerLibrary.requiredMovement(liquidity);
        assertGe(required, TickCheckerLibrary.MIN_TICK_THRESHOLD);
        assertLe(required, TickCheckerLibrary.MAX_TICK_THRESHOLD);
    }

    function testFuzz_RequiredMovement_MonotonicallyNonIncreasingInLiquidity(uint128 liquidityLow, uint128 liquidityHigh)
        public
        pure
    {
        vm.assume(liquidityLow > 0);
        vm.assume(liquidityHigh > liquidityLow);

        int24 requiredLow = TickCheckerLibrary.requiredMovement(liquidityLow);
        int24 requiredHigh = TickCheckerLibrary.requiredMovement(liquidityHigh);

        // More liquidity can only require an equal or smaller tick move,
        // never a larger one — the whole point of the sqrt scaling.
        assertGe(requiredLow, requiredHigh, "required movement must be non-increasing as liquidity grows");
    }

    function testFuzz_RequiredMovement_NeverZero(uint128 liquidity) public pure {
        // MIN_TICK_THRESHOLD is 1, so the gate can never be fully
        // disabled (every swap would otherwise trivially "move enough").
        int24 required = TickCheckerLibrary.requiredMovement(liquidity);
        assertGt(required, 0);
    }
}
