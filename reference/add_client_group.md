# Add a mutually exclusive group of clients

Defines a group from which at most one client is visited (or exactly one
if `required = TRUE`). Useful for prize-collecting with exclusive
alternatives (e.g. serving one of several equivalent points). Clients in
the group automatically become optional (individual `required = FALSE`);
use `prize` to encourage a visit.

## Usage

``` r
add_client_group(model, clients, required = FALSE)
```

## Arguments

- model:

  A `vrpr_model`.

- clients:

  Vector of client numbers (1-based, in the order of
  [`add_clients()`](https://strategicprojects.github.io/vrpr/reference/add_clients.md))
  that form the group.

- required:

  If `TRUE`, exactly one client in the group must be visited; if `FALSE`
  (default), at most one.

## Value

The updated `vrpr_model`.
