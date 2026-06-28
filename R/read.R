# Leitores de instâncias VRP em formatos-padrão (sem dependência de Python).

#' Ler uma instância no formato VRPLIB / TSPLIB
#'
#' Lê instâncias CVRP (e VRPTW) no formato VRPLIB/CVRPLIB (TSPLIB estendido),
#' como as do conjunto X de Uchoa et al. Suporta coordenadas Euclidianas
#' (`EDGE_WEIGHT_TYPE : EUC_2D`); seções de janela de tempo e serviço são lidas
#' quando presentes.
#'
#' @param path Caminho do arquivo `.vrp`.
#' @param num_vehicles Número de veículos disponíveis. Se `NULL`, usa o campo
#'   `VEHICLES`/`TRUCKS`, o sufixo `-k<n>` do nome, ou — como último recurso — o
#'   número de clientes (sempre viável).
#'
#' @return Um [vrp_model()] pronto para [vrp_solve()].
#' @export
read_vrplib <- function(path, num_vehicles = NULL) {
  parsed <- parse_vrplib(readLines(path, warn = FALSE))
  spec <- parsed$spec
  sec <- parsed$sections

  ewt <- toupper(spec[["EDGE_WEIGHT_TYPE"]] %||% "EUC_2D")
  if (ewt != "EUC_2D") {
    cli::cli_abort(c(
      "Só {.val EUC_2D} é suportado por ora; o arquivo usa {.val {ewt}}.",
      "i" = "Instâncias com matriz explícita ainda não são lidas."
    ))
  }
  if (is.null(sec[["NODE_COORD_SECTION"]])) {
    cli::cli_abort("Arquivo sem {.field NODE_COORD_SECTION}.")
  }

  coords <- section_matrix(sec[["NODE_COORD_SECTION"]]) # id x y
  demand <- section_lookup(sec[["DEMAND_SECTION"]])     # id -> demand
  depot_ids <- depot_section_ids(sec[["DEPOT_SECTION"]])
  if (length(depot_ids) == 0) depot_ids <- coords[1, 1] # convenção: nó 1

  tw <- section_matrix(sec[["TIME_WINDOW_SECTION"]])    # id early late (ou NULL)
  svc <- section_lookup(sec[["SERVICE_TIME_SECTION"]])  # id -> service

  ids <- coords[, 1]
  is_depot <- ids %in% depot_ids
  capacity <- as.numeric(spec[["CAPACITY"]] %||% NA)
  if (is.na(capacity)) cli::cli_abort("Arquivo sem {.field CAPACITY}.")

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
    "Lido {.val {spec[['NAME']] %||% basename(path)}}: {nrow(clients)} cliente{?s}, \\
     {length(depot_ids)} depósito{?s}, capacidade {capacity}, {n_av} veículo{?s}."
  )
  model
}

#' Ler uma instância VRPTW no formato Solomon
#'
#' Lê instâncias VRPTW no formato de Solomon (e Gehring-Homberger), com a seção
#' `VEHICLE` (número e capacidade) e a tabela `CUSTOMER` (coordenadas, demanda,
#' janela de tempo e tempo de serviço). O cliente 0 é o depósito.
#'
#' @param path Caminho do arquivo.
#' @param num_vehicles Número de veículos; se `NULL`, usa o valor do arquivo.
#'
#' @return Um [vrp_model()] pronto para [vrp_solve()].
#' @export
read_solomon <- function(path, num_vehicles = NULL) {
  lines <- readLines(path, warn = FALSE)
  name <- trimws(lines[[which(nzchar(trimws(lines)))[1]]])

  toks <- lapply(lines, function(l) suppressWarnings(as.numeric(strsplit(trimws(l), "\\s+")[[1]])))
  numeric_rows <- function(k) Filter(function(t) length(t) == k && !anyNA(t), toks)

  veh <- numeric_rows(2)
  if (length(veh) == 0) cli::cli_abort("Não encontrei a linha NUMBER/CAPACITY (Solomon).")
  n_av <- num_vehicles %||% veh[[1]][1]
  capacity <- veh[[1]][2]

  cust <- numeric_rows(7)
  if (length(cust) == 0) cli::cli_abort("Não encontrei linhas de cliente (7 colunas).")
  m <- do.call(rbind, cust) # cust_no x y demand ready due service

  # Linha do depósito = cliente 0 (ou a primeira linha).
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
    "Lido {.val {name}}: {nrow(clients)} cliente{?s}, capacidade {capacity}, \\
     {n_av} veículo{?s} (VRPTW)."
  )
  model
}

# ---- auxiliares de parsing ------------------------------------------------

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# Separa um arquivo VRPLIB em especificação (KEY : VALUE) e seções (dados).
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

# Converte linhas de dados numéricos numa matriz.
section_matrix <- function(data_lines) {
  if (is.null(data_lines) || length(data_lines) == 0) return(NULL)
  rows <- lapply(data_lines, function(l) as.numeric(strsplit(trimws(l), "\\s+")[[1]]))
  do.call(rbind, rows)
}

# Mapa id (chr) -> valor (2ª coluna).
section_lookup <- function(data_lines) {
  m <- section_matrix(data_lines)
  if (is.null(m)) return(list())
  stats::setNames(as.list(m[, 2]), as.character(m[, 1]))
}

# Ids de depósito (até o -1 terminador).
depot_section_ids <- function(data_lines) {
  m <- section_matrix(data_lines)
  if (is.null(m)) return(integer(0))
  ids <- as.integer(m[, 1])
  ids[ids > 0]
}

# Número de veículos: campo VEHICLES/TRUCKS, sufixo -k<n> do nome, ou nº de clientes.
guess_num_vehicles <- function(spec, n_clients) {
  for (key in c("VEHICLES", "TRUCKS")) {
    if (!is.null(spec[[key]])) return(as.integer(spec[[key]]))
  }
  name <- spec[["NAME"]] %||% ""
  k <- regmatches(name, regexpr("k(\\d+)", name))
  if (length(k) == 1 && nzchar(k)) return(as.integer(sub("k", "", k)))
  n_clients
}
