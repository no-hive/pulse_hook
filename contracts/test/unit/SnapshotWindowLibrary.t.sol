// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {SnapshotWindowLibrary} from "../../src/lib/SnapshotWindowLibrary.sol";

// -----------------------------------------------------------------------
// Unit tests for SnapshotWindowLibrary (recordIfNewBlock / average).
//
// SOURCE: no draft test isolated this library directly — the rolling
// window's smoothing effect was only ever exercised indirectly, across
// many blocks, through the integration tests in
// test/integration/MPFHook.t.sol. Nothing to move here.
//
// SnapshotWindowLibrary.State lives in storage, so this test contract
// needs to hold its own `State` slot and call the library on it directly
// (`using SnapshotWindowLibrary for SnapshotWindowLibrary.State;`) — no
// hook deployment needed, this is pure storage manipulation + vm.roll.
// -----------------------------------------------------------------------
contract SnapshotWindowLibraryTest is Test {
    using SnapshotWindowLibrary for SnapshotWindowLibrary.State;

    SnapshotWindowLibrary.State internal snapshotState;

    // =====================================================================
    // recordIfNewBlock
    // =====================================================================

    function test_RecordIfNewBlock_SameBlock_IsNoOp() public {
        snapshotState.recordIfNewBlock(100); // records in current block
        snapshotState.recordIfNewBlock(9999); // same block -> must be a no-op

        // If the second call had recorded, a 2-entry average of (100,
        // 9999) would be 5049 (or 5050 depending on rounding); observing
        // exactly 100 proves only the first call landed.
        assertEq(snapshotState.average(), 100, "second call within the same block must not overwrite/append");
    }

    function test_RecordIfNewBlock_ManyCallsSameBlock_OnlyFirstCounts() public {
        for (uint256 i; i < 10; i++) {
            snapshotState.recordIfNewBlock(int256(i) * 1000);
        }
        assertEq(snapshotState.average(), 0, "only the first call's value (0) should have been recorded");
    }

    function test_RecordIfNewBlock_RecordsOnceOnNextNewBlock() public {
        snapshotState.recordIfNewBlock(100); // block N

        vm.roll(block.number + 1);
        snapshotState.recordIfNewBlock(200); // block N+1

        // Two distinct blocks recorded -> average of (100, 200) == 150.
        assertEq(snapshotState.average(), 150);
    }

    function test_RecordIfNewBlock_SkippedBlocksAreFine_OnlyCallsRecord() public {
        // The library only records on blocks where the pool actually saw
        // a call; it does not need every block to be touched.
        snapshotState.recordIfNewBlock(10); // block N

        vm.roll(block.number + 50); // many blocks pass untouched
        snapshotState.recordIfNewBlock(20); // block N+50

        assertEq(snapshotState.average(), 15);
    }

    function test_RecordIfNewBlock_CountSaturatesAtWindowSize() public {
        for (uint256 i; i < SnapshotWindowLibrary.SNAPSHOT_WINDOW + 5; i++) {
            snapshotState.recordIfNewBlock(int256(i));
            vm.roll(block.number + 1);
        }

        // No public getter for `count`, so assert saturation indirectly:
        // once past the window size, older entries must be overwritten
        // (checked precisely in the averaging test below). Here we just
        // confirm the buffer didn't grow unbounded by checking the mean
        // matches an exactly-15-element window, not a 20-element one.
        // values recorded: 0..19 (20 blocks); window keeps the last 15: 5..19
        int256 expectedSum;
        for (int256 v = 5; v <= 19; v++) {
            expectedSum += v;
        }
        assertEq(snapshotState.average(), expectedSum / 15);
    }

    function test_RecordIfNewBlock_CircularBufferOverwritesOldestFirst() public {
        uint256 window = SnapshotWindowLibrary.SNAPSHOT_WINDOW;

        // Fill the window exactly: values 1..15 -> average = 8.
        for (uint256 i = 1; i <= window; i++) {
            snapshotState.recordIfNewBlock(int256(i));
            vm.roll(block.number + 1);
        }
        assertEq(snapshotState.average(), 8, "full window of 1..15 must average to 8");

        // One more block writes 16, overwriting the oldest slot (1).
        // New set is 2..16 -> average = 9.
        snapshotState.recordIfNewBlock(16);
        assertEq(snapshotState.average(), 9, "oldest snapshot (1) must be evicted first");
    }

    function test_RecordIfNewBlock_ZeroBlockCollidesWithDefaultLastBlock() public {
        // Documents a genuine edge case rather than a bug: `lastBlock`
        // defaults to 0, so if the contract is ever called while
        // block.number == 0, recordIfNewBlock treats it as "already
        // recorded this block" and silently skips.
        vm.roll(0);
        snapshotState.recordIfNewBlock(777);

        assertEq(snapshotState.average(), 0, "a call at block 0 collides with the zero-initialized lastBlock");
    }

    // =====================================================================
    // average
    // =====================================================================

    function test_Average_ReturnsZero_BeforeAnySnapshot() public view {
        assertEq(snapshotState.average(), 0);
    }

    function test_Average_SingleSnapshot_EqualsThatValue() public {
        snapshotState.recordIfNewBlock(-42);
        assertEq(snapshotState.average(), -42);
    }

    function test_Average_PartialWindow_ComputesMean() public {
        int256[3] memory values = [int256(10), 20, 30];
        for (uint256 i; i < values.length; i++) {
            snapshotState.recordIfNewBlock(values[i]);
            vm.roll(block.number + 1);
        }
        assertEq(snapshotState.average(), 20);
    }

    function test_Average_NegativeValues_TruncatesTowardZero() public {
        // sum = -3, count = 2 -> -3 / 2 == -1 in Solidity (division
        // truncates toward zero, not floor), which is worth pinning down
        // explicitly since it affects how the reference value behaves
        // when the recent medians trend negative.
        snapshotState.recordIfNewBlock(-1);
        vm.roll(block.number + 1);
        snapshotState.recordIfNewBlock(-2);

        assertEq(snapshotState.average(), -1);
    }

    function test_Average_FullWindow_ComputesExactMean() public {
        uint256 window = SnapshotWindowLibrary.SNAPSHOT_WINDOW;
        int256 expectedSum;
        for (uint256 i = 1; i <= window; i++) {
            snapshotState.recordIfNewBlock(int256(i) * 3);
            expectedSum += int256(i) * 3;
            vm.roll(block.number + 1);
        }
        assertEq(snapshotState.average(), expectedSum / int256(window));
    }

    function testFuzz_Average_MatchesManualMean_PartialWindow(int128[5] memory values) public {
        int256 expectedSum;
        for (uint256 i; i < values.length; i++) {
            snapshotState.recordIfNewBlock(int256(values[i]));
            expectedSum += int256(values[i]);
            vm.roll(block.number + 1);
        }
        assertEq(snapshotState.average(), expectedSum / int256(values.length));
    }

    function testFuzz_RecordIfNewBlock_CountNeverExceedsWindow(uint8 numBlocks) public {
        uint256 blocks = bound(numBlocks, 0, 40);
        uint256 window = SnapshotWindowLibrary.SNAPSHOT_WINDOW;

        for (uint256 i; i < blocks; i++) {
            snapshotState.recordIfNewBlock(int256(i));
            vm.roll(block.number + 1);
        }

        // Indirect check: once `blocks >= window`, the average must equal
        // the mean of exactly the last `window` recorded values, proving
        // `count` saturated instead of growing past the array's bounds
        // (which would otherwise revert on out-of-bounds writes anyway,
        // but this confirms the *averaging* window size too).
        if (blocks >= window) {
            int256 expectedSum;
            for (uint256 v = blocks - window; v < blocks; v++) {
                expectedSum += int256(v);
            }
            assertEq(snapshotState.average(), expectedSum / int256(window));
        } else if (blocks > 0) {
            int256 expectedSum;
            for (uint256 v; v < blocks; v++) {
                expectedSum += int256(v);
            }
            assertEq(snapshotState.average(), expectedSum / int256(blocks));
        } else {
            assertEq(snapshotState.average(), 0);
        }
    }
}
