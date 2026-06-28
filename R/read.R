# Readers for VRP instances in standard formats (no Python dependency).

#' Read an instance in VRPLIB / TSPLIB format
#'
#' Reads CVRP (and VRPTW) instances in VRPLIB/CVRPLIB format (extended TSPLIB),
#' such as the X set by Uchoa et al. Supports Euclidean coordinates
#' (`EDGE_WEIGHT_TYPE : EUC_2D`); time-window and service-time sections are read
#' when present.
#'
#' @param path Path to the `.vrp` file.
#' @param num_vehicles Number of available vehicles. If `NULL`, uses the
#'   `VEHICLES`/`TRUCKS` field, the `-k<n>` suffix in the name, or -- as a last
#'   resort -- the number of clients (always feasible).
#'
#' @return A [vrp_model()] ready for [vrp_solve()].
#' @export
read_vrplib <- function(path, num_vehicles = NULL) {
  parsed <- parse_vrplib(readLines(path, warn = FALSE))
  spec <- parsed$spec
  sec <- parsed$sections

  ewt <- toupper(spec[["EDGE_WEIGHT_TYPE"]] %||% "EUC_2D")
  if (ewt != "EUC_2D") {
    cli::cli_abort(c(
      "Only {.val EUC_2D} is supported for now; the file uses {.val {ewt}}.",
      "i" = "Instances with an explicit matrix are not read yet."
    ))
  }
  if (is.null(sec[["NODE_COORD_SECTION"]])) {
    cli::cli_abort("File without a {.field NODE_COORD_SECTION}.")
  }

  coords <- section_matrix(sec[["NODE_COORD_SECTION"]]) # id x y
  demand <- section_lookup(sec[["DEMAND_SECTION"]])     # id -> demand
  depot_ids <- depot_section_ids(sec[["DEPOT_SECTION"]])
  if (length(depot_ids) == 0) depot_ids <- coords[1, 1] # convention: node 1

  tw <- section_matrix(sec[["TIME_WINDOW_SECTION"]])    # id early late (or NULL)
  svc <- section_lookup(sec[["SERVICE_TIME_SECTION"]])  # id -> service

  ids <- coords[, 1]
  is_depot <- ids %in% depot_ids
  capacity <- as.numeric(spec[["CAPACITY"]] %||% NA)
  if (is.na(capacity)) cli::cli_abort("File without a {.field CAPACITY}.")

  tw_for <- function(id) {
    if (is.null(tw)) return(c(0, Inf))
    row <- tw[tw[, 1] == id, , drop = FALSE]
    if (nrow(row) == 0) c(0, Inf) else c(row[1, 2], row[1, 3])
  }

  model <- vrp_model()
  for (id in depot_ids) {
    i <- which(ids == id)
    w <- tw_for(id)
    model <- add_depot(model, x = coords[i, 2], y = coords[i, 3],
                       tw_early = w[1], tw_late = w[2])
  }

  client_rows <- which(!is_depot)
  clients <- tibble::tibble(
    x = coords[client_rows, 2],
    y = coords[client_rows, 3],
    demand = vapply(ids[client_rows], function(id) demand[[as.character(id)]] %||% 0, numeric(1)),
    tw_early = vapply(ids[client_rows], function(id) tw_for(id)[1], numeric(1)),
    tw_late = vapply(ids[client_rows], function(id) tw_for(id)[2], numeric(1)),
    service = vapply(ids[client_rows], function(id) svc[[as.character(id)]] %||% 0, numeric(1))
  )
  model <- add_clients(model, clients)

  n_av <- num_vehicles %||% guess_num_vehicles(spec, nrow(clients))
  model <- add_vehicle_type(model, num_available = n_av, capacity = capacity)

  cli::cli_alert_success(
    "Read {.val {spec[['NAME']] %||% basename(path)}}: {nrow(clients)} client{?s}, \\
     {length(depot_ids)} depot{?s}, capacity {capacity}, {n_av} vehicle{?s}."
  )
  model
}

#' Read a VRPTW instance in Solomon format
#'
#' Reads VRPTW instances in Solomon (and Gehring-Homberger) format, with the
#' `VEHICLE` section (number and capacity) and the `CUSTOMER` table (coordinates,
#' demand, time window and service time). Customer 0 is the depot.
#'
#' @param path Path to the file.
#' @param num_vehicles Number of vehicles; if `NULL`, uses the value from the file.
#'
#' @return A [vrp_model()] ready for [vrp_solve()].
#' @export
read_solomon <- function(path, num_vehicles = NULL) {
  lines <- readLines(path, warn = FALSE)
  name <- trimws(lines[[which(nzchar(trimws(lines)))[1]]])

  toks <- lapply(lines, function(l) suppressWarnings(as.numeric(strsplit(trimws(l), "\\s+")[[1]])))
  numeric_rows <- function(k) Filter(function(t) length(t) == k && !anyNA(t), toks)

  veh <- numeric_rows(2)
  if (length(veh) == 0) cli::cli_abort("Could not find the NUMBER/CAPACITY line (Solomon).")
  n_av <- num_vehicles %||% veh[[1]][1]
  capacity <- veh[[1]][2]

  cust <- numeric_rows(7)
  if (length(cust) == 0) cli::cli_abort("Could not find client rows (7 columns).")
  m <- do.call(rbind, cust) # cust_no x y demand ready due service

  # Depot row = customer 0 (or the first row).
  depot_row <- which(m[, 1] == 0)
  if (length(depot_row) == 0) depot_row <- 1L
  depot_row <- depot_row[1]

  model <- vrp_model() |>
    add_depot(
      x = m[depot_row, 2], y = m[depot_row, 3],
      tw_early = m[depot_row, 5], tw_late = m[depot_row, 6]
    )

  cust_rows <- setdiff(seq_len(nrow(m)), depot_row)
  clients <- tibble::tibble(
    x = m[cust_rows, 2], y = m[cust_rows, 3],
    demand = m[cust_rows, 4],
    tw_early = m[cust_rows, 5], tw_late = m[cust_rows, 6],
    service = m[cust_rows, 7]
  )
  model <- model |>
    add_clients(clients) |>
    add_vehicle_type(num_available = n_av, capacity = capacity)

  cli::cli_alert_success(
    "Read {.val {name}}: {nrow(clients)} client{?s}, capacity {capacity}, \\
     {n_av} vehicle{?s} (VRPTW)."
  )
  model
}

# ---- parsing helpers ------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# Splits a VRPLIB file into specification (KEY : VALUE) and sections (data).
parse_vrplib <- function(lines) {
  spec <- list()
  sections <- list()
  cur <- NULL
  for (raw in lines) {
    ln <- trimws(raw)
    if (!nzchar(ln)) next
    if (identical(ln, "EOF")) break
    if (grepl("_SECTION$", ln)) {
      cur <- ln
      sections[[cur]] <- character(0)
    } else if (is.null(cur) && grepl(":", ln)) {
      kv <- strsplit(ln, ":", fixed = TRUE)[[1]]
      spec[[trimws(kv[1])]] <- trimws(paste(kv[-1], collapse = ":"))
    } else {
      sections[[cur]] <- c(sections[[cur]], ln)
    }
  }
  list(spec = spec, sections = sections)
}

# Converts numeric data lines into a matrix.
section_matrix <- function(data_lines) {
  if (is.null(data_lines) || length(data_lines) == 0) return(NULL)
  rows <- lapply(data_lines, function(l) as.numeric(strsplit(trimws(l), "\\s+")[[1]]))
  do.call(rbind, rows)
}

# Map id (chr) -> value (2nd column).
section_lookup <- function(data_lines) {
  m <- section_matrix(data_lines)
  if (is.null(m)) return(list())
  stats::setNames(as.list(m[, 2]), as.character(m[, 1]))
}

# Depot ids (up to the -1 terminator).
depot_section_ids <- function(data_lines) {
  m <- section_matrix(data_lines)
  if (is.null(m)) return(integer(0))
  ids <- as.integer(m[, 1])
  ids[ids > 0]
}

# Number of vehicles: VEHICLES/TRUCKS field, -k<n> suffix of the name, or n clients.
guess_num_vehicles <- function(spec, n_clients) {
  for (key in c("VEHICLES", "TRUCKS")) {
    if (!is.null(spec[[key]])) return(as.integer(spec[[key]]))
  }
  name <- spec[["NAME"]] %||% ""
  k <- regmatches(name, regexpr("k(\\d+)", name))
  if (length(k) == 1 && nzchar(k)) return(as.integer(sub("k", "", k)))
  n_clients
}
