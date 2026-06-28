#' Build a vehicle routing (VRP) model
#'
#' `vrp_model()` creates an empty model to which depots, clients and vehicle
#' types are added via the pipe (`|>`). It is the tidy equivalent of PyVRP's
#' `Model` class -- the data boundary uses tibbles, not one object at a time.
#'
#' @return A `vrpr_model` object.
#' @export
#' @examples
#' clients <- tibble::tibble(
#'   x = c(10, 25, 40), y = c(5, 30, 12),
#'   demand = c(10, 15, 8)
#' )
#' m <- vrp_model() |>
#'   add_depot(x = 0, y = 0) |>
#'   add_clients(clients) |>
#'   add_vehicle_type(num_available = 5, capacity = 100)
#' m
vrp_model <- function() {
  structure(
    list(
      depots = tibble::tibble(
        x = double(), y = double(),
        tw_early = double(), tw_late = double(), service = double()
      ),
      clients = tibble::tibble(
        x = double(), y = double(), demand = double(), pickup = double(),
        tw_early = double(), tw_late = double(), service = double(),
        release_time = double(), prize = double(), required = logical()
      ),
      vehicle_types = tibble::tibble(
        num_available = integer(), capacity = double(), fixed_cost = double(),
        tw_early = double(), tw_late = double(), max_duration = double(),
        unit_distance_cost = double(), unit_duration_cost = double(),
        start_depot = integer(), end_depot = integer(),
        reload_depots = list(), max_reloads = double()
      ),
      groups = list()
    ),
    class = "vrpr_model"
  )
}

#' Add a mutually exclusive group of clients
#'
#' Defines a group from which at most one client is visited (or exactly one if
#' `required = TRUE`). Useful for prize-collecting with exclusive alternatives
#' (e.g. serving one of several equivalent points). Clients in the group
#' automatically become optional (individual `required = FALSE`); use `prize` to
#' encourage a visit.
#'
#' @param model A `vrpr_model`.
#' @param clients Vector of client numbers (1-based, in the order of
#'   [add_clients()]) that form the group.
#' @param required If `TRUE`, exactly one client in the group must be visited;
#'   if `FALSE` (default), at most one.
#' @return The updated `vrpr_model`.
#' @export
add_client_group <- function(model, clients, required = FALSE) {
  check_model(model)
  clients <- as.integer(clients)
  if (length(clients) < 1L) {
    cli::cli_abort("A group needs at least one client.")
  }
  if (anyDuplicated(clients)) {
    cli::cli_abort("A group cannot contain duplicate clients.")
  }
  model$groups <- c(model$groups, list(list(clients = clients, required = required)))
  model
}

#' Add a depot to the model
#' @param model A `vrpr_model`.
#' @param x,y Depot coordinates.
#' @param tw_early,tw_late Depot time window (opening/closing). `tw_late = Inf`
#'   leaves the closing time unconstrained.
#' @param service Service time at the depot (e.g. loading), per trip.
#' @return The updated `vrpr_model`.
#' @export
add_depot <- function(model, x, y, tw_early = 0, tw_late = Inf, service = 0) {
  check_model(model)
  model$depots <- tibble::add_row(
    model$depots,
    x = as.double(x), y = as.double(y),
    tw_early = as.double(tw_early), tw_late = as.double(tw_late),
    service = as.double(service)
  )
  model
}

#' Add clients to the model
#'
#' @param model A `vrpr_model`.
#' @param data A tibble/data.frame with at least the columns `x` and `y`.
#'   Optional columns: `demand` (delivery), `pickup`, `tw_early`, `tw_late`,
#'   `service`, `release_time`, `prize`, `required`. The time-window columns
#'   (`tw_early`/`tw_late`/`service`) enable the VRPTW; `pickup` enables
#'   simultaneous pickup and delivery / backhaul.
#' @return The updated `vrpr_model`.
#' @export
add_clients <- function(model, data) {
  check_model(model)
  data <- tibble::as_tibble(data)
  required_cols <- c("x", "y")
  missing <- setdiff(required_cols, names(data))
  if (length(missing) > 0) {
    cli::cli_abort("{.arg data} needs the column{?s} {.field {missing}}.")
  }
  model$clients <- vctrs_rbind_clients(model$clients, data)
  model
}

#' Add a vehicle type to the model
#' @param model A `vrpr_model`.
#' @param num_available Number of vehicles available of this type.
#' @param capacity Vehicle capacity.
#' @param fixed_cost Fixed cost per vehicle used.
#' @param tw_early,tw_late Vehicle shift time window (start/end). `tw_late = Inf`
#'   leaves the end of the shift unconstrained.
#' @param max_duration Maximum route duration. `Inf` = unconstrained.
#' @param unit_distance_cost,unit_duration_cost Variable cost per unit of
#'   distance and of duration for this type. Varying these (and `capacity`,
#'   `fixed_cost`) across calls enables a **heterogeneous fleet**.
#' @param depot Index (1-based) of the depot vehicles of this type start from and
#'   return to. Shortcut to set `start_depot` and `end_depot` together.
#' @param start_depot,end_depot Indices (1-based) of the start and end depots, in
#'   the order of [add_depot()]. Varying them across types enables the
#'   **MDVRP** (multiple depots).
#' @param reload_depots Indices (1-based) of depots where vehicles of this type
#'   may reload/empty mid-route, enabling **multi-trip** routes. Empty (default)
#'   = no reloading.
#' @param max_reloads Maximum number of reloads per route. `Inf` = unconstrained.
#' @details Call `add_vehicle_type()` several times for a fleet with multiple
#'   vehicle types (different capacities, costs, shifts or depots).
#' @return The updated `vrpr_model`.
#' @export
add_vehicle_type <- function(model, num_available, capacity, fixed_cost = 0,
                             tw_early = 0, tw_late = Inf, max_duration = Inf,
                             unit_distance_cost = 1, unit_duration_cost = 0,
                             depot = 1L, start_depot = depot, end_depot = depot,
                             reload_depots = integer(0), max_reloads = Inf) {
  check_model(model)
  model$vehicle_types <- tibble::add_row(
    model$vehicle_types,
    num_available = as.integer(num_available),
    capacity = as.double(capacity),
    fixed_cost = as.double(fixed_cost),
    tw_early = as.double(tw_early),
    tw_late = as.double(tw_late),
    max_duration = as.double(max_duration),
    unit_distance_cost = as.double(unit_distance_cost),
    unit_duration_cost = as.double(unit_duration_cost),
    start_depot = as.integer(start_depot),
    end_depot = as.integer(end_depot),
    reload_depots = list(as.integer(reload_depots)),
    max_reloads = as.double(max_reloads)
  )
  model
}

#' @export
print.vrpr_model <- function(x, ...) {
  cli::cli_h1("VRP model")
  cli::cli_bullets(c(
    "*" = "{nrow(x$depots)} depot{?s}",
    "*" = "{nrow(x$clients)} client{?s}",
    "*" = "{nrow(x$vehicle_types)} vehicle type{?s}",
    if (length(x$groups) > 0) c("*" = "{length(x$groups)} client group{?s}")
  ))
  invisible(x)
}

check_model <- function(model, call = rlang::caller_env()) {
  if (!inherits(model, "vrpr_model")) {
    cli::cli_abort(
      "{.arg model} must be a {.cls vrpr_model} (use {.fn vrp_model}).",
      call = call
    )
  }
}

# Stacks clients, filling missing optional columns with sensible defaults.
vctrs_rbind_clients <- function(acc, data) {
  defaults <- list(
    demand = 0, pickup = 0, tw_early = 0, tw_late = Inf,
    service = 0, release_time = 0, prize = 0, required = TRUE
  )
  for (col in names(defaults)) {
    if (is.null(data[[col]])) data[[col]] <- defaults[[col]]
  }
  data$required <- as.logical(data$required)
  cols <- names(acc)
  vctrs::vec_rbind(acc, data[cols])
}
