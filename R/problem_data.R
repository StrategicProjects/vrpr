#' Montar os dados do problema (ProblemData) a partir de um modelo
#'
#' Constrói a estrutura C++ `ProblemData` do PyVRP a partir de um [vrp_model()].
#' As localizações seguem a convenção do PyVRP: depósitos primeiro (índices
#' baixos), depois os clientes.
#'
#' Medidas inteiras (distância, duração, custo, carga) trafegam como `numeric`
#' de R com semântica inteira; valores não inteiros são rejeitados na fronteira
#' C++. Use `Inf` para restrições "irrestritas" (p.ex. `tw_late`).
#'
#' @param model Um [vrp_model()] com ao menos um depósito e um tipo de veículo.
#' @param distance,duration Matrizes (`numeric`, `n x n`, locais na ordem
#'   depósitos-depois-clientes) de distância e duração. Se `NULL`, são
#'   calculadas como a distância Euclidiana arredondada entre as coordenadas;
#'   `duration` por padrão iguala `distance`.
#'
#' @return Um objeto `vrpr_problem_data` (envelope de um external pointer C++).
#' @export
vrp_problem_data <- function(model, distance = NULL, duration = NULL) {
  check_model(model)
  if (nrow(model$depots) == 0) {
    cli::cli_abort("O modelo precisa de ao menos um depósito.")
  }
  if (nrow(model$vehicle_types) == 0) {
    cli::cli_abort("O modelo precisa de ao menos um tipo de veículo.")
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

  # Depósitos: 1-based no modelo -> índices de localização 0-based (depósitos
  # ocupam as localizações 0..D-1).
  n_depots <- nrow(model$depots)
  for (col in c("start_depot", "end_depot")) {
    d <- vt[[col]]
    if (any(d < 1L | d > n_depots)) {
      cli::cli_abort(
        "{.field {col}} deve estar em 1..{n_depots} (nº de depósitos)."
      )
    }
  }

  # Multi-trip: depósitos de reload 1-based -> localização 0-based.
  reload_loc <- lapply(vt$reload_depots, function(r) {
    r <- as.integer(r)
    if (length(r) > 0 && any(r < 1L | r > n_depots)) {
      cli::cli_abort("{.field reload_depots} deve estar em 1..{n_depots}.")
    }
    as.integer(r - 1L)
  })

  # Grupos de clientes mutuamente exclusivos. Cada cliente pertence a no máximo
  # um grupo; membros de grupo viram opcionais (o grupo carrega a obrigatoriedade).
  n_clients <- nrow(cl)
  client_group <- rep(-1L, n_clients) # índice 0-based do grupo, -1 = sem grupo
  group_members <- list()
  group_required <- logical(0)
  for (g in seq_along(model$groups)) {
    grp <- model$groups[[g]]
    members <- grp$clients
    if (any(members < 1L | members > n_clients)) {
      cli::cli_abort("Grupo {g}: cliente fora de 1..{n_clients}.")
    }
    if (any(client_group[members] >= 0L)) {
      cli::cli_abort("Um cliente não pode pertencer a dois grupos.")
    }
    client_group[members] <- g - 1L
    cl$required[members] <- FALSE # o grupo é mutuamente exclusivo
    group_members[[g]] <- as.integer(n_depots + members - 1L) # -> localização
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

  structure(
    list(ptr = ptr, summary = vrpr_problem_data_summary(ptr)),
    class = "vrpr_problem_data"
  )
}

#' @export
print.vrpr_problem_data <- function(x, ...) {
  s <- x$summary
  cli::cli_h1("ProblemData")
  cli::cli_bullets(c(
    "*" = "{s$num_clients} cliente{?s} · {s$num_depots} depósito{?s} \\
           ({s$num_locations} localizações)",
    "*" = "{s$num_vehicle_types} tipo{?s} de veículo · {s$num_vehicles} veículo{?s}",
    "*" = "{s$num_load_dimensions} dimensão/dimensões de carga · \\
           {s$num_profiles} perfil/perfis",
    "*" = "janelas de tempo: {if (s$has_time_windows) 'sim' else 'não'}"
  ))
  invisible(x)
}

# Distância Euclidiana arredondada (medidas do PyVRP são inteiras).
euclidean_matrix <- function(x, y) {
  d <- as.matrix(stats::dist(cbind(x, y), method = "euclidean"))
  dimnames(d) <- NULL
  round(d)
}

check_square_matrix <- function(m, n, arg, call = rlang::caller_env()) {
  if (!is.matrix(m) || !is.numeric(m)) {
    cli::cli_abort("{.arg {arg}} deve ser uma matriz numérica.", call = call)
  }
  if (nrow(m) != n || ncol(m) != n) {
    cli::cli_abort(
      "{.arg {arg}} deve ser {n}x{n} (localizações), mas é {nrow(m)}x{ncol(m)}.",
      call = call
    )
  }
}

# Preenche `max_distance` (única coluna que ainda não vem do modelo).
with_vehicle_defaults <- function(vt) {
  if (is.null(vt[["max_distance"]])) vt[["max_distance"]] <- Inf
  vt
}
