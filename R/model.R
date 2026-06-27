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
      depots = tibble::tibble(x = double(), y = double()),
      clients = tibble::tibble(
        x = double(), y = double(), demand = double(),
        tw_early = double(), tw_late = double(),
        service = double(), prize = double(), required = logical()
      ),
      vehicle_types = tibble::tibble(
        num_available = integer(), capacity = double(),
        fixed_cost = double()
      )
    ),
    class = "vrpr_model"
  )
}

#' Adicionar um depósito ao modelo
#' @param model Um `vrpr_model`.
#' @param x,y Coordenadas do depósito.
#' @return O `vrpr_model` atualizado.
#' @export
add_depot <- function(model, x, y) {
  check_model(model)
  model$depots <- tibble::add_row(model$depots, x = as.double(x), y = as.double(y))
  model
}

#' Adicionar clientes ao modelo
#'
#' @param model Um `vrpr_model`.
#' @param data Um tibble/data.frame com, no mínimo, colunas `x` e `y`. Colunas
#'   opcionais: `demand`, `tw_early`, `tw_late`, `service`, `prize`, `required`.
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
#' @return O `vrpr_model` atualizado.
#' @export
add_vehicle_type <- function(model, num_available, capacity, fixed_cost = 0) {
  check_model(model)
  model$vehicle_types <- tibble::add_row(
    model$vehicle_types,
    num_available = as.integer(num_available),
    capacity = as.double(capacity),
    fixed_cost = as.double(fixed_cost)
  )
  model
}

#' @export
print.vrpr_model <- function(x, ...) {
  cli::cli_h1("modelo VRP")
  cli::cli_bullets(c(
    "*" = "{nrow(x$depots)} depósito{?s}",
    "*" = "{nrow(x$clients)} cliente{?s}",
    "*" = "{nrow(x$vehicle_types)} tipo{?s} de veículo"
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
    demand = 0, tw_early = 0, tw_late = Inf,
    service = 0, prize = 0, required = TRUE
  )
  for (col in names(defaults)) {
    if (is.null(data[[col]])) data[[col]] <- defaults[[col]]
  }
  data$required <- as.logical(data$required)
  cols <- names(acc)
  vctrs::vec_rbind(acc, data[cols])
}
