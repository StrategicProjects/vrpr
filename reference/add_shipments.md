# Add shipments (pickup and delivery pairs) to the model

A shipment is a paired pickup and delivery: the same vehicle must pick
up the goods at the pickup point and drop them off at the delivery
point, with the pickup happening first, in the same trip. This models
the classic pickup-and-delivery problem (PDPTW when combined with time
windows).

## Usage

``` r
add_shipments(model, data)
```

## Arguments

- model:

  A `vrpr_model`.

- data:

  A tibble/data.frame with at least the columns `pickup_x`, `pickup_y`,
  `delivery_x` and `delivery_y`. Optional columns: `amount` (load
  carried between pickup and delivery), `pickup_tw_early`,
  `pickup_tw_late`, `pickup_service`, `delivery_tw_early`,
  `delivery_tw_late`, `delivery_service`, `prize` and `required`.

## Value

The updated `vrpr_model`.
