# Add a depot to the model

Add a depot to the model

## Usage

``` r
add_depot(model, x, y, tw_early = 0, tw_late = Inf, service = 0)
```

## Arguments

- model:

  A `vrpr_model`.

- x, y:

  Depot coordinates.

- tw_early, tw_late:

  Depot time window (opening/closing). `tw_late = Inf` leaves the
  closing time unconstrained.

- service:

  Service time at the depot (e.g. loading), per trip.

## Value

The updated `vrpr_model`.
