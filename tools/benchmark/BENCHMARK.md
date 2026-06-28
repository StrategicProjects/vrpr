# Parity benchmark — vrpr vs PyVRP

Validates that `vrpr` (the R port of PyVRP via cpp11) is faithful to the
Python/C++ reference, along two axes: **objective correctness** and **solution
quality**.

## How to reproduce

```sh
# 1. PyVRP in a venv (the reference side)
python3 -m venv /tmp/vrpr_bench && /tmp/vrpr_bench/bin/pip install pyvrp

# 2. install vrpr (a RELEASE build — see the caveat below)
R CMD INSTALL .

# 3. run the driver (downloads the X-set instance if absent)
VRPR_PYVRP_PYTHON=/tmp/vrpr_bench/bin/python \
  Rscript tools/benchmark/parity.R X-n101-k25 10 1
```

> ⚠️ **Always measure the RELEASE build** (`R CMD INSTALL`), not the debug build of
> `devtools::load_all()`. The debug build compiles without `-O2` and with the
> core's `assert()`s active (no `-DNDEBUG`), making it ~20x slower — which
> completely distorts any throughput comparison.

## Part A — objective parity (exact, deterministic)

The same instance and the **same solution** (same routes), evaluated on both
sides. Since `vrpr` and PyVRP share the same C++ core (`CostEvaluator`,
`Solution`), the cost **must** match bit for bit.

Instance `sample-n6-k2`, routes `[[1,2],[3,4,5]]`:

| | feasible | distance | cost |
|---|---|---|---|
| PyVRP | true | 81 | 81 |
| vrpr  | true | 81 | 81 |

✅ Identical. Validates the data model, the distance computation (EUC_2D
round-half-up) and the objective function.

## Part B — quality parity

Instance `X-n101-k25` (100 clients, known optimum **27591**), 10 s per solver,
release build:

| Solver | cost | gap to optimum | iterations (10s) |
|---|---|---|---|
| PyVRP | 27591 | 0.00 % | ~18,000 |
| vrpr  | 27591 | 0.00 % | ~24,000 |

✅ Both reach the **optimum** in 10 s. `vrpr`'s throughput is the same order of
magnitude as PyVRP's (here even slightly higher) — the R ILS loop is not a
bottleneck in the release build. Across seeds, `vrpr` stays within 0.00–0.1 % of
the optimum.

## Why there is parity

`vrpr` vendors PyVRP's C++ core and rewires it with cpp11; the R ILS loop is a
**faithful port** of `IteratedLocalSearch.py`: Late Acceptance Hill-Climbing
(Burke & Bykov, 2017) + restart after stagnation + an exhaustive search on each
new best, with the same default parameters (`history_length = 300`). The heavy
work (local search, cost evaluation) runs in the same C++; the R orchestration
adds a per-iteration overhead that, in the release build, is small relative to
the cost of local search.

## Notes

- The number of vehicles is fixed generously (30 > k=25); since the CVRP minimises
  distance only (no fixed vehicle cost), idle vehicles do not change the optimum.
- The distance matrix is Euclidean with round-half-up (`floor(d + 0.5)`) on both
  sides, the TSPLIB EUC_2D convention — required to reproduce the BKS 27591.
