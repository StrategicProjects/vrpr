# Route visualisation with {ggplot2} (replaces PyVRP's matplotlib plotting).

#' Plot the solution of a VRP result
#'
#' Draws depots, clients and the routes (one colour per route) over the
#' instance coordinates. Unvisited optional clients (prize-collecting) appear as
#' hollow circles.
#'
#' @param x A [vrp_solve()] result.
#' @param show_clients Reserved; clients are always drawn.
#' @param ... Unused.
#' @return A `ggplot` object.
#' @export
plot.vrpr_result <- function(x, show_clients = TRUE, ...) {
  rlang::check_installed("ggplot2", "to plot vrpr solutions.")
  locs <- x$problem_data$locations
  if (is.null(locs)) {
    cli::cli_abort("No coordinates to plot (problem_data has no {.field locations}).")
  }

  depots <- locs[locs$kind == "depot", , drop = FALSE]
  clients <- locs[locs$kind == "client", , drop = FALSE]
  rt <- routes(x)

  paths <- route_paths(rt, depots, clients)
  visited <- unique(rt$client)
  clients$visited <- clients$index %in% visited

  cost_lbl <- if (is.finite(x$cost)) round(x$cost) else NA
  subtitle <- sprintf(
    "%d route(s) - %d client(s) - cost %s%s",
    x$solution$summary$num_routes, nrow(clients),
    if (is.na(cost_lbl)) "-" else cost_lbl,
    if (x$is_feasible) "" else " - infeasible"
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
      labels = c(`TRUE` = "visited", `FALSE` = "not visited"),
      name = NULL, drop = FALSE
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(title = "VRP solution", subtitle = subtitle,
                  x = NULL, y = NULL, colour = "route") +
    ggplot2::theme_minimal()
}

#' Plot a VRP model (depots and clients only)
#'
#' @param x A [vrp_model()].
#' @param ... Unused.
#' @return A `ggplot` object.
#' @export
plot.vrpr_model <- function(x, ...) {
  rlang::check_installed("ggplot2", "to plot vrpr models.")
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
      title = "VRP model",
      subtitle = sprintf("%d depot(s) - %d client(s)",
                         nrow(depots), nrow(clients)),
      x = NULL, y = NULL
    ) +
    ggplot2::theme_minimal()
}

# Builds each route's path: depot -> clients (in order) -> depot.
route_paths <- function(rt, depots, clients) {
  if (nrow(rt) == 0) {
    return(tibble::tibble(x = double(), y = double(),
                          route_id = integer(), ord = integer()))
  }
  pieces <- lapply(split(rt, rt$route_id), function(r) {
    r <- r[order(r$position), , drop = FALSE]
    d <- depots[match(r$depot[1], depots$index), c("x", "y")]
    cs <- clients[match(r$client, clients$index), c("x", "y")]
    xy <- rbind(d, cs, d) # closes the loop at the depot
    tibble::tibble(
      x = xy$x, y = xy$y,
      route_id = r$route_id[1], ord = seq_len(nrow(xy))
    )
  })
  vctrs::vec_rbind(!!!pieces)
}
