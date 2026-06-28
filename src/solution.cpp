// cpp11 binding of CostEvaluator, Solution, Route and RandomNumberGenerator.
//
// Long-lived objects (ProblemData/Solution/CostEvaluator/RNG) travel as external
// pointers. A route's visits are PyVRP location indices (depots first); the
// conversion to "client number" (1..C) is done on the R side. int64 measures
// come back as doubles (< 2^53 in real instances).

#include "measure_bridge.h"
#include "vendor/pyvrp/CostEvaluator.h"
#include "vendor/pyvrp/ProblemData.h"
#include "vendor/pyvrp/RandomNumberGenerator.h"
#include "vendor/pyvrp/Solution.h"

#include <cpp11.hpp>

#include <cstdint>
#include <vector>

using namespace cpp11;
using pyvrp::CostEvaluator;
using pyvrp::ProblemData;
using pyvrp::RandomNumberGenerator;
using pyvrp::Solution;

namespace
{
ProblemData *as_problem_data(SEXP p)
{
    return external_pointer<ProblemData>(p).get();
}
Solution *as_solution(SEXP p) { return external_pointer<Solution>(p).get(); }
CostEvaluator *as_cost_evaluator(SEXP p)
{
    return external_pointer<CostEvaluator>(p).get();
}
RandomNumberGenerator *as_rng(SEXP p)
{
    return external_pointer<RandomNumberGenerator>(p).get();
}

// Converts a PyVRP measure (Measure) to a double to return to R.
template <typename M> double meas(M const &m)
{
    return static_cast<double>(m);
}
}  // namespace

[[cpp11::register]]
SEXP vrpr_rng_create(int seed)
{
    auto *rng = new RandomNumberGenerator(static_cast<std::uint32_t>(seed));
    return external_pointer<RandomNumberGenerator>(rng);
}

[[cpp11::register]]
SEXP vrpr_cost_evaluator_create(doubles load_penalties,
                                double tw_penalty,
                                double dist_penalty)
{
    std::vector<double> const lp(load_penalties.begin(), load_penalties.end());
    auto *ce = new CostEvaluator(lp, tw_penalty, dist_penalty);
    return external_pointer<CostEvaluator>(ce);
}

// Builds a Solution from routes given as location indices.
[[cpp11::register]]
SEXP vrpr_solution_from_routes(SEXP pd, list routes)
{
    auto *data = as_problem_data(pd);

    std::vector<std::vector<size_t>> rts;
    rts.reserve(routes.size());
    for (R_xlen_t r = 0; r < routes.size(); ++r)
    {
        integers visits(routes[r]);
        std::vector<size_t> route;
        route.reserve(visits.size());
        for (R_xlen_t i = 0; i < visits.size(); ++i)
            route.push_back(static_cast<size_t>(visits[i]));
        rts.push_back(std::move(route));
    }

    auto *sol = new Solution(*data, rts);
    return external_pointer<Solution>(sol);
}

[[cpp11::register]]
SEXP vrpr_solution_random(SEXP pd, SEXP rng)
{
    auto *sol = new Solution(*as_problem_data(pd), *as_rng(rng));
    return external_pointer<Solution>(sol);
}

[[cpp11::register]]
list vrpr_solution_summary(SEXP ptr)
{
    auto *sol = as_solution(ptr);
    using namespace cpp11::literals;

    auto const &excess = sol->excessLoad();
    writable::doubles excess_load(static_cast<R_xlen_t>(excess.size()));
    for (size_t i = 0; i != excess.size(); ++i)
        excess_load[i] = meas(excess[i]);

    return writable::list({
        "num_routes"_nm = static_cast<int>(sol->numRoutes()),
        "num_trips"_nm = static_cast<int>(sol->numTrips()),
        "num_clients"_nm = static_cast<int>(sol->numClients()),
        "num_missing_clients"_nm = static_cast<int>(sol->numMissingClients()),
        "is_feasible"_nm = static_cast<bool>(sol->isFeasible()),
        "is_complete"_nm = static_cast<bool>(sol->isComplete()),
        "has_excess_load"_nm = static_cast<bool>(sol->hasExcessLoad()),
        "has_excess_distance"_nm = static_cast<bool>(sol->hasExcessDistance()),
        "has_time_warp"_nm = static_cast<bool>(sol->hasTimeWarp()),
        "distance"_nm = meas(sol->distance()),
        "duration"_nm = meas(sol->duration()),
        "distance_cost"_nm = meas(sol->distanceCost()),
        "duration_cost"_nm = meas(sol->durationCost()),
        "fixed_vehicle_cost"_nm = meas(sol->fixedVehicleCost()),
        "excess_distance"_nm = meas(sol->excessDistance()),
        "excess_load"_nm = excess_load,
        "prizes"_nm = meas(sol->prizes()),
        "uncollected_prizes"_nm = meas(sol->uncollectedPrizes()),
        "time_warp"_nm = meas(sol->timeWarp()),
    });
}

// Per-route detail: visits (location indices), metrics and the schedule (start
// of service and waiting time) per client visit -- useful for VRPTW. num_depots
// distinguishes depots (low indices) from clients in the schedule.
[[cpp11::register]]
list vrpr_solution_routes(SEXP ptr, int num_depots)
{
    auto *sol = as_solution(ptr);
    using namespace cpp11::literals;
    auto const n_dep = static_cast<size_t>(num_depots);

    writable::list out(static_cast<R_xlen_t>(sol->numRoutes()));
    R_xlen_t idx = 0;
    for (auto const &route : sol->routes())
    {
        auto const visits = route.visits();
        writable::integers v(static_cast<R_xlen_t>(visits.size()));
        for (size_t i = 0; i != visits.size(); ++i)
            v[i] = static_cast<int>(visits[i]);

        // Schedule: client entries (location >= num_depots), in order,
        // line up 1:1 with visits().
        writable::doubles start_service(static_cast<R_xlen_t>(visits.size()));
        writable::doubles wait(static_cast<R_xlen_t>(visits.size()));
        R_xlen_t k = 0;
        for (auto const &sv : route.schedule())
            if (sv.location >= n_dep && k < start_service.size())
            {
                start_service[k] = meas(sv.startService);
                wait[k] = meas(sv.waitDuration);
                ++k;
            }

        auto const &delivery = route.delivery();
        double const deliv = delivery.empty() ? 0.0 : meas(delivery[0]);

        out[idx++] = writable::list({
            "visits"_nm = v,
            "vehicle_type"_nm = static_cast<int>(route.vehicleType()),
            "start_depot"_nm = static_cast<int>(route.startDepot()),
            "end_depot"_nm = static_cast<int>(route.endDepot()),
            "distance"_nm = meas(route.distance()),
            "duration"_nm = meas(route.duration()),
            "delivery"_nm = deliv,
            "start_service"_nm = start_service,
            "wait"_nm = wait,
            "is_feasible"_nm = static_cast<bool>(route.isFeasible()),
        });
    }
    return out;
}

// Penalised (smoothed) cost: finite even for infeasible solutions.
[[cpp11::register]]
double vrpr_penalised_cost(SEXP ce, SEXP sol)
{
    return static_cast<double>(
        as_cost_evaluator(ce)->penalisedCost(*as_solution(sol)));
}
