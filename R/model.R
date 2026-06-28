#' Construir um modelo de roteirização (VRP)
#'
#' `vrp_model()` cria um modelo vazio ao qual se adicionam depósitos, clientes e
#' tipos de veículo via pipe (`|>`). É o equivalente tidy da classe `Model` do
#' PyVRP — a fronteira de dados usa tibbles, não objetos um a um.
#'
#' @details
#' **Fase 1 — em construção.** A estrutura da API e a validação já existem; a
#' montagem do `ProblemData` em C++ (via cpp11) é ligada a seguir, conforme o
#' roadmap em `plano.md`.
#'
#' @return Um objeto `vrpr_model`.
#' @export
#' @examples
#' clientes <- tibble::tibble(
#'   x = c(10, 25, 40), y = c(5, 30, 12),
#'   demand = c(10, 15, 8)
#' )
#' \dontrun{
#' m <- vrp_model() |>
#'   add_depot(x = 0, y = 0) |>
#'   add_clients(clientes) |>
#'   add_vehicle_type(num_available = 5, capacity = 100)
#' }
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

#' Adicionar um grupo de clientes mutuamente exclusivos
#'
#' Define um grupo do qual no máximo um cliente é visitado (ou exatamente um, se
#' `required = TRUE`). Útil para *prize-collecting* com alternativas excludentes
#' (p.ex. atender um de vários pontos equivalentes). Os clientes do grupo passam
#' automaticamente a opcionais (`required = FALSE` individual); use `prize` para
#' incentivar a visita.
#'
#' @param model Um `vrpr_model`.
#' @param clients Vetor de números de cliente (1-based, na ordem de
#'   [add_clients()]) que formam o grupo.
#' @param required Se `TRUE`, exatamente um cliente do grupo deve ser visitado;
#'   se `FALSE` (padrão), no máximo um.
#' @return O `vrpr_model` atualizado.
#' @export
add_client_group <- function(model, clients, required = FALSE) {
  check_model(model)
  clients <- as.integer(clients)
  if (length(clients) < 1L) {
    cli::cli_abort("Um grupo precisa de ao menos um cliente.")
  }
  if (anyDuplicated(clients)) {
    cli::cli_abort("Um grupo não pode ter clientes repetidos.")
  }
  model$groups <- c(model$groups, list(list(clients = clients, required = required)))
  model
}

#' Adicionar um depósito ao modelo
#' @param model Um `vrpr_model`.
#' @param x,y Coordenadas do depósito.
#' @param tw_early,tw_late Janela de tempo do depósito (abertura/fechamento).
#'   `tw_late = Inf` deixa o fechamento irrestrito.
#' @param service Tempo de serviço no depósito (p.ex. carga), por viagem.
#' @return O `vrpr_model` atualizado.
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

#' Adicionar clientes ao modelo
#'
#' @param model Um `vrpr_model`.
#' @param data Um tibble/data.frame com, no mínimo, colunas `x` e `y`. Colunas
#'   opcionais: `demand` (entrega), `pickup` (coleta), `tw_early`, `tw_late`,
#'   `service`, `release_time`, `prize`, `required`. As janelas de tempo
#'   (`tw_early`/`tw_late`/`service`) habilitam o VRPTW; `pickup` habilita
#'   coleta-e-entrega simultânea / backhaul.
#' @return O `vrpr_model` atualizado.
#' @export
add_clients <- function(model, data) {
  check_model(model)
  data <- tibble::as_tibble(data)
  required_cols <- c("x", "y")
  missing <- setdiff(required_cols, names(data))
  if (length(missing) > 0) {
    cli::cli_abort("{.arg data} precisa das colunas {.field {missing}}.")
  }
  model$clients <- vctrs_rbind_clients(model$clients, data)
  model
}

#' Adicionar um tipo de veículo ao modelo
#' @param model Um `vrpr_model`.
#' @param num_available Quantidade de veículos disponíveis deste tipo.
#' @param capacity Capacidade do veículo.
#' @param fixed_cost Custo fixo por veículo usado.
#' @param tw_early,tw_late Janela do turno do veículo (início/fim). `tw_late = Inf`
#'   deixa o fim do turno irrestrito.
#' @param max_duration Duração máxima da rota. `Inf` = irrestrito.
#' @param unit_distance_cost,unit_duration_cost Custos variáveis por unidade de
#'   distância e de duração deste tipo. Diferenciar estes (e `capacity`,
#'   `fixed_cost`) entre chamadas habilita a **frota heterogênea**.
#' @param depot Índice (1-based) do depósito de onde os veículos deste tipo saem
#'   e ao qual retornam. Atalho para definir `start_depot` e `end_depot` juntos.
#' @param start_depot,end_depot Índices (1-based) dos depósitos de partida e de
#'   retorno, na ordem de [add_depot()]. Diferenciá-los entre tipos habilita o
#'   **MDVRP** (múltiplos depósitos).
#' @param reload_depots Índices (1-based) de depósitos onde os veículos deste
#'   tipo podem reabastecer/esvaziar no meio da rota, habilitando **multi-trip**.
#'   Vazio (padrão) = sem reload.
#' @param max_reloads Número máximo de reloads por rota. `Inf` = irrestrito.
#' @details Chame `add_vehicle_type()` várias vezes para uma frota com múltiplos
#'   tipos de veículo (capacidades, custos, turnos ou depósitos distintos).
#' @return O `vrpr_model` atualizado.
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
  cli::cli_h1("modelo VRP")
  cli::cli_bullets(c(
    "*" = "{nrow(x$depots)} depósito{?s}",
    "*" = "{nrow(x$clients)} cliente{?s}",
    "*" = "{nrow(x$vehicle_types)} tipo{?s} de veículo",
    if (length(x$groups) > 0) c("*" = "{length(x$groups)} grupo{?s} de clientes")
  ))
  invisible(x)
}

check_model <- function(model, call = rlang::caller_env()) {
  if (!inherits(model, "vrpr_model")) {
    cli::cli_abort(
      "{.arg model} deve ser um {.cls vrpr_model} (use {.fn vrp_model}).",
      call = call
    )
  }
}

# Empilha clientes preenchendo colunas opcionais ausentes com defaults sensatos.
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
