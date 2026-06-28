#' Assemble the problem data (ProblemData) from a model
#'
#' Builds PyVRP's C++ `ProblemData` structure from a [vrp_model()]. Locations
#' follow PyVRP's convention: depots first (low indices), then clients.
#'
#' Integer measures (distance, duration, cost, load) travel as R `numeric` with
#' integer semantics; non-integer values are rejected at the C++ boundary. Use
#' `Inf` for "unconstrained" limits (e.g. `tw_late`).
#'
#' @param model A [vrp_model()] with at least one depot and one vehicle type.
#' @param distance,duration Matrices (`numeric`, `n x n`, locations in
#'   depots-then-clients order) of distance and duration. If `NULL`, they are
#'   computed as the rounded Euclidean distance between coordinates; `duration`
#'   defaults to `distance`.
#'
#' @return A `vrpr_problem_data` object (a wrapper around a C++ external pointer).
#' @export
vrp_problem_data <- function(model, distance = NULL, duration = NULL) {
  check_model(model)
  if (nrow(model$depots) == 0) {
    cli::cli_abort("The model needs at least one depot.")
  }
  if (nrow(model$vehicle_types) == 0) {
    cli::cli_abort("The model needs at least one vehicle type.")
  }

  loc_x <- c(model$depots$x, model$clients$x)
  loc_y <- c(model$depots$y, model$clients$y)
  n <- length(loc_x)

  if (is.null(distance)) {
    distance <- euclidean_matrix(loc_x, loc_y)
  }
  check_square_matrix(distance, n, "distance")
  if (is.null(duration)) {
    duration <- distance
  }
  check_square_matrix(duration, n, "duration")

  vt <- with_vehicle_defaults(model$vehicle_types)
  cl <- model$clients

  # Depots: 1-based in the model -> 0-based location indices (depots occupy
  # locations 0..D-1).
  n_depots <- nrow(model$depots)
  for (col in c("start_depot", "end_depot")) {
    d <- vt[[col]]
    if (any(d < 1L | d > n_depots)) {
      cli::cli_abort(
        "{.field {col}} must be in 1..{n_depots} (number of depots)."
      )
    }
  }

  # Multi-trip: 1-based reload depots -> 0-based location indices.
  reload_loc <- lapply(vt$reload_depots, function(r) {
    r <- as.integer(r)
    if (length(r) > 0 && any(r < 1L | r > n_depots)) {
      cli::cli_abort("{.field reload_depots} must be in 1..{n_depots}.")
    }
    as.integer(r - 1L)
  })

  # Mutually exclusive client groups. Each client belongs to at most one group;
  # group members become optional (the group carries the requirement).
  n_clients <- nrow(cl)
  client_group <- rep(-1L, n_clients) # 0-based group index, -1 = no group
  group_members <- list()
  group_required <- logical(0)
  for (g in seq_along(model$groups)) {
    grp <- model$groups[[g]]
    members <- grp$clients
    if (any(members < 1L | members > n_clients)) {
      cli::cli_abort("Group {g}: client out of range 1..{n_clients}.")
    }
    if (any(client_group[members] >= 0L)) {
      cli::cli_abort("A client cannot belong to two groups.")
    }
    client_group[members] <- g - 1L
    cl$required[members] <- FALSE # the group is mutually exclusive
    group_members[[g]] <- as.integer(n_depots + members - 1L) # -> location
    group_required[g] <- isTRUE(grp$required)
  }

  ptr <- vrpr_problem_data_create(
    depot_x = as.double(model$depots$x),
    depot_y = as.double(model$depots$y),
    depot_tw_early = as.double(model$depots$tw_early),
    depot_tw_late = as.double(model$depots$tw_late),
    depot_service = as.double(model$depots$service),
    client_x = as.double(cl$x),
    client_y = as.double(cl$y),
    client_delivery = as.double(cl$demand),
    client_pickup = as.double(cl$pickup),
    client_service = as.double(cl$service),
    client_tw_early = as.double(cl$tw_early),
    client_tw_late = as.double(cl$tw_late),
    client_release = as.double(cl$release_time),
    client_prize = as.double(cl$prize),
    client_required = as.logical(cl$required),
    veh_num_available = as.integer(vt$num_available),
    veh_capacity = as.double(vt$capacity),
    veh_fixed_cost = as.double(vt$fixed_cost),
    veh_tw_early = as.double(vt$tw_early),
    veh_tw_late = as.double(vt$tw_late),
    veh_max_duration = as.double(vt$max_duration),
    veh_max_distance = as.double(vt$max_distance),
    veh_unit_distance_cost = as.double(vt$unit_distance_cost),
    veh_unit_duration_cost = as.double(vt$unit_duration_cost),
    veh_start_depot = as.integer(vt$start_depot - 1L),
    veh_end_depot = as.integer(vt$end_depot - 1L),
    veh_reload_depots = reload_loc,
    veh_max_reloads = as.double(vt$max_reloads),
    client_group = client_group,
    group_members = group_members,
    group_required = group_required,
    distance = distance,
    duration = duration
  )

  # Locations (depots then clients), kept for plotting/inspection.
  locations <- tibble::tibble(
    x = loc_x, y = loc_y,
    kind = c(rep("depot", n_depots), rep("client", n_clients)),
    index = c(seq_len(n_depots), seq_len(n_clients))
  )

  structure(
    list(ptr = ptr, summary = vrpr_problem_data_summary(ptr), locations = locations),
    class = "vrpr_problem_data"
  )
}

#' @export
print.vrpr_problem_data <- function(x, ...) {
  s <- x$summary
  cli::cli_h1("ProblemData")
  cli::cli_bullets(c(
    "*" = "{s$num_clients} client{?s} · {s$num_depots} depot{?s} \\
           ({s$num_locations} locations)",
    "*" = "{s$num_vehicle_types} vehicle type{?s} · {s$num_vehicles} vehicle{?s}",
    "*" = "{s$num_load_dimensions} load dimension{?s} · \\
           {s$num_profiles} profile{?s}",
    "*" = "time windows: {if (s$has_time_windows) 'yes' else 'no'}"
  ))
  invisible(x)
}

# Rounded Euclidean distance (PyVRP measures are integers). Uses round-half-up
# (floor(d + 0.5)), the TSPLIB/PyVRP EUC_2D convention -- not R's round(), which
# rounds half to even.
euclidean_matrix <- function(x, y) {
  d <- as.matrix(stats::dist(cbind(x, y), method = "euclidean"))
  dimnames(d) <- NULL
  floor(d + 0.5)
}

check_square_matrix <- function(m, n, arg, call = rlang::caller_env()) {
  if (!is.matrix(m) || !is.numeric(m)) {
    cli::cli_abort("{.arg {arg}} must be a numeric matrix.", call = call)
  }
  if (nrow(m) != n || ncol(m) != n) {
    cli::cli_abort(
      "{.arg {arg}} must be {n}x{n} (locations), but is {nrow(m)}x{ncol(m)}.",
      call = call
    )
  }
}

# Fills `max_distance` (the only column not yet coming from the model).
with_vehicle_defaults <- function(vt) {
  if (is.null(vt[["max_distance"]])) vt[["max_distance"]] <- Inf
  vt
}
