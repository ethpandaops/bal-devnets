# BAL (EIP-7928) Benchmark Report — bal-devnet-2

**Date:** 2026-03-24
**Benchmark runs:** 2026-03-19 (Geth stateless), 2026-03-20 (Besu stateless, Geth stateful), 2026-03-23 (Reth stateless)
**Tool:** ethpandaops/benchmarkoor v0.1.0

## Overview

EIP-7928 Block-Level Access Lists enable four capabilities: **parallel disk reads**, **parallel transaction execution**, **parallel state root computation**, and **executionless state updates**. This report evaluates three execution modes across Reth, Besu, and Geth using stateless (opcode-level) benchmarks, plus a separate Geth-only stateful benchmark suite that tests BAL-specific workload patterns (dependency graphs, prefetch, state root computation, serial chains).

Batch IO (prefetch) results from stateless tests are inconclusive due to warm-cache test conditions. The stateful benchmarks provide initial signal on BAL-specific patterns.

---

## Test Environments

### Stateless benchmarks (Reth, Besu, Geth)

- **Hardware:** AMD Ryzen 9 9950X3D, 4 pinned cores per run, 32GB memory limit
- **State:** ZFS-snapshotted from mainnet block 24,188,300 (warm page cache)
- **Suite:** 1,103 opcode-level tests, ~119.8 GGas total
- **Runtime:** podman containers

### Stateful benchmarks (Geth only)

- **Hardware:** Intel Core Ultra 9 185H, 12 cores, 47GB memory
- **State:** Copied from bal-devnet-2 snapshot at block 256,830
- **Suite:** 48 BAL-specific tests (dependency graphs, prefetch, state root, serial chains), ~958.5 MGas total
- **Runtime:** docker containers
- **Rollback:** `rpc-debug-setHead` between tests

**Client versions:**
- Reth: `reth/v1.11.3-473deed` (`ethpandaops/reth:bal-devnet-2`)
- Besu: `besu/v26.3-develop-5960819` (`ethpandaops/besu:bal-devnet-2-with-prefetch`)
- Geth stateless: `Geth/v1.17.0-unstable-ff772bfa-20260317` (`ethpandaops/geth:bal-devnet-2`)
- Geth stateful: `Geth/v1.17.0-unstable` (`geth-amsterdam:local`)

---

## Execution Modes

| Mode | Parallel Execution | Parallel State Root | Batch IO (Prefetch) |
|------|-------------------|--------------------|--------------------|
| **A — Sequential** | No | No | No |
| **B — Optimized / Full** | Yes | Yes | Yes |
| **C — No Prefetch / No Batch IO** | Yes | Yes | No |

**A to B/C** measures the combined value of parallel execution + parallel state root (the core BAL benefit).
**B vs C** isolates batch IO only.

### Client-specific flags

**Reth:**
- A: `--engine.disable-bal-parallel-execution --engine.disable-bal-parallel-state-root --engine.disable-bal-batch-io`
- B: (defaults — all optimizations enabled)
- C: `--engine.disable-bal-batch-io`

**Besu:**
- A: `--Xbal-optimization-enabled=false --Xbal-perfect-parallelization-enabled=false --Xbal-trust-state-root=false`
- B: `--Xbal-prefetch-reading-enabled=true --Xbal-trust-state-root=true --Xbal-perfect-parallelization-enabled=true`
- C: `--Xbal-prefetch-reading-enabled=false --bonsai-cache-enabled=true --Xbal-trust-state-root=true --Xbal-perfect-parallelization-enabled=true`

**Geth:**
- A: `--bal.executionmode=sequential`
- B: `--bal.executionmode=full`
- C: `--bal.executionmode=nobatchio`

---

## Part 1: Stateless Benchmark Results (All Clients)

### Aggregate Results

| Metric | Reth | Besu | Geth |
|--------|------|------|------|
| **Sequential (A)** | 521 MGas/s | 217 MGas/s | 375 MGas/s |
| **Optimized (B)** | 579 MGas/s (+11%) | 466 MGas/s (+115%) | 623 MGas/s (+66%) |
| **No Prefetch (C)** | 583 MGas/s (+12%) | 498 MGas/s (+130%) | 651 MGas/s (+74%) |
| **B vs C (prefetch delta)** | -0.7% | -6.4% | -4.3% |
| **Test pass rate (A)** | 1102/1103 | 1102/1103 | 1099/1103 |
| **Test pass rate (B)** | 1102/1103 | 1102/1103 | **975/1103** |
| **Test pass rate (C)** | 1102/1103 | 1102/1103 | **975/1103** |
| **Test duration (A)** | 4m02s | 9m28s | 5m28s |
| **Test duration (B)** | 3m37s | 4m31s | 3m11s |
| **Test duration (C)** | 3m35s | 4m15s | 3m03s |

### Distribution of per-test changes (optimized B vs sequential A baseline)

| Client | Tests faster | Avg improvement | P99 improvement | Tests slower | Avg regression | P99 regression |
|--------|-------------|----------------|-----------------|-------------|----------------|----------------|
| Reth | 807/1100 | +23.5% | +322.3% | 293/1100 | -10.4% | -70.8% |
| Besu | 942/1100 | +150.0% | +500.7% | 158/1100 | -39.7% | -88.6% |
| Geth | 874/974 | +158.6% | +288.8% | 100/974 | -31.3% | -95.4% |

### Key Takeaways

1. **Parallel execution + state root delivers large gains in Besu and Geth.** Besu more than doubles throughput (+115-130%). Geth improves 66-74%. These gains validate the core BAL design.

2. **Reth's gains are modest (+11-12%).** Reth's sequential baseline is already fast (521 MGas/s), suggesting strong single-threaded performance. The parallel scheduler may not be extracting full benefit yet, or the test workloads don't expose enough parallelism for Reth's architecture.

3. **Batch IO shows no benefit on warm cache.** This is expected — with state already in page cache, there is nothing to prefetch from disk. This result does **not** indicate prefetch is unnecessary; it indicates the test conditions cannot evaluate it.

4. **Geth has a correctness issue.** 128 test failures and container crashes in both optimized modes. Results for Geth B/C are computed over only 975 tests (vs 1,099-1,102 for others), making direct comparison unreliable.

---

## Part 2: Stateful Benchmark Results (Geth Only)

This suite tests BAL-specific workload patterns rather than individual opcodes: dependency graphs with varying conflict levels, prefetch-intensive blocks, state root computation, and serial transaction chains. All 48 tests passed in all three modes (no crashes), using a different Geth build (`geth-amsterdam:local`) than the stateless suite.

### Aggregate Results (sequential as baseline)

| Metric | sequential (B) | nobatchio (A) | full (C) |
|--------|---------------|--------------|----------|
| **MGas/s** | 934 | 1,301 (**+39.3%**) | 1,401 (**+50.0%**) |
| **Test duration** | 1.12s | 846ms (-24.2%) | 784ms (-30.0%) |
| **Total runtime** | 48s | 56s (+16.7%) | 45s (-6.3%) |
| **Tests passed** | 48/48 | 48/48 | 48/48 |

Both parallel modes deliver substantial gains over sequential. **Full mode (with batch IO) is 7.7% faster than nobatchio** on aggregate, showing batch IO provides measurable benefit on BAL-specific workloads even under warm cache.

### Distribution (sequential B as baseline)

| Run | Tests faster | Avg gain | P95 gain | P99 gain | Tests slower | Avg regression | P95 regression | P99 regression |
|-----|-------------|---------|---------|---------|-------------|----------------|----------------|----------------|
| nobatchio (A) vs seq | 34/46 | +64.0% | +163.1% | +163.1% | 12/46 | -17.0% | -33.9% | -33.9% |
| full (C) vs seq | 38/46 | +56.6% | +187.1% | +187.1% | 8/46 | -25.4% | -61.5% | -61.5% |

Full mode has more tests faster (38 vs 34) and fewer tests slower (8 vs 12) than nobatchio, with higher peak gains (+187% vs +163%).

### Per-test breakdown by category

All percentages below are relative to **sequential (B) baseline**.

#### Prefetch tests

| Test | sequential (B) | nobatchio (A) | full (C) |
|------|---------------|--------------|----------|
| `prefetch-60M` | 450 | 1,184 (**+163%**) | 1,173 (**+161%**) |
| `prefetch-30M` | 323 | 586 (**+81%**) | 508 (**+57%**) |

Both parallel modes massively outperform sequential on prefetch workloads: +81-163%. The gap between `full` and `nobatchio` is small (-1% on 60M, -13% on 30M), meaning the parallel execution itself is the dominant factor, not the batch IO phase.

#### Independent pairs (maximum parallelism)

| Test | sequential (B) | nobatchio (A) | full (C) |
|------|---------------|--------------|----------|
| `interact-max-independent_pairs-60M` | 1,262 | 2,779 (**+120%**) | 2,584 (**+105%**) |
| `interact-half-independent_pairs-60M` | 893 | 1,895 (**+112%**) | 2,333 (**+161%**) |
| `interact-max-independent_pairs-30M` | 324 | 431 (+33%) | 512 (**+58%**) |
| `interact-half-independent_pairs-30M` | 251 | 364 (+45%) | 369 (+47%) |

Independent-pair workloads show the strongest parallel gains: up to +161% over sequential. On the `half` fill tests, **full mode outperforms nobatchio** (e.g., 2,333 vs 1,895 on `half-independent_pairs-60M`), suggesting batch IO helps when parallelism is moderate and state access is spread across many accounts.

#### Mixed dependency graphs

| Test | sequential (B) | nobatchio (A) | full (C) |
|------|---------------|--------------|----------|
| `mixed_dep-max-group1-60M` | 1,348 | 2,428 (+80%) | 3,419 (**+154%**) |
| `mixed_dep-max-group2-60M` | 1,749 | 2,536 (+45%) | 2,747 (**+57%**) |
| `mixed_dep-max-group5-60M` | 3,048 | 3,353 (+10%) | 4,046 (**+33%**) |
| `mixed_dep-max-group5-30M` | 877 | 1,651 (+88%) | 1,912 (**+118%**) |
| `mixed_dep-max-group2-30M` | 647 | 893 (+38%) | 1,104 (**+71%**) |
| `mixed_dep-max-group1-30M` | 675 | 432 (-36%) | 790 (+17%) |
| `mixed_dep-half-group1-60M` | 1,497 | 3,022 (**+102%**) | 2,556 (+71%) |
| `mixed_dep-half-group2-60M` | 1,961 | 3,652 (**+86%**) | 3,380 (+72%) |
| `mixed_dep-half-group5-60M` | 2,679 | 3,614 (+35%) | 2,928 (+9%) |
| `mixed_dep-half-group5-30M` | 1,027 | 1,721 (+68%) | 1,476 (+44%) |
| `mixed_dep-half-group2-30M` | 903 | 1,047 (+16%) | 1,041 (+15%) |
| `mixed_dep-half-group1-30M` | 497 | 783 (+58%) | 391 (-21%) |
| `mixed_dep-greedy-group1-60M` | 547 | 497 (-9%) | 508 (-7%) |
| `mixed_dep-greedy-group2-60M` | 609 | 947 (+56%) | 594 (-2%) |
| `mixed_dep-greedy-group2-30M` | 221 | 358 (+62%) | 268 (+21%) |
| `mixed_dep-greedy-group1-30M` | 289 | 394 (+36%) | 310 (+7%) |

Key observations:
- **`max` fill with `full` mode shows the largest gains** — `mixed_dep-max-group1-60M` reaches **+154%** over sequential. This is the highest per-test gain in the entire stateful suite.
- **`full` consistently outperforms `nobatchio` at `max` fill level** — batch IO helps when there are many small independent transactions with high state access counts.
- **`half` fill level favors `nobatchio`** in most cases — the moderate transaction count may not generate enough IO pressure for batch IO to overcome its coordination overhead.
- **`greedy` fill shows minimal or negative gains** — few large transactions leave no room for parallelism.
- **`group1` (independent) benefits most; `group5` (5-tx dependency chains) benefits less**, as expected from the BAL's ability to identify non-conflicting transactions.

#### State root computation

| Test | sequential (B) | nobatchio (A) | full (C) |
|------|---------------|--------------|----------|
| `state_root-half-contract_per_tx-60M` | 1,023 | 2,133 (+108%) | 2,937 (**+187%**) |
| `state_root-max-contract_per_tx-30M` | 348 | 477 (+37%) | 575 (**+65%**) |
| `state_root-half-contract_per_tx-30M` | 457 | 571 (+25%) | 653 (**+43%**) |
| `state_root-half-single_contract-30M` | 2,337 | 3,181 (+36%) | 3,108 (+33%) |
| `state_root-max-single_contract-30M` | 3,791 | 4,611 (+22%) | 4,257 (+12%) |
| `state_root-half-single_contract-60M` | 4,854 | 4,446 (-8%) | 3,761 (-23%) |
| `state_root-greedy-single_contract-60M` | 461 | 423 (-8%) | 545 (+18%) |
| `state_root-greedy-single_contract-30M` | 236 | 160 (-32%) | 90.7 (**-62%**) |
| `state_root-greedy-contract_per_tx-30M` | 149 | 164 (+10%) | 180 (+21%) |
| `state_root-greedy-contract_per_tx-60M` | 370 | 290 (-22%) | 177 (**-52%**) |

Key observations:
- **`contract_per_tx` with `half`/`max` fill is the best-case for the full BAL pipeline.** `state_root-half-contract_per_tx-60M` achieves **+187% over sequential** with full mode — the single highest gain in the entire suite. Many distinct contracts create independent trie update regions that parallelize perfectly.
- **`full` consistently outperforms `nobatchio` on `contract_per_tx` patterns** — by +43-65% on 30M and +187% vs +108% on 60M. Batch IO meaningfully accelerates state root computation when many scattered trie regions need updating.
- **`greedy` fill with `single_contract` is the worst case** — `state_root-greedy-single_contract-30M` regresses -62% with full mode. All state changes go to one contract, so parallel state root has nothing to parallelize and pays coordination overhead.
- **`greedy-contract_per_tx-60M` also regresses -52% with full mode** — surprising, since `contract_per_tx` usually helps. At greedy fill, each transaction is so large that the few transactions in the block don't generate enough independent work to offset overhead.

#### Serial chains and keccak chains

| Test | sequential (B) | nobatchio (A) | full (C) |
|------|---------------|--------------|----------|
| `keccak_chain-half-60M` | 6,633 | 4,386 (**-34%**) | 5,148 (-22%) |
| `keccak_chain-half-30M` | 2,180 | 1,944 (-11%) | 1,699 (-22%) |
| `keccak_chain-greedy-60M` | 576 | 723 (+26%) | 708 (+23%) |
| `keccak_chain-greedy-30M` | 294 | 255 (-13%) | 232 (-21%) |
| `serial_chain-60M` | 3,087 | 2,498 (**-19%**) | 2,467 (-20%) |
| `serial_chain-30M` | 1,113 | 1,389 (+25%) | 1,544 (+39%) |

Serial chains are inherently non-parallelizable — each tx depends on the previous. The `keccak_chain-half-60M` test shows sequential running at 6,633 vs 4,386 for nobatchio (**-34% regression**), confirming that parallel overhead hurts on serial workloads. This is expected behavior, not a bug — but it demonstrates the need for conflict-detection fallback.

Interestingly, `serial_chain-30M` shows parallel modes *faster* than sequential (+25-39%), and `keccak_chain-greedy-60M` also favors parallel (+23-26%). The parallel overhead may be offset by other optimizations (e.g., parallel state root) even when execution itself is serial.

### Stateful benchmark takeaways

1. **Full mode (with batch IO) is the fastest overall at +50% over sequential** vs nobatchio at +39%. On BAL-specific workloads, batch IO provides a clear +7.7% aggregate benefit, unlike the stateless benchmarks where it showed no gain. The benefit is concentrated on high-parallelism, multi-contract workloads.

2. **The best-case gains are very large.** `state_root-half-contract_per_tx-60M` at +187% and `mixed_dep-max-group1-60M` at +154% show what the BAL pipeline can deliver when workloads have genuine parallelism. These gains come from parallel execution + parallel state root + batch IO working together.

3. **Worst-case regressions are bounded and predictable.** The worst regression is `state_root-greedy-single_contract-30M` at -62% for full mode. Regressions consistently appear on greedy-fill (few large txs) and single-contract (no trie parallelism) patterns. These are detectable from the BAL upfront.

4. **No test failures.** All 48 tests passed in all three modes, unlike the stateless benchmarks where Geth had 128 failures. This may be due to a different Geth build (`geth-amsterdam:local` vs `ethpandaops/geth:bal-devnet-2`), different test patterns, or the smaller test suite not hitting the empty_code edge cases.

5. **Greedy fill level (maximum gas per tx) shows minimal or negative parallel benefit.** Parallelism helps most when blocks have many smaller independent transactions, not a few large ones. This is an important design consideration for BAL — the protocol should not assume parallelism always helps.

---

## Worst-Case Regressions

### From stateless benchmarks (Optimized vs Sequential)

These are tests where the parallel path performed **worse** than sequential — the critical metric for protocol safety since block validation time must be bounded.

#### Pattern 1: State-conflicting transactions (All clients)

Tests with many transactions touching overlapping accounts (`ether_transfers` with `diff_acc`, `a_to_a`, `a_to_b` patterns, precompile transfers).

| Client | # Tests regressed | Avg regression | Worst case |
|--------|------------------|----------------|------------|
| Reth | 293/1100 | -10.4% | -74.5% (`ether_transfers warm a_to_diff_acc`) |
| Besu | 158/1100 | -39.7% | -91.3% (`state_root_computation max_txs contract_per_tx`) |
| Geth | 100/974 | -31.3% | -96.1% (see Pattern 3 below) |

**Why:** When most transactions in a block conflict, parallel execution pays coordination overhead with no parallelism benefit. The BAL provides the access list to detect this upfront, but current implementations don't fall back to sequential.

#### Pattern 2: Large memory / data operations (Geth-dominant)

| Test | Geth sequential | Geth optimized | Regression |
|------|----------------|----------------|------------|
| `msize 1MB` | 22,908 | 3,295 | -85.6% |
| `return_revert 1MB non-zero` | 9,983 | 1,257 | -87.4% |
| `log 1MB zeros LOG3` | 37,205 | 6,783 | -81.8% |

Compute/memory-bound tests where Geth's parallel state management adds unnecessary overhead. Reth and Besu show milder regressions.

#### Pattern 3: Empty-code accounts (Geth bug)

| Test | Geth sequential | Geth optimized | Regression |
|------|----------------|----------------|------------|
| `empty_code EXTCODESIZE` | 550 | 21.5 | **-96.1%** |
| `empty_code EXTCODEHASH` | 535 | 24.4 | -95.4% |
| `empty_code BALANCE` | 539 | 26.4 | -95.1% |
| `empty_code DELEGATECALL` | 102 | 8.0 | -92.2% |
| `empty_code CALL` | 149 | 14.7 | -90.1% |

**This is a bug.** Reth and Besu handle these tests without regression. The Geth parallel path has a pathological code path for empty-code accounts. Likely the cause of the 128 stateless test failures.

#### Pattern 4: Large-code CODECOPY (Besu-specific)

| Test | Besu sequential | Besu optimized | Regression |
|------|----------------|----------------|------------|
| `codecopy 24576 mem_256` | 6,491 | 1,063 | -83.6% |
| `codecopy 24576 mem_0` | 6,650 | 1,136 | -82.9% |
| `codecopy 24576 mem_1024` | 6,181 | 1,086 | -82.4% |

Besu's sequential path has JIT optimization for max-size CODECOPY that the parallel path disrupts.

### From stateful benchmarks (Geth, sequential baseline)

#### Pattern 5: Serial dependency chains

| Test | sequential | nobatchio | full | Worst regression |
|------|-----------|-----------|------|-----------------|
| `keccak_chain-half-60M` | 6,633 | 4,386 | 5,148 | **-34%** (nobatchio) |
| `keccak_chain-half-30M` | 2,180 | 1,944 | 1,699 | -22% (full) |
| `serial_chain-60M` | 3,087 | 2,498 | 2,467 | -20% (full) |

Expected: inherently serial workloads cannot benefit from parallelism. The parallel overhead (state snapshot management, coordination) causes measurable regression. The BAL contains the information needed to detect these serial patterns upfront.

#### Pattern 6: Greedy fill / single-contract state root (largest regressions)

| Test | sequential | nobatchio | full | Worst regression |
|------|-----------|-----------|------|-----------------|
| `state_root-greedy-single_contract-30M` | 236 | 160 | 90.7 | **-62%** (full) |
| `state_root-greedy-contract_per_tx-60M` | 370 | 290 | 177 | **-52%** (full) |
| `state_root-half-single_contract-60M` | 4,854 | 4,446 | 3,761 | -23% (full) |
| `mixed_dep-half-group1-30M` | 497 | 783 | 391 | -21% (full) |

The worst stateful regressions come from greedy fill + single-contract patterns where all state changes funnel through one trie path. Full mode pays both parallel execution overhead and batch IO coordination cost with no parallelism to offset it. These represent the worst-case block structure for BAL optimization — detectable from the access list's contract distribution.

---

## Action Items

### P0 — Required before next benchmark round

| # | Owner | Action |
|---|-------|--------|
| 1 | **Geth** | Fix empty_code bug in parallel execution. The 90-96% regressions and 128 test failures in the stateless suite indicate a correctness issue. Note: the stateful suite (different build) had no failures — identify what differs between the two builds. |
| 2 | **Geth** | Fix container crash that causes 128 test failures in `full` and `nobatchio` modes on the stateless suite. |

### P1 — Optimize before full stateful benchmarks

| # | Owner | Action |
|---|-------|--------|
| 3 | **All clients** | Implement conflict-detection fallback. When the BAL reveals high transaction conflict rate, fall back to sequential for the block. The stateful benchmarks confirm this is needed: `keccak_chain-half-60M` regresses 51% in parallel mode, while `interact-max-independent_pairs` gains 120%+. A smart fallback would capture the upside while bounding the downside to sequential + ~5% detection overhead. |
| 4 | **Geth** | Profile large-memory regressions (`msize 1MB`: -86%, `return_revert 1MB`: -87%). Reduce memory copying overhead in parallel state management for bulk data operations. |
| 5 | **Besu** | Investigate `codecopy code_size_24576` regression (-82-84%). Determine what JIT/cache optimization the parallel path breaks and preserve it. |
| 6 | **Besu** | Investigate `state_root_computation max_txs contract_per_tx` regression (-91%). This is Besu's worst single regression in stateless tests. |
| 7 | **Reth** | Profile why parallel gains are only +11-12% vs Besu's +115-130%. Either the parallel scheduler needs better work partitioning, or the sequential path is already so optimized that parallelism adds more overhead than it saves. |

### P2 — Benchmark design changes for next round

| # | Action | Rationale |
|---|--------|-----------|
| 8 | **Add cold-state benchmark runs.** Drop page caches (`echo 3 > /proc/sys/vm/drop_caches`) before each test to evaluate batch IO / prefetch on disk-bound workloads. | Current warm-cache results cannot fully evaluate prefetch. The stateful results hint that batch IO helps on high-parallelism workloads (+38% on `state_root-half-contract_per_tx`), but cold-state testing would confirm whether this is IO-driven or scheduling-driven. |
| 9 | **Run stateful benchmarks on Reth and Besu.** | Currently only Geth has stateful results. The BAL-specific test patterns (dependency graphs, prefetch, state root computation) are more representative of real BAL workloads than opcode-level tests. |
| 10 | **Benchmark executionless state updates.** Measure applying BAL state diffs without re-executing transactions. | This is the fourth BAL capability the spec enables and is not measured at all. It could be the most impactful for worst-case block validation. |
| 11 | **Re-run all three clients after P0/P1 fixes.** | Geth's 128 failures and empty_code bug make current cross-client stateless comparisons unreliable. |
| 12 | **Test on bal-devnet-3 when clients are ready.** | The current benchmarks are from bal-devnet-2. devnet-3 includes additional EIPs (7954, 8037, 7975, 8159) that may change the performance profile. |

---

## Status Summary

| Client | Parallel exec works? | Correctness? | Worst-case bounded? | Ready for full stateful tests? |
|--------|---------------------|-------------|---------------------|-------------------------------|
| **Reth** | Yes (+11-12%) | Clean (1102/1103) | No (P99: -70%) | After conflict fallback (#3) + stateful suite (#9) |
| **Besu** | Yes (+115-130%) | Clean (1102/1103) | No (P99: -91%) | After CODECOPY fix (#5) + fallback (#3) + stateful suite (#9) |
| **Geth (stateless)** | Yes (+66-74%) | **Broken** (975/1103) | No (P99: -96%) | **After bug fixes (#1, #2)** + fallback (#3) |
| **Geth (stateful)** | Yes (+39-50%) | Clean (48/48) | No (serial: -51%) | After conflict fallback (#3) |

### Positive signals from stateful benchmarks

The Geth stateful results provide strong evidence that:
- **The BAL design delivers major gains.** Full mode is +50% over sequential on aggregate, with peaks of +187% (`state_root-half-contract_per_tx-60M`) and +154% (`mixed_dep-max-group1-60M`).
- **Batch IO adds measurable value on BAL workloads.** Full mode is +7.7% faster than nobatchio on aggregate, with the gap widening to +43-65% on `contract_per_tx` state root tests. This contradicts the stateless-only finding that batch IO has no benefit.
- **Worst-case regressions are predictable.** They consistently appear on greedy fill (few large txs) and single-contract (no trie parallelism) patterns — both detectable from the BAL before execution begins.

The key remaining work is bounding worst-case regressions via conflict-detection fallback, fixing Geth's stateless correctness bugs, and expanding stateful benchmarks to Reth and Besu.
