# Gerenciador de penalidades adaptativo (port do PenaltyManager do PyVRP).
#
# Mantém pesos de penalidade para carga, time warp e distância, e os ajusta com
# base na fração recente de soluções viáveis em cada dimensão: penalidade sobe
# quando há viabilidade de menos (restrição fraca) e desce quando há de mais
# (restrição forte demais). Objeto mutável baseado em environment.

new_penalty_manager <- function(num_load_dims = 1L,
                                init_load = 20,
                                init_tw = 6,
                                init_dist = 6,
                                penalty_increase = 1.2,
                                penalty_decrease = 0.85,
                                target_feasible = 0.43,
                                num_between_updates = 50L,
                                min_penalty = 0.1,
                                max_penalty = 1e5) {
  self <- new.env(parent = emptyenv())
  self$num_load_dims <- max(1L, as.integer(num_load_dims))
  self$load <- init_load
  self$tw <- init_tw
  self$dist <- init_dist
  self$buf_load <- logical(0)
  self$buf_tw <- logical(0)
  self$buf_dist <- logical(0)
  self$params <- list(
    inc = penalty_increase, dec = penalty_decrease,
    target = target_feasible, n = as.integer(num_between_updates),
    min = min_penalty, max = max_penalty
  )
  class(self) <- "vrpr_penalty_manager"
  self
}

# Ajusta um peso a partir da fração de viabilidade recente.
adjust_penalty <- function(value, feasible_buffer, p) {
  frac <- mean(feasible_buffer)
  if (frac < p$target - 0.05) {
    value <- value * p$inc
  } else if (frac > p$target + 0.05) {
    value <- value * p$dec
  }
  max(p$min, min(p$max, value))
}

# Registra a viabilidade de uma solução (por dimensão) e atualiza os pesos a cada
# `n` registros.
pm_register <- function(pm, load_feasible, tw_feasible, dist_feasible) {
  pm$buf_load <- c(pm$buf_load, load_feasible)
  pm$buf_tw <- c(pm$buf_tw, tw_feasible)
  pm$buf_dist <- c(pm$buf_dist, dist_feasible)

  if (length(pm$buf_load) >= pm$params$n) {
    pm$load <- adjust_penalty(pm$load, pm$buf_load, pm$params)
    pm$tw <- adjust_penalty(pm$tw, pm$buf_tw, pm$params)
    pm$dist <- adjust_penalty(pm$dist, pm$buf_dist, pm$params)
    pm$buf_load <- logical(0)
    pm$buf_tw <- logical(0)
    pm$buf_dist <- logical(0)
  }
  invisible(pm)
}

# Avaliador de custo com os pesos correntes.
pm_cost_evaluator <- function(pm) {
  vrp_cost_evaluator(
    load_penalties = rep(pm$load, pm$num_load_dims),
    tw_penalty = pm$tw,
    dist_penalty = pm$dist
  )
}
