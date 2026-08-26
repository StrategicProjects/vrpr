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

  # Whole-text substitution, for multi-line anchors.
  sub_in_text <- function(file, old, new, expect = 1L) {
    path <- file.path(dest, file)
    txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
    hits <- length(gregexpr(old, txt, fixed = TRUE)[[1]])
    if (!grepl(old, txt, fixed = TRUE)) hits <- 0L
    if (hits != expect) {
      warn(sprintf(
        "patch_vendor: expected %d match(es) in %s, found %d -- review this fixup",
        expect, file, hits
      ))
      if (hits == 0) return(invisible(FALSE))
    }
    writeLines(gsub(old, new, txt, fixed = TRUE), path)
    invisible(TRUE)
  }

  # (0) Upstream's logging.h wraps spdlog, which R packages cannot depend on.
  # Replace it with no-op macro definitions (logging is a debug aid upstream;
  # release wheels compile it out via PYVRP_LOG_LEVEL anyway).
  if (file.exists(file.path(dest, "logging.h"))) {
    writeLines(vrpr_logging_h, file.path(dest, "logging.h"))
  }

  # Inserts `#include <header>` into `file` (alphabetically within its block of
  # <...> includes) unless already present.
  ensure_std_include <- function(file, header) {
    path <- file.path(dest, file)
    txt <- readLines(path, warn = FALSE)
    line <- sprintf("#include <%s>", header)
    if (any(grepl(line, txt, fixed = TRUE))) {
      return(invisible(FALSE))
    }
    std <- grep("^#include <", txt)
    if (length(std) == 0) {
      warn(sprintf("patch_vendor: no <...> include block in %s -- add %s manually",
                   file, line))
      return(invisible(FALSE))
    }
    line <- paste0(line, "  // vrpr: missing on older standard libraries")
    before <- std[txt[std] > line]
    at <- if (length(before) > 0) min(before) - 1L else max(std)
    writeLines(append(txt, line, after = at), path)
    invisible(TRUE)
  }

  # (1) Missing standard includes. Newer libc++/libstdc++ provide these
  # transitively (which is why upstream compiles), but LLVM >= 23 libc++
  # (CRAN's clang23 checks) and the old libc++ in Apple's MacOSX11.3 SDK do
  # not. Verified by compiling every TU against the MacOSX11.3 SDK headers.
  ensure_std_include("Solution.cpp", "iterator")       # std::back_inserter
  ensure_std_include("search/LocalSearch.cpp", "iterator")
  ensure_std_include("Client.h", "optional")           # std::optional group
  ensure_std_include("Shipment.h", "string")           # std::string ctor arg
  ensure_std_include("Shipment.h", "vector")           # std::vector<Load>

  # (2) Apple's MacOSX11.3 SDK (r-release-macos-x86_64 / r-oldrel-macos CRAN
  # builders) ships a libc++ whose <concepts> implements only std::same_as;
  # std::convertible_to is missing and __cpp_lib_concepts is not defined.
  # vrpr_compat.h supplies pyvrp::compat::convertible_to (aliasing the std
  # concept where the concepts library is complete) and we point the vendored
  # headers at it.
  writeLines(vrpr_compat_h, file.path(dest, "vrpr_compat.h"))
  sub_in_file(
    "CostEvaluator.h", "#include \"Measure.h\"",
    "#include \"Measure.h\"\n#include \"vrpr_compat.h\"  // vrpr: portability shim"
  )
  sub_in_file(
    "search/Route.h", "#include \"ProblemData.h\"",
    "#include \"ProblemData.h\"\n#include \"vrpr_compat.h\"  // vrpr: portability shim"
  )
  sub_in_file("CostEvaluator.h", "std::convertible_to", "compat::convertible_to", expect = 2L)
  sub_in_file("search/Route.h", "std::convertible_to", "compat::convertible_to", expect = 5L)

  # (3) <format> does not exist in older standard libraries (Apple's MacOSX11.3
  # SDK has none; libstdc++ only ships it from GCC 13). The vendored core only
  # uses it for a std::formatter<Measure> specialisation that nothing in the
  # compiled sources calls, so guard both the include and the specialisation
  # behind the feature-test macro.
  sub_in_text(
    "Measure.h", "#include <format>",
    paste0(
      "#if defined(__has_include)\n",
      "#if __has_include(<version>)\n",
      "#include <version>\n",
      "#endif\n",
      "#endif\n",
      "#if defined(__cpp_lib_format)  // vrpr: <format> is missing on older stdlibs\n",
      "#include <format>\n",
      "#endif"
    )
  )
  sub_in_text(
    "Measure.h",
    paste0(
      "template <pyvrp::MeasureType Type, pyvrp::NumberType Value>\n",
      "struct std::formatter<pyvrp::Measure<Type, Value>> : std::formatter<Value>\n",
      "{\n",
      "    auto format(pyvrp::Measure<Type, Value> const measure, auto &ctx) const\n",
      "    {\n",
      "        return std::formatter<Value>::format(measure.get(), ctx);\n",
      "    }\n",
      "};"
    ),
    paste0(
      "#if defined(__cpp_lib_format)  // vrpr: guarded with the include above\n",
      "template <pyvrp::MeasureType Type, pyvrp::NumberType Value>\n",
      "struct std::formatter<pyvrp::Measure<Type, Value>> : std::formatter<Value>\n",
      "{\n",
      "    auto format(pyvrp::Measure<Type, Value> const measure, auto &ctx) const\n",
      "    {\n",
      "        return std::formatter<Value>::format(measure.get(), ctx);\n",
      "    }\n",
      "};\n",
      "#endif  // __cpp_lib_format"
    )
  )

  # (4) <ranges> does not exist in older standard libraries either; the only
  # use is a compile-time sanity static_assert in Solution.cpp. Guard it (and
  # a proper <ranges> include, which upstream relies on transitively) behind
  # the feature-test macro.
  sub_in_text(
    "Solution.cpp", "#include <numeric>",
    paste0(
      "#include <numeric>\n",
      "#if defined(__cpp_lib_ranges)  // vrpr: <ranges> is missing on older stdlibs\n",
      "#include <ranges>\n",
      "#endif"
    )
  )
  sub_in_text(
    "Solution.cpp",
    "        static_assert(std::ranges::input_range<Route>);",
    paste0(
      "#if defined(__cpp_lib_ranges)  // vrpr: guarded with the include above\n",
      "        static_assert(std::ranges::input_range<Route>);\n",
      "#endif"
    )
  )

  invisible(NULL)
}

vrpr_logging_h <- c(
  "#ifndef PYVRP_LOGGING_H",
  "#define PYVRP_LOGGING_H",
  "",
  "// vrpr replacement (written by tools/vendor.R; upstream's logging.h wraps",
  "// spdlog, which an R package cannot depend on). All logging macros are",
  "// no-ops, matching upstream release builds with logging compiled out.",
  "",
  "#define PYVRP_DEBUG(name, ...) (void)0",
  "#define PYVRP_INFO(name, ...) (void)0",
  "#define PYVRP_WARN(name, ...) (void)0",
  "#define PYVRP_ERROR(name, ...) (void)0",
  "#define PYVRP_CRITICAL(name, ...) (void)0",
  "",
  "#endif  // PYVRP_LOGGING_H"
)

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
