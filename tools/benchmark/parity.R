#!/usr/bin/env Rscript
# Benchmark de paridade vrpr vs PyVRP numa instância CVRPLIB.
#
# Baixa uma instância do conjunto X (Uchoa et al.) se ausente, resolve com o vrpr
# e — se houver um Python com PyVRP — também com o PyVRP, e compara os custos com
# o ótimo conhecido (do arquivo .sol).
#
# Uso:  Rscript tools/benchmark/parity.R [instância] [segundos] [seed]
#   ex: Rscript tools/benchmark/parity.R X-n101-k25 10 1
#
# Para a parte PyVRP, defina VRPR_PYVRP_PYTHON com o python que tem pyvrp instalado
# (senão tenta "python3"); se indisponível, compara apenas vrpr vs o ótimo.

suppressMessages(library(vrpr))

# Parser JSON mínimo (evita dependência de {jsonlite}).
jsonlite_min <- function(s) {
  num <- function(key) as.numeric(sub(paste0('.*"', key, '"\\s*:\\s*([0-9.]+).*'), "\\1", s))
  list(cost = num("cost"), iterations = num("iterations"))
}

args <- commandArgs(trailingOnly = TRUE)
instance <- if (length(args) >= 1) args[[1]] else "X-n101-k25"
secs <- if (length(args) >= 2) as.numeric(args[[2]]) else 10
seed <- if (length(args) >= 3) as.integer(args[[3]]) else 1L

here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
if (length(here) == 0 || here == "") here <- "tools/benchmark"
vrp <- file.path(here, paste0(instance, ".vrp"))
sol <- file.path(here, paste0(instance, ".sol"))

base_url <- "https://raw.githubusercontent.com/PyVRP/Instances/main/CVRP"
fetch <- function(f, url) if (!file.exists(f)) utils::download.file(url, f, quiet = TRUE)
fetch(vrp, file.path(base_url, basename(vrp)))
fetch(sol, file.path(base_url, basename(sol)))

bks <- as.numeric(sub(".*[Cc]ost\\s+", "", grep("[Cc]ost", readLines(sol), value = TRUE)[1]))
gap <- function(c) sprintf("%.2f%%", 100 * (c - bks) / bks)

# Número de veículos: usa o do PyVRP read se possível; senão, um teto folgado.
n_veh <- 30L

cli::cli_h1("Paridade vrpr vs PyVRP — {instance} ({secs}s, seed {seed})")
cli::cli_alert_info("Ótimo conhecido (BKS): {bks}")

# --- vrpr ---
m <- read_vrplib(vrp, num_vehicles = n_veh)
t0 <- Sys.time()
res <- vrp_solve(m, stop = max_runtime(secs), seed = seed, display = FALSE)
vrpr_secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cli::cli_alert_success(
  "vrpr:  custo {round(cost(res))}  gap {gap(cost(res))}  \\
   ({res$iterations} iterações em {round(vrpr_secs, 1)}s)"
)

# --- PyVRP (opcional) ---
py <- Sys.getenv("VRPR_PYVRP_PYTHON", unset = "python3")
script <- file.path(here, "pyvrp_side.py")
has_py <- nzchar(Sys.which(py)) &&
  system2(py, c("-c", shQuote("import pyvrp")), stdout = FALSE, stderr = FALSE) == 0
if (has_py && file.exists(script)) {
  out <- system2(py, c(script, vrp, n_veh, secs, seed), stdout = TRUE, stderr = FALSE)
  pj <- jsonlite_min(out[length(out)])
  cli::cli_alert_success(
    "PyVRP: custo {pj$cost}  gap {gap(pj$cost)}  ({pj$iterations} iterações)"
  )
  cli::cli_alert_info(
    "Razão de iterações PyVRP/vrpr: {round(pj$iterations / res$iterations, 1)}x"
  )
} else {
  cli::cli_alert_warning(
    "PyVRP indisponível (defina VRPR_PYVRP_PYTHON). Comparando apenas vrpr vs o ótimo."
  )
}
