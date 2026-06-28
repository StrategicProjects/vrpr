#!/usr/bin/env Rscript
# tools/vendor.R -- vendors PyVRP's C++ core into src/vendor/pyvrp/.
#
# Downloads the tarball of the tag pinned in tools/PYVRP_VERSION, extracts it and
# copies the `pyvrp/cpp/` tree verbatim into src/vendor/pyvrp/, recording the
# version. It does NOT compile or change the build: the cpp11 wiring (replacing
# pybind11's bindings.cpp and the spdlog logging) is a later manual step, kept
# faithful to upstream.
#
# Usage (from the package root):
#   Rscript tools/vendor.R                # uses tools/PYVRP_VERSION
#   Rscript tools/vendor.R v0.13.4        # explicit version (does not persist the pin)
#
# Requires only base R (utils). Uses {cli} for logging if available.

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
      stop("tools/PYVRP_VERSION not found; pass the version explicitly.")
    }
    version <- trimws(readLines(version_file, warn = FALSE)[[1]])
  }

  step(sprintf("Vendoring PyVRP %s", version))

  dest <- file.path(pkg_root, "src", "vendor", "pyvrp")
  url <- sprintf("https://github.com/%s/archive/refs/tags/%s.tar.gz", repo, version)

  tmp <- tempfile(fileext = ".tar.gz")
  exdir <- tempfile("pyvrp-src-")
  on.exit(unlink(c(tmp, exdir), recursive = TRUE, force = TRUE), add = TRUE)

  inform(sprintf("Downloading %s", url))
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)

  inform("Extracting the tarball")
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  utils::untar(tmp, exdir = exdir)

  # Locate the .../pyvrp/cpp tree inside the extracted tarball.
  cpp_dirs <- list.dirs(exdir, recursive = TRUE, full.names = TRUE)
  cpp_dir <- cpp_dirs[grepl("/pyvrp/cpp$", cpp_dirs)]
  if (length(cpp_dir) != 1) {
    stop("Could not locate 'pyvrp/cpp' in the tarball (found: ",
         length(cpp_dir), ").")
  }

  inform(sprintf("Copying the C++ core to %s", dest))
  unlink(dest, recursive = TRUE, force = TRUE)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  # Copy the whole cpp directory and rename it to the stable destination.
  file.copy(cpp_dir, dirname(dest), recursive = TRUE)
  file.rename(file.path(dirname(dest), "cpp"), dest)

  # Inventory of what was vendored.
  files <- list.files(dest, recursive = TRUE)
  sources <- grep("\\.(h|hpp|cpp)$", files, value = TRUE)
  # bindings.* use pybind11 and logging.h uses spdlog: replaced in the port.
  to_replace <- grep("bindings\\.|logging\\.h$", sources, value = TRUE)

  writeLines(
    c(
      sprintf("source: https://github.com/%s", repo),
      sprintf("tag: %s", version),
      sprintf("vendored_from: %s/pyvrp/cpp", repo),
      sprintf("n_source_files: %d", length(sources)),
      "note: bindings.* (pybind11) and logging.h (spdlog) are replaced by the cpp11 layer."
    ),
    # Do NOT use the name "VERSION": on a case-insensitive FS (macOS) it would
    # clash with the C++20 standard header <version> when vendor/pyvrp is on -I.
    file.path(dest, "pyvrp_version.txt")
  )

  ok(sprintf("Vendored PyVRP %s: %d source files under src/vendor/pyvrp/",
             version, length(sources)))
  if (length(to_replace) > 0) {
    msg <- sprintf("To reconcile manually in the cpp11 wiring: %s",
                   paste(to_replace, collapse = ", "))
    if (have_cli) cli::cli_alert_warning(msg) else message(msg)
  }

  invisible(list(version = version, dest = dest,
                 n_sources = length(sources), to_replace = to_replace))
}

# Direct execution via Rscript.
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  version <- if (length(args) >= 1) args[[1]] else NULL
  vendor_pyvrp(version = version)
}
