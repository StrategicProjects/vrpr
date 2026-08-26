# Adaptive penalty manager (port of PyVRP's PenaltyManager, >= 0.14).
#
# Keeps penalty weights for load (per dimension), time warp and distance, and
# adjusts them from the recent fraction of feasible solutions in each
# dimension: a penalty rises when there is too little feasibility (constraint
# too weak) and falls when there is too much (constraint too strong).
# Registration records violation *magnitudes*; feasibility is `violation == 0`.
# Initial penalties sit at the midpoint of [min_penalty, max_penalty], as in
# PyVRP's `PenaltyParams.midpoint_penalties`. A mutable, environment-based
# object.

new_penalty_manager <- function(num_load_dims = 1L,
                                solutions_between_updates = 500L,
                                penalty_increase = 1.5,
                                penalty_decrease = 0.90,
                                target_feasible = 0.65,
                                feas_tolerance = 0.05,
                                min_penalty = 0.1,
                                max_penalty = 100000) {
  self <- new.env(parent = emptyenv())
  self$num_load_dims <- max(1L, as.integer(num_load_dims))
  # Dimensions: load[1..k], time warp, distance.
  n_dims <- self$num_load_dims + 2L
  midpoint <- min_penalty + (max_penalty - min_penalty) / 2
  self$penalties <- rep(midpoint, n_dims)
  self$viol <- vector("list", n_dims)
  for (d in seq_len(n_dims)) self$viol[[d]] <- numeric(0)
  self$prev_avg_viol <- rep(Inf, n_dims)
  self$params <- list(
    n = as.integer(solutions_between_updates),
    inc = penalty_increase, dec = penalty_decrease,
    target = target_feasible, tol = feas_tolerance,
    min = min_penalty, max = max_penalty
  )
  class(self) <- "vrpr_penalty_manager"
  self
}

# Adjusts one weight from the recent feasibility fraction (PyVRP's _compute).
compute_penalty <- function(value, feas_frac, p) {
  diff <- p$target - feas_frac
  if (abs(diff) >= p$tol) {
    value <- if (diff > 0) value * p$inc else value * p$dec
  }
  max(p$min, min(p$max, value))
}

# Registers a solution's constraint violations (magnitudes, one per dimension)
# and updates the weights every `n` registrations per dimension.
pm_register <- function(pm, summary) {
  violations <- c(
    summary$excess_load, # one per load dimension
    summary$time_warp,
    summary$excess_distance
  )
  p <- pm$params
  for (d in seq_along(violations)) {
    pm$viol[[d]] <- c(pm$viol[[d]], violations[[d]])
    if (length(pm$viol[[d]]) >= p$n) {
      feas_frac <- mean(pm$viol[[d]] == 0)
      avg_viol <- mean(pm$viol[[d]])
      pm$viol[[d]] <- numeric(0)
      if (pm$penalties[[d]] >= p$max
          && (p$target - feas_frac) >= p$tol
          && avg_viol >= pm$prev_avg_viol[[d]]) {
        cli::cli_warn(c(
          "A penalty parameter has reached its maximum value.",
          "i" = "This typically happens when the instance is infeasible or \\
                 penalised costs are much larger than the objective."
        ))
      }
      pm$prev_avg_viol[[d]] <- avg_viol
      pm$penalties[[d]] <- compute_penalty(pm$penalties[[d]], feas_frac, p)
    }
  }
  invisible(pm)
}

# Cost evaluator with the current weights.
pm_cost_evaluator <- function(pm) {
  k <- pm$num_load_dims
  vrp_cost_evaluator(
    load_penalties = pm$penalties[seq_len(k)],
    tw_penalty = pm$penalties[[k + 1L]],
    dist_penalty = pm$penalties[[k + 2L]]
  )
}

# Cost evaluator with maximum penalties (used e.g. for the initial solution,
# so the search moves towards feasibility fast).
pm_max_cost_evaluator <- function(pm) {
  vrp_cost_evaluator(
    load_penalties = rep(pm$params$max, pm$num_load_dims),
    tw_penalty = pm$params$max,
    dist_penalty = pm$params$max
  )
}
