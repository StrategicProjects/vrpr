#ifndef PYVRP_LOGGING_H
#define PYVRP_LOGGING_H

// vrpr replacement (written by tools/vendor.R; upstream's logging.h wraps
// spdlog, which an R package cannot depend on). All logging macros are
// no-ops, matching upstream release builds with logging compiled out.

#define PYVRP_DEBUG(name, ...) (void)0
#define PYVRP_INFO(name, ...) (void)0
#define PYVRP_WARN(name, ...) (void)0
#define PYVRP_ERROR(name, ...) (void)0
#define PYVRP_CRITICAL(name, ...) (void)0

#endif  // PYVRP_LOGGING_H
