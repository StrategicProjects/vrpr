#!/usr/bin/env Rscript
# tools/vendor.R -- vendors PyVRP's C++ core into src/vendor/pyvrp/.
#
# Downloads the tarball of the tag pinned in tools/PYVRP_VERSION, extracts it and
# copies the `pyvrp/cpp/` tree verbatim into src/vendor/pyvrp/, recording the
# version. It does NOT compile or change the build: the cpp11 wiring (replacing
# pybind11's bindings.cpp and the spdlog logging) is a later manual step, kept
# faithful to upstream.
#
# After copying, patch_vendor() applies a small set of portability fixups
# needed by CRAN builders (see the comments in patch_vendor below). Re-run
# checks after re-vendoring: upstream may have fixed (or moved) these spots,
# in which case the patch step warns instead of failing.
#
# Usage (from the package root):
#   Rscript tools/vendor.R                # uses tools/PYVRP_VERSION
#   Rscript tools/vendor.R v0.13.4        # explicit version (does not persist the pin)
#
# Requires only base R (utils). Uses {cli} for logging if available.

# Portability fixups applied on top of the verbatim upstream copy. Each entry
# is checked before substitution; if upstream has changed and a pattern no
# longer matches, we warn (so the fixup can be reviewed) instead of failing.
patch_vendor <- function(dest) {
  warn <- function(msg) {
    if (requireNamespace("cli", quietly = TRUE)) cli::cli_alert_warning(msg)
    else message("WARNING: ", msg)
  }

  sub_in_file <- function(file, old, new, fixed = TRUE, expect = 1L) {
    path <- file.path(dest, file)
    txt <- readLines(path, warn = FALSE)
    hits <- sum(grepl(old, txt, fixed = fixed))
    if (hits != expect) {
      warn(sprintf(
        "patch_vendor: expected %d match(es) of %s in %s, found %d -- review this fixup",
        expect, sQuote(old), file, hits
      ))
      if (hits == 0) return(invisible(FALSE))
    }
    writeLines(gsub(old, new, txt, fixed = fixed), path)
    invisible(TRUE)
  }

  # (1) LLVM >= 23 libc++ dropped transitive includes: std::back_inserter needs
  # an explicit <iterator> (flagged by CRAN's clang23 additional checks).
  # Upstream added the include to LocalSearch.cpp after v0.13.4.
  for (file in c("search/LocalSearch.cpp", "Solution.cpp")) {
    path <- file.path(dest, file)
    txt <- readLines(path, warn = FALSE)
    if (!any(grepl("#include <iterator>", txt, fixed = TRUE))) {
      anchor <- grep("#include <algorithm>", txt, fixed = TRUE)
      if (length(anchor) == 1) {
        txt <- append(
          txt,
          "#include <iterator>  // vrpr: std::back_inserter (libc++ >= 23)",
          after = anchor
        )
        writeLines(txt, path)
      } else {
        warn(sprintf("patch_vendor: no <algorithm> anchor in %s -- add <iterator> manually", file))
      }
    }
  }

  # (2) Apple's MacOSX11.3 SDK (r-release-macos-x86_64 / r-oldrel-macos CRAN
  # builders) ships a libc++ whose <concepts> implements only std::same_as;
  # std::convertible_to is missing and __cpp_lib_concepts is not defined.
  # vrpr_compat.h supplies pyvrp::compat::convertible_to (aliasing the std
  # concept where the concepts library is complete) and we point the vendored
  # headers at it.
  writeLines(vrpr_compat_h, file.path(dest, "vrpr_compat.h"))
  sub_in_file(
    "CostEvaluator.h", "#include \"Solution.h\"",
    "#include \"Solution.h\"\n#include \"vrpr_compat.h\"  // vrpr: std::convertible_to fallback"
  )
  sub_in_file(
    "search/Route.h", "#include \"ProblemData.h\"",
    "#include \"ProblemData.h\"\n#include \"vrpr_compat.h\"  // vrpr: std::convertible_to fallback"
  )
  sub_in_file("CostEvaluator.h", "std::convertible_to", "compat::convertible_to", expect = 3L)
  sub_in_file("search/Route.h", "std::convertible_to", "compat::convertible_to", expect = 3L)

  # (3) Route::Iterator declares only three of the five member typedefs.
  # Pre-C++20 std::iterator_traits (same old libc++ as in (2)) requires all
  # five, otherwise the traits are empty and e.g. the iterator-range vector
  # constructor used by Route::visits() is SFINAE'd away. The two additions
  # match what the C++20 traits deduce (operator* returns Client by value).
  sub_in_file(
    "Route.h", "        using value_type = Client;",
    paste0(
      "        using value_type = Client;\n",
      "        // vrpr: pre-C++20 std::iterator_traits (e.g. the libc++ in Apple's\n",
      "        // MacOSX11.3 SDK) requires all five member typedefs; these two match\n",
      "        // what the C++20 traits deduce (operator* returns Client by value).\n",
      "        using reference = Client;\n",
      "        using pointer = void;"
    )
  )

  invisible(NULL)
}

vrpr_compat_h <- c(
  "#ifndef VRPR_COMPAT_H",
  "#define VRPR_COMPAT_H",
  "",
  "// vrpr addition (not part of upstream PyVRP; written by tools/vendor.R).",
  "//",
  "// Compatibility shim for C++20 <concepts> on older standard libraries still",
  "// used by some CRAN builders. Apple's MacOSX11.3 SDK (used by the",
  "// r-release-macos-x86_64 and r-oldrel-macos builders) ships a libc++ whose",
  "// <concepts> implements only std::same_as: std::convertible_to appears in the",
  "// synopsis comment but is never defined, and the SDK does not define the",
  "// feature-test macro __cpp_lib_concepts. We key on that macro: where the",
  "// concepts library is complete we simply reuse std::convertible_to, otherwise",
  "// we define the C++20 [concept.convertible] wording ourselves in a separate",
  "// namespace (never in namespace std).",
  "//",
  "// tools/vendor.R patches the vendored PyVRP sources to use",
  "// pyvrp::compat::convertible_to instead of std::convertible_to.",
  "",
  "#if defined(__has_include)",
  "#if __has_include(<version>)",
  "#include <version>",
  "#endif",
  "#endif",
  "",
  "#if defined(__cpp_lib_concepts)",
  "#include <concepts>",
  "#else",
  "#include <type_traits>",
  "#include <utility>",
  "#endif",
  "",
  "namespace pyvrp::compat",
  "{",
  "#if defined(__cpp_lib_concepts)",
  "using std::convertible_to;",
  "#else",
  "// C++20 [concept.convertible], as specified in the standard.",
  "template <typename From, typename To>",
  "concept convertible_to = std::is_convertible_v<From, To>",
  "                         && requires { static_cast<To>(std::declval<From>()); };",
  "#endif",
  "}  // namespace pyvrp::compat",
  "",
  "#endif  // VRPR_COMPAT_H"
)

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

  inform("Applying portability fixups (patch_vendor)")
  patch_vendor(dest)

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
      "note: bindings.* (pybind11) and logging.h (spdlog) are replaced by the cpp11 layer.",
      "note: portability fixups applied on top of the verbatim copy (see patch_vendor in tools/vendor.R)."
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
