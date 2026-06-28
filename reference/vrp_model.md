# Build a vehicle routing (VRP) model

`vrp_model()` creates an empty model to which depots, clients and
vehicle types are added via the pipe (`|>`). It is the tidy equivalent
of PyVRP's `Model` class – the data boundary uses tibbles, not one
object at a time.

## Usage

``` r
vrp_model()
```

## Value

A `vrpr_model` object.

## Examples

``` r
clients <- tibble::tibble(
  x = c(10, 25, 40), y = c(5, 30, 12),
  demand = c(10, 15, 8)
)
if (FALSE) { # \dontrun{
m <- vrp_model() |>
  add_depot(x = 0, y = 0) |>
  add_clients(clients) |>
  add_vehicle_type(num_available = 5, capacity = 100)
} # }
```
