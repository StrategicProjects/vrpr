# Changelog

## vrpr 0.1.0

First release.

- A tidy, pipe-friendly R interface to the ‘PyVRP’ vehicle routing
  solver. PyVRP’s high-performance C++ core is vendored and rewired
  through ‘cpp11’, with no ‘Python’ runtime dependency.
- Supports the capacitated VRP, time windows (VRPTW), heterogeneous
  fleets, multiple depots (MDVRP), prize-collecting (optional clients
  and mutually exclusive client groups), simultaneous pickup and
  delivery / backhaul, and multi-trip routes.
- [`read_vrplib()`](https://strategicprojects.github.io/vrpr/reference/read_vrplib.md)
  and
  [`read_solomon()`](https://strategicprojects.github.io/vrpr/reference/read_solomon.md)
  read standard VRPLIB/TSPLIB and Solomon instances;
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws
  solutions with ‘ggplot2’.
- The solver is a faithful port of PyVRP’s iterated local search;
  objective and solution-quality parity with PyVRP is verified in
  `tools/benchmark/`.
