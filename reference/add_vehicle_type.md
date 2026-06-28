# Add a vehicle type to the model

Add a vehicle type to the model

## Usage

``` r
add_vehicle_type(
  model,
  num_available,
  capacity,
  fixed_cost = 0,
  tw_early = 0,
  tw_late = Inf,
  max_duration = Inf,
  unit_distance_cost = 1,
  unit_duration_cost = 0,
  depot = 1L,
  start_depot = depot,
  end_depot = depot,
  reload_depots = integer(0),
  max_reloads = Inf
)
```

## Arguments

- model:

  A `vrpr_model`.

- num_available:

  Number of vehicles available of this type.

- capacity:

  Vehicle capacity.

- fixed_cost:

  Fixed cost per vehicle used.

- tw_early, tw_late:

  Vehicle shift time window (start/end). `tw_late = Inf` leaves the end
  of the shift unconstrained.

- max_duration:

  Maximum route duration. `Inf` = unconstrained.

- unit_distance_cost, unit_duration_cost:

  Variable cost per unit of distance and of duration for this type.
  Varying these (and `capacity`, `fixed_cost`) across calls enables a
  **heterogeneous fleet**.

- depot:

  Index (1-based) of the depot vehicles of this type start from and
  return to. Shortcut to set `start_depot` and `end_depot` together.

- start_depot, end_depot:

  Indices (1-based) of the start and end depots, in the order of
  [`add_depot()`](https://strategicprojects.github.io/vrpr/reference/add_depot.md).
  Varying them across types enables the **MDVRP** (multiple depots).

- reload_depots:

  Indices (1-based) of depots where vehicles of this type may
  reload/empty mid-route, enabling **multi-trip** routes. Empty
  (default) = no reloading.

- max_reloads:

  Maximum number of reloads per route. `Inf` = unconstrained.

## Value

The updated `vrpr_model`.

## Details

Call `add_vehicle_type()` several times for a fleet with multiple
vehicle types (different capacities, costs, shifts or depots).
