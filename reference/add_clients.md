# Add clients to the model

Add clients to the model

## Usage

``` r
add_clients(model, data)
```

## Arguments

- model:

  A `vrpr_model`.

- data:

  A tibble/data.frame with at least the columns `x` and `y`. Optional
  columns: `demand` (delivery), `pickup`, `tw_early`, `tw_late`,
  `service`, `release_time`, `prize`, `required`. The time-window
  columns (`tw_early`/`tw_late`/`service`) enable the VRPTW; `pickup`
  enables simultaneous pickup and delivery / backhaul.

## Value

The updated `vrpr_model`.
