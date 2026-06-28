// Binding cpp11 do motor de busca local (search/) do PyVRP.
//
// Empacota num único objeto persistente (LSBundle, exposto como external pointer)
// tudo que a busca local precisa: uma cópia dos dados, o RNG, o PerturbationManager,
// o conjunto de operadores (de nó e de rota) e o LocalSearch em si. Assim o futuro
// laço ILS reutiliza o mesmo motor entre iterações.
//
// LocalSearch::operator()(sol, ce, exhaustive=false) é UMA iteração ILS (perturba +
// busca local até o ótimo local). Com exhaustive=true não perturba (descida pura).

#include "measure_bridge.h"
#include "vendor/pyvrp/CostEvaluator.h"
#include "vendor/pyvrp/ProblemData.h"
#include "vendor/pyvrp/RandomNumberGenerator.h"
#include "vendor/pyvrp/Solution.h"
#include "vendor/pyvrp/search/Exchange.h"
#include "vendor/pyvrp/search/LocalSearch.h"
#include "vendor/pyvrp/search/LocalSearchOperator.h"
#include "vendor/pyvrp/search/PerturbationManager.h"
#include "vendor/pyvrp/search/RelocateWithDepot.h"
#include "vendor/pyvrp/search/SearchSpace.h"
#include "vendor/pyvrp/search/SwapRoutes.h"
#include "vendor/pyvrp/search/SwapStar.h"
#include "vendor/pyvrp/search/SwapTails.h"

#include <cpp11.hpp>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <utility>
#include <vector>

using namespace cpp11;
using pyvrp::CostEvaluator;
using pyvrp::ProblemData;
using pyvrp::RandomNumberGenerator;
using pyvrp::Solution;
using pyvrp::search::LocalSearch;
using pyvrp::search::NodeOperator;
using pyvrp::search::PerturbationManager;
using pyvrp::search::PerturbationParams;
using pyvrp::search::RouteOperator;
using pyvrp::search::SearchSpace;

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

// Vizinhança granular: para cada cliente, os k clientes mais próximos por
// distância (perfil 0). Depósitos não têm vizinhos. Espelha o papel do
// compute_neighbours do PyVRP (versão simples, por proximidade).
SearchSpace::Neighbours compute_neighbours(ProblemData const &data, size_t k)
{
    auto const num_loc = data.numLocations();
    auto const num_dep = data.numDepots();
    auto const &dist = data.distanceMatrix(0);

    SearchSpace::Neighbours nb(num_loc);
    for (size_t i = num_dep; i < num_loc; ++i)
    {
        std::vector<std::pair<std::int64_t, size_t>> cand;
        cand.reserve(num_loc - num_dep);
        for (size_t j = num_dep; j < num_loc; ++j)
            if (j != i)
                cand.emplace_back(static_cast<std::int64_t>(dist(i, j)), j);

        auto const kk = std::min(k, cand.size());
        std::partial_sort(cand.begin(), cand.begin() + kk, cand.end());

        std::vector<size_t> row;
        row.reserve(kk);
        for (size_t t = 0; t != kk; ++t)
            row.push_back(cand[t].second);
        std::sort(row.begin(), row.end());  // ordem estável dos vizinhos
        nb[i] = std::move(row);
    }
    return nb;
}

// Tudo que a busca local precisa, com tempos de vida amarrados juntos.
struct LSBundle
{
    std::shared_ptr<ProblemData> data;
    std::shared_ptr<RandomNumberGenerator> rng;
    PerturbationManager pm;
    std::vector<std::unique_ptr<NodeOperator>> node_ops;
    std::vector<std::unique_ptr<RouteOperator>> route_ops;
    LocalSearch ls;

    LSBundle(ProblemData const &d,
             size_t num_neighbours,
             std::uint32_t seed,
             size_t min_pert,
             size_t max_pert)
        : data(std::make_shared<ProblemData>(d)),
          rng(std::make_shared<RandomNumberGenerator>(seed)),
          pm(PerturbationParams(min_pert, max_pert)),
          ls(*data, compute_neighbours(*data, num_neighbours), pm)
    {
        // Operadores de nó: família Exchange<N,M> (relocate/swap) + SwapTails (2-opt*).
        add_node<pyvrp::search::Exchange<1, 0>>();
        add_node<pyvrp::search::Exchange<2, 0>>();
        add_node<pyvrp::search::Exchange<3, 0>>();
        add_node<pyvrp::search::Exchange<1, 1>>();
        add_node<pyvrp::search::Exchange<2, 1>>();
        add_node<pyvrp::search::Exchange<3, 1>>();
        add_node<pyvrp::search::Exchange<2, 2>>();
        add_node<pyvrp::search::Exchange<3, 2>>();
        add_node<pyvrp::search::Exchange<3, 3>>();
        add_node<pyvrp::search::SwapTails>();
        add_node<pyvrp::search::RelocateWithDepot>();  // só ativo c/ reload depots

        // Operadores de rota.
        add_route<pyvrp::search::SwapStar>();
        add_route<pyvrp::search::SwapRoutes>();
    }

    template <typename Op> void add_node()
    {
        if (!pyvrp::search::supports<Op>(*data))
            return;
        auto op = std::make_unique<Op>(*data);
        ls.addNodeOperator(*op);
        node_ops.push_back(std::move(op));
    }

    template <typename Op> void add_route()
    {
        if (!pyvrp::search::supports<Op>(*data))
            return;
        auto op = std::make_unique<Op>(*data);
        ls.addRouteOperator(*op);
        route_ops.push_back(std::move(op));
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

// Roda a busca local sobre `sol`, devolvendo uma nova solução (idealmente melhor).
// exhaustive=false aplica uma perturbação antes (uma iteração ILS); true é descida
// pura. shuffle=true randomiza a ordem dos movimentos/perturbações antes de rodar.
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

// Número de operadores ativos (para inspeção/diagnóstico).
[[cpp11::register]]
list vrpr_local_search_info(SEXP bundle)
{
    auto *b = as_bundle(bundle);
    using namespace cpp11::literals;
    return writable::list({
        "num_node_operators"_nm = static_cast<int>(b->node_ops.size()),
        "num_route_operators"_nm = static_cast<int>(b->route_ops.size()),
    });
}
