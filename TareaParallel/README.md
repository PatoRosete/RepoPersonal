# Parallel Programming — Exercises 1 & 2

**Author:** Carlos Enrique Rosete Pascual
**Date:** 2026-06-01

---

## Files

```
TareaParallel/
├── excersise1facbin.c     # Exercise 1 in C (sequential + parallel)
├── excersise2primesum.c   # Exercise 2 in C (sequential + parallel)
├── ex1.exs                # Exercise 1 in Elixir (sequential + parallel)
├── ex2.exs                # Exercise 2 in Elixir (sequential + parallel)
└── Makefile               # Compiles all C programs
```

---

## How to compile

The Makefile compiles all C programs at once. Just run:

```bash
make
```

To remove compiled files:

```bash
make clean
```

> The Elixir files (`.exs`) do not need compilation — they run directly inside `iex`.

---

## How to run

### Exercise 1 — Bits set to 1 in n!

**C:**
```bash
./excersise1facbin <n> <threads>

# Examples:
./excersise1facbin 10 2
./excersise1facbin 10 4
```

**Elixir (iex):**
```elixir
iex> c("ex1.exs")
iex> Ex1.factorial_bits(10)
iex> Ex1.parallel_factorial_bits(10, 4)
```

### Exercise 2 — Sum of prime numbers ≤ n

**C:**
```bash
./excersise2primesum <n> <threads>

# Examples:
./excersise2primesum 1000000 4
./excersise2primesum 1000000 8
```

**Elixir (iex):**
```elixir
iex> c("ex2.exs")
iex> Ex2.sum_primes(1000000)
iex> Ex2.parallel_sum_primes(1000000, 4)
```

Each program runs both the parallel and sequential versions automatically and prints the results, wall time, and CPU time for both.

---

## Time measurement

Both C and Elixir measure two types of time:

- **Wall time** — real elapsed time from start to finish (`CLOCK_REALTIME` in C, `:timer.tc` in Elixir). This is the time used to compute speedup.
- **CPU time** — total CPU time consumed across all cores (`CLOCK_PROCESS_CPUTIME_ID` in C). In parallel runs this can exceed wall time because multiple cores contribute CPU time simultaneously, so all their times get added together.

---

## Parallelization approach

### Exercise 1 — Factorial bits

The factorial `n! = 1 × 2 × 3 × ... × n` is a single long chain of multiplications. To parallelize it, the range `[1, n]` is split into equal sub-ranges, one per thread/task. Each thread multiplies the numbers in its own sub-range independently, producing a partial product. Once all threads finish, the partial products are multiplied together to get the final factorial. The bit count is then applied to the result.

For example, with `n=10` and 3 threads:
- Thread 0: `1 × 2 × 3 = 6`
- Thread 1: `4 × 5 × 6 = 120`
- Thread 2: `7 × 8 × 9 × 10 = 5040`
- Final: `6 × 120 × 5040 = 3628800 = 10!`

In C, a `pthread_mutex_t` protects the shared accumulator when each thread writes its partial product. In Elixir, `Task.async/await` is used and the partial results are combined with `Enum.product/1` — no mutex needed since each task returns its value independently.

### Exercise 2 — Sum of primes

Checking whether a number is prime is an independent operation — whether `x` is prime has no relation to whether `y` is prime. This makes the problem embarrassingly parallel. The range `[2, n]` is split into equal sub-ranges, one per thread/task. Each thread checks every number in its range and accumulates a local sum. When done, the local sums are added to a shared total.

In C, a `pthread_mutex_t` protects the shared total. In Elixir, each task returns its partial sum and they are combined with `Enum.sum/1`.

The primality check uses trial division up to `√x` (implemented as `i * i <= x` to avoid floating point), which matches the algorithm specified in the exercise.

---

## Speedup evaluation

Speedup is computed as:

```
Sp = T1 / Tp
```

Where `T1` is the sequential wall time and `Tp` is the parallel wall time with `p` threads/tasks.

---

### Exercise 1 — C results (`n = 10`)

| Threads (p) | Sequential T1 (s) | Parallel Tp (s) | Speedup Sp |
|:-----------:|:-----------------:|:---------------:|:----------:|
| 2           | 0.000002          | 0.002754        | 0.001×     |
| 3           | 0.000001          | 0.001844        | 0.001×     |
| 6           | 0.000002          | 0.002700        | 0.001×     |
| 8           | 0.000002          | 0.005154        | 0.0004×    |

### Exercise 1 — Elixir results (`n = 10`)

| Tasks (p) | Sequential T1 (s) | Parallel Tp (s) | Speedup Sp |
|:---------:|:-----------------:|:---------------:|:----------:|
| 4         | 0.000083          | 0.000672        | 0.12×      |

**Analysis:** Exercise 1 shows no speedup at any thread count, in either language. This is expected — `n=10` means only 10 multiplications total, which takes nanoseconds. The overhead of creating threads/tasks, scheduling them, and synchronizing the shared result is orders of magnitude larger than the actual work. This is a known limitation of parallelism: it only pays off when the computation is large enough to outweigh the overhead. For this exercise, a value like `n=100000` or larger would be needed to see meaningful speedup.

---

### Exercise 2 — C results (`n = 20`)

| Threads (p) | Sequential T1 (s) | Parallel Tp (s) | Speedup Sp |
|:-----------:|:-----------------:|:---------------:|:----------:|
| 4           | 0.000003          | 0.001505        | 0.002×     |
| 8           | 0.000003          | 0.005188        | 0.001×     |
| 10          | 0.000002          | 0.004932        | 0.0004×    |

### Exercise 2 — Elixir results (`n = 1,000,000`)

| Tasks (p) | Sequential T1 (s) | Parallel Tp (s) | Speedup Sp |
|:---------:|:-----------------:|:---------------:|:----------:|
| 4         | 0.804848          | 0.367446        | **2.19×**  |

**Analysis:** Exercise 2 shows a clear contrast between the two input sizes. With `n=20` in C, the result is the same as Exercise 1 — the input is too small and thread overhead dominates. With `n=1,000,000` in Elixir, the computation is heavy enough to stress the CPU and the parallel version achieves a real speedup of **2.19×** using 4 schedulers. This is a reasonable result for 4 cores — linear speedup would be 4×, but in practice Amdahl's Law limits the gain because a small sequential portion always remains (splitting ranges, combining results). The Elixir BEAM scheduler also adds some overhead compared to raw pthreads, but handles load balancing automatically across all available cores.

---

## Conclusion

| Exercise | Language | Input    | Threads/Tasks | Speedup  |
|:--------:|:--------:|:--------:|:-------------:|:--------:|
| 1        | C        | n=10     | 2–8           | < 1× (overhead dominates) |
| 1        | Elixir   | n=10     | 4             | < 1× (overhead dominates) |
| 2        | C        | n=20     | 4–10          | < 1× (overhead dominates) |
| 2        | Elixir   | n=1M     | 4             | **2.19×** |

The key takeaway is that parallelism only provides a benefit when the workload per thread is large enough to outweigh the cost of thread creation and synchronization. Exercise 2 with a large `n` is a good example of a problem that parallelizes well because primality checking is an embarrassingly parallel task with no dependencies between numbers.