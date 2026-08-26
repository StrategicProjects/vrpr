// cpp11 binding of PyVRP's local-search engine (search/).
//
// Bundles into a single persistent object (LSBundle, exposed as an external
// pointer) everything local search needs: a copy of the data, the RNG, the
// PerturbationManager, the operators and the LocalSearch itself. This way the
// ILS loop reuses the same engine across iterations.
//
// LocalSearch::operator()(sol, ce, exhaustive=false) is ONE ILS iteration
// (perturb + local search to a local optimum). With exhaustive=true it does not
// perturb (pure descent).

#include "measure_bridge.h"
#include "vendor/pyvrp/CostEvaluator.h"
#include "vendor/pyvrp/ProblemData.h"
#include "vendor/pyvrp/RandomNumberGenerator.h"
#include "vendor/pyvrp/Solution.h"
#include "vendor/pyvrp/search/InsertOptionalClient.h"
#include "vendor/pyvrp/search/InsertOptionalShipment.h"
#include "vendor/pyvrp/search/LocalSearch.h"
#include "vendor/pyvrp/search/LocalSearchOperator.h"
#include "vendor/pyvrp/search/PerturbationManager.h"
#include "vendor/pyvrp/search/Relocate.h"
#include "vendor/pyvrp/search/RelocateAlternative.h"
#include "vendor/pyvrp/search/RelocateDelivery.h"
#include "vendor/pyvrp/search/RelocatePickup.h"
#include "vendor/pyvrp/search/RelocateShipment.h"
#include "vendor/pyvrp/search/RelocateWithDepot.h"
#include "vendor/pyvrp/search/RemoveAdjacentDepot.h"
#include "vendor/pyvrp/search/RemoveOptionalClient.h"
#include "vendor/pyvrp/search/RemoveOptionalShipment.h"
#include "vendor/pyvrp/search/ReplaceGroup.h"
#include "vendor/pyvrp/search/ReplaceOptionalClient.h"
#include "vendor/pyvrp/search/ReplaceOptionalShipment.h"
#include "vendor/pyvrp/search/SearchSpace.h"
#include "vendor/pyvrp/search/Swap.h"
#include "vendor/pyvrp/search/SwapTails.h"
#include "vendor/pyvrp/search/neighbourhood.h"

#include <cpp11.hpp>

#include <cstdint>
#include <memory>
#include <utility>
#include <vector>

using namespace cpp11;
using pyvrp::CostEvaluator;
using pyvrp::ProblemData;
using pyvrp::RandomNumberGenerator;
using pyvrp::Solution;
using pyvrp::search::BinaryOperator;
using pyvrp::search::LocalSearch;
using pyvrp::search::NeighbourhoodParams;
using pyvrp::search::PerturbationManager;
using pyvrp::search::PerturbationParams;
using pyvrp::search::UnaryOperator;

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

// Everything local search needs, with lifetimes tied together.
struct LSBundle
{
    std::shared_ptr<ProblemData> data;
    std::shared_ptr<RandomNumberGenerator> rng;
    PerturbationManager pm;
    std::vector<std::unique_ptr<UnaryOperator>> unary_ops;
    std::vector<std::unique_ptr<BinaryOperator>> binary_ops;
    LocalSearch ls;

    LSBundle(ProblemData const &d,
             size_t num_neighbours,
             std::uint32_t seed,
             size_t min_pert,
             size_t max_pert)
        : data(std::make_shared<ProblemData>(d)),
          rng(std::make_shared<RandomNumberGenerator>(seed)),
          pm(PerturbationParams(min_pert, max_pert)),
          ls(*data,
             pyvrp::search::computeNeighbours(
                 *data, NeighbourhoodParams(0.2, num_neighbours, true)),
             pm)
    {
        // PyVRP's default operator set (pyvrp.search.OPERATORS), in the same
        // registration order. Each operator is added only when it supports the
        // instance at hand.
        namespace ps = pyvrp::search;
        add<ps::Relocate<1>>();
        add<ps::Relocate<2>>();
        add<ps::Swap<1, 1>>();
        add<ps::Swap<2, 1>>();
        add<ps::Swap<2, 2>>();
        add<ps::SwapTails>();
        add<ps::RelocateAlternative>();
        add<ps::RelocatePickup>();
        add<ps::RelocateDelivery>();
        add<ps::RelocateWithDepot>();
        add<ps::RemoveAdjacentDepot>();
        add<ps::RemoveOptionalClient>();
        add<ps::InsertOptionalClient>();
        add<ps::ReplaceOptionalClient>();
        add<ps::RemoveOptionalShipment>();
        add<ps::InsertOptionalShipment>();
        add<ps::ReplaceOptionalShipment>();
        add<ps::ReplaceGroup>();
        add<ps::RelocateShipment>();
    }

    template <typename Op> void add()
    {
        if (!Op::supports(*data))
            return;
        auto op = std::make_unique<Op>(*data);
        ls.addOperator(*op);
        store(std::move(op));
    }

    template <typename Op>
    void store(std::unique_ptr<Op> op)
    {
        if constexpr (std::is_base_of_v<UnaryOperator, Op>)
            unary_ops.push_back(std::move(op));
        else
            binary_ops.push_back(std::move(op));
    }
};

LSBundle *as_bundle(SEXP p) { return external_pointer<LSBundle>(p).get(); }
}  // namespace

[[cpp11::register]]
SEXP vrpr_local_search_create(SEXP pd,
                              int num_neighbours,
                              int seed,
                              int min_perturbations,
                              int max_perturbations)
{
    auto *data = as_problem_data(pd);
    auto *bundle = new LSBundle(*data,
                                static_cast<size_t>(num_neighbours),
                                static_cast<std::uint32_t>(seed),
                                static_cast<size_t>(min_perturbations),
                                static_cast<size_t>(max_perturbations));
    return external_pointer<LSBundle>(bundle);
}

// Runs local search on `sol`, returning a new (ideally better) solution.
// exhaustive=false applies a perturbation first (one ILS iteration); true is pure
// descent. shuffle=true randomises the order of moves/perturbations before running.
[[cpp11::register]]
SEXP vrpr_local_search_run(SEXP bundle, SEXP sol, SEXP ce, bool exhaustive, bool shuffle)
{
    auto *b = as_bundle(bundle);
    if (shuffle)
        b->ls.shuffle(*b->rng);

    auto improved = b->ls(*as_solution(sol), *as_cost_evaluator(ce), exhaustive);
    auto *out = new Solution(std::move(improved));
    return external_pointer<Solution>(out);
}

// Number of active operators (for inspection/diagnostics).
[[cpp11::register]]
list vrpr_local_search_info(SEXP bundle)
{
    auto *b = as_bundle(bundle);
    using namespace cpp11::literals;
    return writable::list({
        "num_unary_operators"_nm = static_cast<int>(b->unary_ops.size()),
        "num_binary_operators"_nm = static_cast<int>(b->binary_ops.size()),
    });
}
