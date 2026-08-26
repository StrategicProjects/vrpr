// cpp11 binding of CostEvaluator, Solution, Route and RandomNumberGenerator.
//
// Long-lived objects (ProblemData/Solution/CostEvaluator/RNG) travel as external
// pointers. Since PyVRP 0.14, routes are sequences of typed activities
// (DEPOT/CLIENT/PICKUP/DELIVERY with a type-relative 0-based index); they cross
// the R boundary as parallel integer vectors `type` and `idx`. int64 measures
// come back as doubles (< 2^53 in real instances).

#include "measure_bridge.h"
#include "vendor/pyvrp/Activity.h"
#include "vendor/pyvrp/CostEvaluator.h"
#include "vendor/pyvrp/ProblemData.h"
#include "vendor/pyvrp/RandomNumberGenerator.h"
#include "vendor/pyvrp/Solution.h"

#include <cpp11.hpp>

#include <cstdint>
#include <vector>

using namespace cpp11;
using pyvrp::Activity;
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

Activity::ActivityType as_activity_type(int type)
{
    switch (type)
    {
        case 0: return Activity::ActivityType::DEPOT;
        case 1: return Activity::ActivityType::CLIENT;
        case 2: return Activity::ActivityType::PICKUP;
        case 3: return Activity::ActivityType::DELIVERY;
        default:
            cpp11::stop("Unknown activity type %d (0=depot, 1=client, "
                        "2=pickup, 3=delivery).",
                        type);
    }
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

// Builds a Solution from routes given as activity lists. Each element of
// `routes` is a list with integer vectors `type` (0=depot/reload, 1=client,
// 2=pickup, 3=delivery) and `idx` (0-based, type-relative); `veh_types` gives
// each route's 0-based vehicle type.
[[cpp11::register]]
SEXP vrpr_solution_from_routes(SEXP pd, list routes, integers veh_types)
{
    auto *data = as_problem_data(pd);

    std::vector<pyvrp::Route> rts;
    rts.reserve(routes.size());
    for (R_xlen_t r = 0; r < routes.size(); ++r)
    {
        list route(routes[r]);
        integers type(route["type"]);
        integers idx(route["idx"]);

        std::vector<Activity> activities;
        activities.reserve(type.size());
        for (R_xlen_t i = 0; i < type.size(); ++i)
            activities.emplace_back(as_activity_type(type[i]),
                                    static_cast<size_t>(idx[i]));

        // Route validates the plan and throws std::invalid_argument on
        // inconsistencies; cpp11 translates that into an R error.
        rts.emplace_back(*data,
                         activities,
                         static_cast<size_t>(veh_types[r]));
    }

    auto *sol = new Solution(*data, std::move(rts));
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
        "num_shipments"_nm = static_cast<int>(sol->numShipments()),
        "num_missing_clients"_nm = static_cast<int>(sol->numMissingClients()),
        "num_missing_groups"_nm = static_cast<int>(sol->numMissingGroups()),
        "num_missing_shipments"_nm
        = static_cast<int>(sol->numMissingShipments()),
        "is_feasible"_nm = static_cast<bool>(sol->isFeasible()),
        "is_complete"_nm = static_cast<bool>(sol->isComplete()),
        "has_excess_load"_nm = static_cast<bool>(sol->hasExcessLoad()),
        "has_excess_distance"_nm = static_cast<bool>(sol->hasExcessDistance()),
        "has_time_warp"_nm = static_cast<bool>(sol->hasTimeWarp()),
        "distance"_nm = meas(sol->distance()),
        "duration"_nm = meas(sol->duration()),
        "overtime"_nm = meas(sol->overtime()),
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

// Per-route detail: the full schedule (typed activities, including the start,
// reload and end depots) plus route-level metrics. The R side turns this into
// tidy tibbles.
[[cpp11::register]]
list vrpr_solution_routes(SEXP ptr)
{
    auto *sol = as_solution(ptr);
    using namespace cpp11::literals;

    writable::list out(static_cast<R_xlen_t>(sol->numRoutes()));
    R_xlen_t r = 0;
    for (auto const &route : sol->routes())
    {
        auto const &schedule = route.schedule();
        auto const n = static_cast<R_xlen_t>(schedule.size());

        writable::integers type(n);
        writable::integers idx(n);
        writable::integers trip(n);
        writable::doubles start_time(n);
        writable::doubles end_time(n);
        writable::doubles wait(n);
        writable::doubles time_warp(n);

        for (R_xlen_t i = 0; i < n; ++i)
        {
            auto const &act = schedule[static_cast<size_t>(i)];
            type[i] = static_cast<int>(act.type());
            idx[i] = static_cast<int>(act.idx());
            trip[i] = static_cast<int>(act.trip());
            start_time[i] = meas(act.startTime());
            end_time[i] = meas(act.endTime());
            wait[i] = meas(act.waitDuration());
            time_warp[i] = meas(act.timeWarp());
        }

        auto const &delivery = route.delivery();
        double const deliv = delivery.empty() ? 0.0 : meas(delivery[0]);

        out[r++] = writable::list({
            "type"_nm = type,
            "idx"_nm = idx,
            "trip"_nm = trip,
            "start_time"_nm = start_time,
            "end_time"_nm = end_time,
            "wait"_nm = wait,
            "time_warp"_nm = time_warp,
            "vehicle_type"_nm = static_cast<int>(route.vehicleType()),
            "start_depot"_nm = static_cast<int>(route.startDepot()),
            "end_depot"_nm = static_cast<int>(route.endDepot()),
            "distance"_nm = meas(route.distance()),
            "duration"_nm = meas(route.duration()),
            "delivery"_nm = deliv,
            "is_feasible"_nm = static_cast<bool>(route.isFeasible()),
        });
    }
    return out;
}

// Unplanned activities (optional clients/shipments not in any route).
[[cpp11::register]]
list vrpr_solution_unplanned(SEXP ptr)
{
    auto *sol = as_solution(ptr);
    using namespace cpp11::literals;

    auto const &unplanned = sol->unplanned();
    auto const n = static_cast<R_xlen_t>(unplanned.size());
    writable::integers type(n);
    writable::integers idx(n);
    for (R_xlen_t i = 0; i < n; ++i)
    {
        type[i] = static_cast<int>(unplanned[static_cast<size_t>(i)].type());
        idx[i] = static_cast<int>(unplanned[static_cast<size_t>(i)].idx());
    }

    return writable::list({"type"_nm = type, "idx"_nm = idx});
}

// Penalised (smoothed) cost: finite even for infeasible solutions.
[[cpp11::register]]
double vrpr_penalised_cost(SEXP ce, SEXP sol)
{
    return static_cast<double>(
        as_cost_evaluator(ce)->penalisedCost(*as_solution(sol)));
}
