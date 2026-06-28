# Visualização das rotas com {ggplot2} (substitui o plotting matplotlib do PyVRP).

#' Plotar a solução de um resultado VRP
#'
#' Desenha depósitos, clientes e as rotas (uma cor por rota) sobre as coordenadas
#' da instância. Clientes opcionais não visitados (prize-collecting) aparecem como
#' círculos vazados.
#'
#' @param x Um [vrp_solve()] resultado.
#' @param show_clients Rotular os clientes não visitados? (sempre desenhados).
#' @param ... Não usado.
#' @return Um objeto `ggplot`.
#' @export
plot.vrpr_result <- function(x, show_clients = TRUE, ...) {
  rlang::check_installed("ggplot2", "para plotar soluções vrpr.")
  locs <- x$problem_data$locations
  if (is.null(locs)) {
    cli::cli_abort("Sem coordenadas para plotar (problem_data sem {.field locations}).")
  }

  depots <- locs[locs$kind == "depot", , drop = FALSE]
  clients <- locs[locs$kind == "client", , drop = FALSE]
  rt <- routes(x)

  paths <- route_paths(rt, depots, clients)
  visited <- unique(rt$client)
  clients$visited <- clients$index %in% visited

  custo <- if (is.finite(x$cost)) round(x$cost) else NA
  subtitulo <- sprintf(
    "%d rota(s) · %d cliente(s) · custo %s%s",
    x$solution$summary$num_routes, nrow(clients),
    if (is.na(custo)) "—" else custo,
    if (x$is_feasible) "" else " · inviável"
  )

  p <- ggplot2::ggplot()
  if (nrow(paths) > 0) {
    p <- p + ggplot2::geom_path(
      data = paths,
      ggplot2::aes(x = .data$x, y = .data$y,
                   group = .data$route_id, colour = factor(.data$route_id)),
      linewidth = 0.6, alpha = 0.8
    )
  }
  p +
    ggplot2::geom_point(
      data = clients,
      ggplot2::aes(x = .data$x, y = .data$y, shape = .data$visited),
      size = 2.2, colour = "grey25"
    ) +
    ggplot2::geom_point(
      data = depots, ggplot2::aes(x = .data$x, y = .data$y),
      shape = 15, size = 4, colour = "black"
    ) +
    ggplot2::scale_shape_manual(
      values = c(`TRUE` = 19, `FALSE` = 1),
      labels = c(`TRUE` = "visitado", `FALSE` = "não visitado"),
      name = NULL, drop = FALSE
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(title = "Solução VRP", subtitle = subtitulo,
                  x = NULL, y = NULL, colour = "rota") +
    ggplot2::theme_minimal()
}

#' Plotar um modelo VRP (apenas depósitos e clientes)
#'
#' @param x Um [vrp_model()].
#' @param ... Não usado.
#' @return Um objeto `ggplot`.
#' @export
plot.vrpr_model <- function(x, ...) {
  rlang::check_installed("ggplot2", "para plotar modelos vrpr.")
  depots <- x$depots
  clients <- x$clients
  ggplot2::ggplot() +
    ggplot2::geom_point(
      data = clients, ggplot2::aes(x = .data$x, y = .data$y),
      size = 2.2, colour = "grey25"
    ) +
    ggplot2::geom_point(
      data = depots, ggplot2::aes(x = .data$x, y = .data$y),
      shape = 15, size = 4, colour = "black"
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Modelo VRP",
      subtitle = sprintf("%d depósito(s) · %d cliente(s)",
                         nrow(depots), nrow(clients)),
      x = NULL, y = NULL
    ) +
    ggplot2::theme_minimal()
}

# Monta o caminho de cada rota: depósito -> clientes (na ordem) -> depósito.
route_paths <- function(rt, depots, clients) {
  if (nrow(rt) == 0) {
    return(tibble::tibble(x = double(), y = double(),
                          route_id = integer(), ord = integer()))
  }
  pieces <- lapply(split(rt, rt$route_id), function(r) {
    r <- r[order(r$position), , drop = FALSE]
    d <- depots[match(r$depot[1], depots$index), c("x", "y")]
    cs <- clients[match(r$client, clients$index), c("x", "y")]
    xy <- rbind(d, cs, d) # fecha o ciclo no depósito
    tibble::tibble(
      x = xy$x, y = xy$y,
      route_id = r$route_id[1], ord = seq_len(nrow(xy))
    )
  })
  vctrs::vec_rbind(!!!pieces)
}
