#!/usr/bin/env Rscript
# tools/vendor.R — vendoriza o núcleo C++ do PyVRP em src/vendor/pyvrp/.
#
# Baixa o tarball da tag fixada em tools/PYVRP_VERSION, extrai e copia a árvore
# `pyvrp/cpp/` verbatim para src/vendor/pyvrp/, registrando a versão. NÃO compila
# nem altera o build: a ligação cpp11 (substituir bindings.cpp do pybind11 e o
# log spdlog) é um passo manual posterior, faithful ao upstream.
#
# Uso (a partir da raiz do pacote):
#   Rscript tools/vendor.R                # usa tools/PYVRP_VERSION
#   Rscript tools/vendor.R v0.13.4        # versão explícita (não persiste o pino)
#
# Requer apenas base R (utils). Usa {cli} para logs se disponível.

vendor_pyvrp <- function(version = NULL,
                         pkg_root = ".",
                         repo = "PyVRP/PyVRP") {
  have_cli <- requireNamespace("cli", quietly = TRUE)
  inform <- function(msg) if (have_cli) cli::cli_alert_info(msg) else message(msg)
  ok <- function(msg) if (have_cli) cli::cli_alert_success(msg) else message(msg)
  step <- function(msg) if (have_cli) cli::cli_h2(msg) else message("== ", msg)

  version_file <- file.path(pkg_root, "tools", "PYVRP_VERSION")
  if (is.null(version)) {
    if (!file.exists(version_file)) {
      stop("tools/PYVRP_VERSION não encontrado; passe a versão explicitamente.")
    }
    version <- trimws(readLines(version_file, warn = FALSE)[[1]])
  }

  step(sprintf("Vendorizando PyVRP %s", version))

  dest <- file.path(pkg_root, "src", "vendor", "pyvrp")
  url <- sprintf("https://github.com/%s/archive/refs/tags/%s.tar.gz", repo, version)

  tmp <- tempfile(fileext = ".tar.gz")
  exdir <- tempfile("pyvrp-src-")
  on.exit(unlink(c(tmp, exdir), recursive = TRUE, force = TRUE), add = TRUE)

  inform(sprintf("Baixando %s", url))
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)

  inform("Extraindo o tarball")
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  utils::untar(tmp, exdir = exdir)

  # Localiza a árvore .../pyvrp/cpp dentro do tarball extraído.
  cpp_dirs <- list.dirs(exdir, recursive = TRUE, full.names = TRUE)
  cpp_dir <- cpp_dirs[grepl("/pyvrp/cpp$", cpp_dirs)]
  if (length(cpp_dir) != 1) {
    stop("Não foi possível localizar 'pyvrp/cpp' no tarball (encontrados: ",
         length(cpp_dir), ").")
  }

  inform(sprintf("Copiando o núcleo C++ para %s", dest))
  unlink(dest, recursive = TRUE, force = TRUE)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  # Copia o diretório cpp inteiro e o renomeia para o destino estável.
  file.copy(cpp_dir, dirname(dest), recursive = TRUE)
  file.rename(file.path(dirname(dest), "cpp"), dest)

  # Inventário do que foi vendorizado.
  files <- list.files(dest, recursive = TRUE)
  sources <- grep("\\.(h|hpp|cpp)$", files, value = TRUE)
  # bindings.* usam pybind11 e logging.h usa spdlog: serão substituídos no port.
  to_replace <- grep("bindings\\.|logging\\.h$", sources, value = TRUE)

  writeLines(
    c(
      sprintf("source: https://github.com/%s", repo),
      sprintf("tag: %s", version),
      sprintf("vendored_from: %s/pyvrp/cpp", repo),
      sprintf("n_source_files: %d", length(sources)),
      "note: bindings.* (pybind11) e logging.h (spdlog) devem ser substituídos pela camada cpp11."
    ),
    file.path(dest, "VERSION")
  )

  ok(sprintf("PyVRP %s vendorizado: %d arquivos de código em src/vendor/pyvrp/",
             version, length(sources)))
  if (length(to_replace) > 0) {
    msg <- sprintf("A reconciliar manualmente na ligação cpp11: %s",
                   paste(to_replace, collapse = ", "))
    if (have_cli) cli::cli_alert_warning(msg) else message(msg)
  }

  invisible(list(version = version, dest = dest,
                 n_sources = length(sources), to_replace = to_replace))
}

# Execução direta via Rscript.
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  version <- if (length(args) >= 1) args[[1]] else NULL
  vendor_pyvrp(version = version)
}
