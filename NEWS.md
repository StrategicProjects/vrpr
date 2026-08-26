# vrpr 0.2.0

Upgrades the vendored solver core to **PyVRP 0.14.0** (from 0.13.4), a major
upstream release that reworks the data model and the search engine.

## New features

* **Pickup and delivery (shipments)**: `add_shipments()` adds paired
  pickup/delivery visits (same vehicle, pickup first, same trip), enabling the
  PDP/PDPTW family of problems. Solutions report `num_shipments` and
  `num_missing_shipments`.
* New `unplanned()` accessor: a tidy view of the optional clients and
  shipments left out of the solution (prize collecting).
* `routes()` now also reports `activity` (`"client"`, `"pickup"` or
  `"delivery"`), `shipment` and `trip` columns; client rows keep the previous
  columns, so pure client instances read as before.

## Upstream changes tracked

* The search engine follows PyVRP 0.14's design: a single operator family
  (`Relocate`/`Swap` plus explicit optional-client/shipment/group operators)
  replaces the old node/route operator split; the granular neighbourhood is
  now computed by upstream C++ code (default `num_neighbours = 50`).
* The penalty manager follows PyVRP 0.14: midpoint initial penalties,
  violation-magnitude registration, update every 500 solutions and
  `penalty_decrease = 0.90`. The `init_load`/`init_tw`/`init_dist` arguments
  of `ils_params()` were removed accordingly.
* Internally, routes are sequences of typed activities; reload depots (multi
  trip) appear as depot activities inside the route.

## Breaking changes

* `ils_params()` lost `init_load`, `init_tw` and `init_dist` (see above);
  `num_neighbours` now defaults to 50 (PyVRP's default).
* `routes()` gains columns; code that relied on the exact column set should
  select explicitly.

# vrpr 0.1.1

Portability fixes for CRAN builders; no user-facing changes.

* Fixed compilation with LLVM 23's libc++ (CRAN's clang23 additional checks),
  which no longer provides `std::back_inserter` transitively: the vendored
  `search/LocalSearch.cpp` and `Solution.cpp` now include `<iterator>`
  explicitly.
* Fixed compilation on the CRAN macOS builders that use Apple's MacOSX11.3 SDK
  (r-release-macos-x86_64 and r-oldrel-macos), whose libc++ `<concepts>` lacks
  `std::convertible_to`: a small compatibility shim (`vrpr_compat.h`) supplies
  the concept where the standard library does not.
* `Route::Iterator` in the vendored sources now declares all five iterator
  member typedefs, as required by pre-C++20 `std::iterator_traits` on the same
  older libc++ (verified by compiling every translation unit against the
  MacOSX11.3 SDK's libc++ headers).
* These fixups are applied by `tools/vendor.R` on top of the verbatim PyVRP
  sources, so they survive re-vendoring.

# vrpr 0.1.0

First release.

* A tidy, pipe-friendly R interface to the 'PyVRP' vehicle routing solver. PyVRP's
  high-performance C++ core is vendored and rewired through 'cpp11', with no
  'Python' runtime dependency.
* Supports the capacitated VRP, time windows (VRPTW), heterogeneous fleets,
  multiple depots (MDVRP), prize-collecting (optional clients and mutually
  exclusive client groups), simultaneous pickup and delivery / backhaul, and
  multi-trip routes.
* `read_vrplib()` and `read_solomon()` read standard VRPLIB/TSPLIB and Solomon
  instances; `plot()` draws solutions with 'ggplot2'.
* The solver is a faithful port of PyVRP's iterated local search; objective and
  solution-quality parity with PyVRP is verified in `tools/benchmark/`.
