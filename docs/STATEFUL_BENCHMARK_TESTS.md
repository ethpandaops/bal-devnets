# BAL Stateful Benchmark Test Descriptions

This document describes each test in the BAL stateful benchmark suite. Unlike the stateless (opcode-level) benchmarks that stress individual EVM operations, these tests construct blocks with specific transaction dependency patterns designed to evaluate how well clients exploit the Block-Level Access List (EIP-7928) for parallel execution, parallel state root computation, and batch IO.

---

## Common Parameters

Every test name follows the pattern: `{category}-{fill_level}-{variant}-{gas_limit}M`

### Fill Levels

The fill level controls how many transactions are packed into the block and how large each transaction is. This is the most important parameter for understanding parallelism potential.

| Fill Level | Description | Parallelism Potential |
|-----------|-------------|----------------------|
| **greedy** | Few transactions, each consuming maximum gas. Blocks are filled with 1-3 very large transactions. | **Low** — few transactions means few opportunities for parallel execution. Worst case for parallelism. |
| **half** | Moderate number of medium-sized transactions. Each transaction uses roughly half the per-tx gas budget. | **Medium** — enough transactions to find some parallelism, but not saturated. |
| **max** | Many small transactions filling the block to capacity. Each transaction uses minimal gas. | **High** — maximum number of independent work units. Best case for parallelism. |

### Gas Limits

| Gas Limit | Description |
|-----------|-------------|
| **30M** | 30 million gas block limit. Current Ethereum mainnet equivalent. Tests behavior at today's gas target. |
| **60M** | 60 million gas block limit. Tests behavior at elevated gas (e.g., post-EIP-7928 target or burst). Doubles the work per block, amplifying both gains and regressions. |

The 60M tests generally show larger percentage differences between modes because there is more work to parallelize (or more overhead to pay).

---

## Test Categories

### 1. `interact` — Transaction Interaction Patterns (12 tests)

These tests construct blocks where transactions interact with accounts in controlled patterns, testing how well the parallel executor handles different access conflict structures.

#### `interact-{fill}-independent_pairs-{gas}M`

**What it tests:** Blocks filled with transaction pairs that each operate on a unique pair of accounts. No two pairs share any accounts — this is the **ideal case for parallel execution**.

**Block structure:** If the block has N transactions, they form N/2 independent pairs. Pair 1 touches accounts (A1, B1), pair 2 touches (A2, B2), etc. The BAL reveals zero cross-pair conflicts.

**Expected behavior:**
- Sequential: processes all transactions one by one
- Parallel: can execute all pairs simultaneously (limited only by CPU cores)
- Batch IO: can prefetch all account states in one batch before execution

**Why it matters:** This is the theoretical upper bound for BAL parallelism. If a client doesn't show major gains here, its parallel executor has fundamental issues.

| Test | Fill | Gas |
|------|------|-----|
| `interact-greedy-independent_pairs-30M` | greedy | 30M |
| `interact-greedy-independent_pairs-60M` | greedy | 60M |
| `interact-half-independent_pairs-30M` | half | 30M |
| `interact-half-independent_pairs-60M` | half | 60M |
| `interact-max-independent_pairs-30M` | max | 30M |
| `interact-max-independent_pairs-60M` | max | 60M |

---

#### `interact-{fill}-single_contract-{gas}M`

**What it tests:** Blocks filled with transactions that all call the **same contract**. Every transaction conflicts with every other transaction on at least one account (the shared contract). This is the **worst case for parallel execution** among interact tests.

**Block structure:** All N transactions call a single contract address. The BAL reveals that every transaction touches the same account, creating a fully serial dependency chain from the parallel executor's perspective.

**Expected behavior:**
- Sequential: native execution path, no overhead
- Parallel: must serialize all transactions due to conflicts, pays coordination overhead for zero benefit
- Batch IO: can still prefetch the single contract's state, but the benefit is minimal since it's one account

**Why it matters:** This represents common real-world patterns like DEX router contracts (Uniswap), token transfers through a single ERC-20, or popular NFT mints. The parallel executor must detect this pattern and minimize overhead.

| Test | Fill | Gas |
|------|------|-----|
| `interact-greedy-single_contract-30M` | greedy | 30M |
| `interact-greedy-single_contract-60M` | greedy | 60M |
| `interact-half-single_contract-30M` | half | 30M |
| `interact-half-single_contract-60M` | half | 60M |
| `interact-max-single_contract-30M` | max | 30M |
| `interact-max-single_contract-60M` | max | 60M |

---

### 2. `mixed_dep` — Mixed Dependency Graphs (18 tests)

These tests construct blocks with a controlled mix of independent and dependent transactions, forming dependency groups of specified sizes. This is the most realistic category — real blocks have a mix of conflicting and non-conflicting transactions.

#### `mixed_dep-{fill}-group{N}-{gas}M`

**What it tests:** Blocks where transactions are organized into dependency groups of size N. Within each group, transactions are dependent (serial). Across groups, transactions are independent (parallel).

**Group size parameter:**
- **group1**: Every transaction is independent — equivalent to `independent_pairs` but with single-tx groups. Maximum parallelism.
- **group2**: Transactions form pairs where each pair must execute sequentially, but pairs are independent of each other. 50% serial, 50% parallel.
- **group5**: Transactions form chains of 5. Within each chain, strict serial order. Chains are independent. More serial pressure.

**Block structure:** If the block has 20 transactions with `group5`, it forms 4 independent chains of 5. The BAL reveals the 4 groups, allowing parallel execution across groups while maintaining order within each group.

**Expected behavior:**
- Sequential: processes all transactions one by one, ignoring the group structure
- Parallel: executes independent groups in parallel, serializes within groups. Speedup scales with `num_groups / max_group_size`.
- Batch IO: prefetches state for all groups simultaneously

**Why it matters:** This is the closest approximation to real block structure. Most Ethereum blocks have clusters of related transactions (e.g., MEV bundles, multiple swaps on the same pool) interspersed with independent transfers. The group size parameter lets us measure how parallel gains scale with dependency density.

| Test | Fill | Groups | Gas |
|------|------|--------|-----|
| `mixed_dep-greedy-group1-30M` | greedy | 1 (independent) | 30M |
| `mixed_dep-greedy-group1-60M` | greedy | 1 (independent) | 60M |
| `mixed_dep-greedy-group2-30M` | greedy | 2 | 30M |
| `mixed_dep-greedy-group2-60M` | greedy | 2 | 60M |
| `mixed_dep-greedy-group5-30M` | greedy | 5 | 30M |
| `mixed_dep-greedy-group5-60M` | greedy | 5 | 60M |
| `mixed_dep-half-group1-30M` | half | 1 (independent) | 30M |
| `mixed_dep-half-group1-60M` | half | 1 (independent) | 60M |
| `mixed_dep-half-group2-30M` | half | 2 | 30M |
| `mixed_dep-half-group2-60M` | half | 2 | 60M |
| `mixed_dep-half-group5-30M` | half | 5 | 30M |
| `mixed_dep-half-group5-60M` | half | 5 | 60M |
| `mixed_dep-max-group1-30M` | max | 1 (independent) | 30M |
| `mixed_dep-max-group1-60M` | max | 1 (independent) | 60M |
| `mixed_dep-max-group2-30M` | max | 2 | 30M |
| `mixed_dep-max-group2-60M` | max | 2 | 60M |
| `mixed_dep-max-group5-30M` | max | 5 | 30M |
| `mixed_dep-max-group5-60M` | max | 5 | 60M |

**Note:** `mixed_dep-greedy-group5-30M` and `mixed_dep-greedy-group5-60M` produced no results in the benchmark run. With greedy fill, the block may not have enough transactions to form groups of 5 (greedy fill produces very few large transactions).

---

### 3. `keccak_chain` — Keccak Hash Chain Tests (4 tests)

#### `keccak_chain-{fill}-{gas}M`

**What it tests:** Blocks where each transaction computes a keccak256 hash chain, and each subsequent transaction's input depends on the previous transaction's output hash. This creates a **strict sequential dependency** — transaction N cannot begin until transaction N-1 completes.

**Block structure:** Transaction 1 hashes input X to get H1. Transaction 2 hashes H1 to get H2. Transaction 3 hashes H2 to get H3, etc. The BAL reveals a fully linear dependency chain.

**Expected behavior:**
- Sequential: native execution, no wasted work
- Parallel: **must fall back to sequential** since every transaction depends on the previous. Any parallel overhead is pure waste.
- Batch IO: can prefetch the initial state, but state changes propagate sequentially so prefetch has limited value

**Why it matters:** This is the **adversarial worst case for parallelism** — a block intentionally structured so zero parallelism is possible. It measures the overhead floor of the parallel execution infrastructure. A good implementation should detect the fully serial chain from the BAL and skip parallel scheduling entirely.

| Test | Fill | Gas |
|------|------|-----|
| `keccak_chain-greedy-30M` | greedy | 30M |
| `keccak_chain-greedy-60M` | greedy | 60M |
| `keccak_chain-half-30M` | half | 30M |
| `keccak_chain-half-60M` | half | 60M |

---

### 4. `serial_chain` — Serial Transaction Chains (2 tests)

#### `serial_chain-{gas}M`

**What it tests:** Similar to `keccak_chain` but with generic serial dependencies (not hash-chain-specific). Transactions are chained so that each modifies state that the next transaction reads.

**Block structure:** Transaction 1 writes to storage slot S. Transaction 2 reads S and writes to S'. Transaction 3 reads S' and writes to S''. The BAL reveals a linear dependency chain through shared storage slots.

**Expected behavior:**
- Sequential: processes naturally in order
- Parallel: must serialize due to read-after-write dependencies
- Batch IO: prefetches initial state, but each step depends on the previous write

**Why it matters:** While `keccak_chain` tests computational dependency, `serial_chain` tests **state dependency** — the more common real-world pattern (e.g., a sequence of DEX swaps that each change a pool's reserves that the next swap reads).

| Test | Gas |
|------|-----|
| `serial_chain-30M` | 30M |
| `serial_chain-60M` | 60M |

---

### 5. `prefetch` — State Prefetch Tests (2 tests)

#### `prefetch-{gas}M`

**What it tests:** Blocks designed to maximize the benefit of batch IO / state prefetching. Transactions access many distinct storage slots and accounts that are **cold** (not recently cached), but the transactions themselves are independent.

**Block structure:** Many independent transactions, each touching a unique set of storage slots across multiple contracts. The BAL reveals all accessed slots upfront, enabling the client to batch all disk reads before execution begins.

**Expected behavior:**
- Sequential: each transaction triggers cold storage reads one at a time, serializing IO
- Parallel: can execute transactions concurrently since they're independent
- Batch IO: **should show maximum benefit here** — reads all required state in one batched IO operation before any transaction executes, eliminating IO wait during execution

**Why it matters:** This directly tests the EIP-7928 motivation of "parallel disk reads." If batch IO doesn't help on these tests, it won't help anywhere. Under warm cache (as in the current benchmarks), the benefit may be muted since there's no actual disk IO to batch. **Cold-state reruns of this test are critical** for evaluating the prefetch value proposition.

| Test | Gas |
|------|-----|
| `prefetch-30M` | 30M |
| `prefetch-60M` | 60M |

---

### 6. `state_root` — State Root Computation Tests (10 tests)

These tests are designed to stress **parallel state root computation** — the BAL capability that allows the post-execution trie update to be parallelized across independent trie regions.

#### `state_root-{fill}-contract_per_tx-{gas}M`

**What it tests:** Blocks where each transaction deploys or modifies a **unique contract**. The state changes are spread across many independent trie paths (one per contract address), enabling maximum parallelism in the state root computation phase.

**Block structure:** Transaction 1 modifies contract C1, transaction 2 modifies C2, etc. Each contract occupies a different branch of the state trie. The BAL reveals that trie updates can be partitioned by contract.

**Expected behavior:**
- Sequential: updates the trie one account at a time
- Parallel execution: transactions are independent, can run concurrently
- Parallel state root: **should show maximum benefit** — each trie branch can be updated independently
- Batch IO: prefetches all contract states in one batch

**Why it matters:** This is the best-case scenario for parallel state root computation. The post-execution phase (computing the new state root) is often the bottleneck, especially at high gas limits. If parallel state root doesn't show large gains here, the implementation has issues.

| Test | Fill | Gas |
|------|------|-----|
| `state_root-greedy-contract_per_tx-30M` | greedy | 30M |
| `state_root-greedy-contract_per_tx-60M` | greedy | 60M |
| `state_root-half-contract_per_tx-30M` | half | 30M |
| `state_root-half-contract_per_tx-60M` | half | 60M |
| `state_root-max-contract_per_tx-30M` | max | 30M |

---

#### `state_root-{fill}-single_contract-{gas}M`

**What it tests:** Blocks where all transactions modify the **same contract's storage**. All state changes funnel through a single trie path, making parallel state root computation impossible.

**Block structure:** All N transactions write to different storage slots of the same contract address. The BAL reveals that while storage slots differ, they all belong to one account — the account trie node and the storage trie root must be updated sequentially.

**Expected behavior:**
- Sequential: natural execution path
- Parallel execution: transactions may conflict on the account's nonce/balance, limiting parallelism
- Parallel state root: **no benefit** — all updates go through one trie path. Coordination overhead is pure waste.
- Batch IO: prefetches the single contract's storage, minimal benefit

**Why it matters:** This is the **worst case for parallel state root** and a common real-world pattern (e.g., a popular DeFi protocol where all interactions modify the same contract's storage). Together with `contract_per_tx`, it brackets the range of parallel state root performance.

| Test | Fill | Gas |
|------|------|-----|
| `state_root-greedy-single_contract-30M` | greedy | 30M |
| `state_root-greedy-single_contract-60M` | greedy | 60M |
| `state_root-half-single_contract-30M` | half | 30M |
| `state_root-half-single_contract-60M` | half | 60M |
| `state_root-max-single_contract-30M` | max | 30M |

---

## Test Matrix Summary

| Category | Tests | What it measures | Best case for BAL | Worst case for BAL |
|----------|-------|-----------------|-------------------|-------------------|
| `interact` | 12 | Parallel execution with controlled conflicts | `max-independent_pairs` | `greedy-single_contract` |
| `mixed_dep` | 18 | Realistic mixed dependency patterns | `max-group1` | `greedy-group5` |
| `keccak_chain` | 4 | Overhead on fully serial compute chains | N/A (always serial) | `half-60M` (most overhead) |
| `serial_chain` | 2 | Overhead on fully serial state chains | N/A (always serial) | `60M` |
| `prefetch` | 2 | Batch IO / state prefetch benefit | `60M` with cold state | Warm cache (no IO to batch) |
| `state_root` | 10 | Parallel state root computation | `half/max-contract_per_tx` | `greedy-single_contract` |
| **Total** | **48** | | | |

---

## How to Read Results

When comparing execution modes on these tests:

1. **Sequential vs Parallel (nobatchio):** Isolates the value of parallel execution + parallel state root, without batch IO. Gains come from concurrent transaction processing and concurrent trie updates.

2. **Sequential vs Full:** Shows the complete BAL pipeline benefit: parallel execution + parallel state root + batch IO. This is what a production BAL implementation would deliver.

3. **nobatchio vs Full:** Isolates the batch IO component. Differences come solely from whether state is prefetched in a batch before execution or read on-demand during execution.

4. **Fill level scaling:** Compare the same test across greedy/half/max to understand how parallelism scales with transaction count. Greedy (few large txs) should show minimal gains; max (many small txs) should show maximum gains.

5. **Gas limit scaling:** Compare 30M vs 60M variants to understand how gains scale with block size. Larger blocks generally amplify both gains and regressions.

6. **Group size scaling (mixed_dep):** Compare group1/group2/group5 at the same fill level to understand how dependency density affects parallelism. group1 (fully independent) should always outperform group5 (chains of 5).
