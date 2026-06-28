// Binding cpp11 do ProblemData do PyVRP.
//
// Constrói um pyvrp::ProblemData a partir de vetores/matrizes de R (medidas como
// double, ver measure_bridge.h) e o devolve como external pointer com finalizer.
// Cobre o caso CVRP/VRPTW de uma dimensão de carga; variantes multidimensionais
// virão depois (ver plano.md).

#include "measure_bridge.h"
#include "vendor/pyvrp/ProblemData.h"

#include <cpp11.hpp>

#include <limits>
#include <optional>
#include <string>
#include <vector>

using namespace cpp11;
using pyvrp::ProblemData;

namespace
{
// Constrói uma Matrix<T> do PyVRP (row-major) a partir de uma matriz de R.
template <typename T>
pyvrp::Matrix<T> to_matrix(doubles_matrix<> const &m, char const *what)
{
    auto const n = static_cast<std::size_t>(m.nrow());
    if (static_cast<std::size_t>(m.ncol()) != n)
        cpp11::stop("%s deve ser quadrada.", what);

    std::vector<T> data;
    data.reserve(n * n);
    for (std::size_t i = 0; i < n; ++i)
        for (std::size_t j = 0; j < n; ++j)
            data.push_back(vrpr::as_i64(m(i, j), what));

    return pyvrp::Matrix<T>(std::move(data), n, n);
}
}  // namespace

// Cria um ProblemData. Localizações são ordenadas com os depósitos primeiro
// (índices baixos), depois os clientes, conforme a convenção do PyVRP.
[[cpp11::register]]
SEXP vrpr_problem_data_create(doubles depot_x,
                              doubles depot_y,
                              doubles depot_tw_early,
                              doubles depot_tw_late,
                              doubles depot_service,
                              doubles client_x,
                              doubles client_y,
                              doubles client_delivery,
                              doubles client_pickup,
                              doubles client_service,
                              doubles client_tw_early,
                              doubles client_tw_late,
                              doubles client_release,
                              doubles client_prize,
                              logicals client_required,
                              integers veh_num_available,
                              doubles veh_capacity,
                              doubles veh_fixed_cost,
                              doubles veh_tw_early,
                              doubles veh_tw_late,
                              doubles veh_max_duration,
                              doubles veh_max_distance,
                              doubles veh_unit_distance_cost,
                              doubles veh_unit_duration_cost,
                              integers veh_start_depot,
                              integers veh_end_depot,
                              integers client_group,
                              list group_members,
                              logicals group_required,
                              doubles_matrix<> distance,
                              doubles_matrix<> duration)
{
    std::vector<ProblemData::Depot> depots;
    depots.reserve(depot_x.size());
    for (R_xlen_t i = 0; i < depot_x.size(); ++i)
        depots.emplace_back(depot_x[i],
                            depot_y[i],
                            vrpr::as_i64(depot_tw_early[i], "tw_early do depósito"),
                            vrpr::as_i64_or_max(depot_tw_late[i], "tw_late do depósito"),
                            vrpr::as_i64(depot_service[i], "service do depósito"));

    std::vector<ProblemData::Client> clients;
    clients.reserve(client_x.size());
    for (R_xlen_t i = 0; i < client_x.size(); ++i)
    {
        std::vector<pyvrp::Load> const delivery{
            vrpr::as_i64(client_delivery[i], "demand do cliente")};
        std::vector<pyvrp::Load> const pickup{
            vrpr::as_i64(client_pickup[i], "pickup do cliente")};

        clients.emplace_back(client_x[i],
                             client_y[i],
                             delivery,
                             pickup,
                             vrpr::as_i64(client_service[i], "service do cliente"),
                             vrpr::as_i64(client_tw_early[i], "tw_early do cliente"),
                             vrpr::as_i64_or_max(client_tw_late[i], "tw_late do cliente"),
                             vrpr::as_i64(client_release[i], "release_time do cliente"),
                             vrpr::as_i64(client_prize[i], "prize do cliente"),
                             client_required[i] == TRUE,
                             // -1 = sem grupo; senão índice 0-based do grupo.
                             client_group[i] < 0
                                 ? std::optional<size_t>(std::nullopt)
                                 : std::optional<size_t>(
                                       static_cast<size_t>(client_group[i])),
                             "");
    }

    // Grupos de clientes (mutuamente exclusivos): membros são índices de
    // localização; cada grupo pode ser obrigatório (visitar exatamente um) ou
    // não (visitar no máximo um).
    std::vector<ProblemData::ClientGroup> groups;
    groups.reserve(group_members.size());
    for (R_xlen_t g = 0; g < group_members.size(); ++g)
    {
        integers members(group_members[g]);
        std::vector<size_t> cl;
        cl.reserve(members.size());
        for (R_xlen_t i = 0; i < members.size(); ++i)
            cl.push_back(static_cast<size_t>(members[i]));
        groups.emplace_back(cl, group_required[g] == TRUE, "");
    }

    std::vector<ProblemData::VehicleType> vehicle_types;
    vehicle_types.reserve(veh_num_available.size());
    for (R_xlen_t i = 0; i < veh_num_available.size(); ++i)
    {
        std::vector<pyvrp::Load> const capacity{
            vrpr::as_i64(veh_capacity[i], "capacity do veículo")};

        vehicle_types.emplace_back(
            static_cast<std::size_t>(veh_num_available[i]),
            capacity,
            static_cast<std::size_t>(veh_start_depot[i]),
            static_cast<std::size_t>(veh_end_depot[i]),
            vrpr::as_i64(veh_fixed_cost[i], "fixed_cost do veículo"),
            vrpr::as_i64(veh_tw_early[i], "tw_early do veículo"),
            vrpr::as_i64_or_max(veh_tw_late[i], "tw_late do veículo"),
            vrpr::as_i64_or_max(veh_max_duration[i], "max_duration do veículo"),
            vrpr::as_i64_or_max(veh_max_distance[i], "max_distance do veículo"),
            vrpr::as_i64(veh_unit_distance_cost[i], "unit_distance_cost do veículo"),
            vrpr::as_i64(veh_unit_duration_cost[i], "unit_duration_cost do veículo"));
    }

    std::vector<pyvrp::Matrix<pyvrp::Distance>> dist_mats;
    dist_mats.push_back(to_matrix<pyvrp::Distance>(distance, "matriz de distância"));

    std::vector<pyvrp::Matrix<pyvrp::Duration>> dur_mats;
    dur_mats.push_back(to_matrix<pyvrp::Duration>(duration, "matriz de duração"));

    // O construtor chama validate() e lança std::exception em dados inconsistentes;
    // o cpp11 traduz isso para um erro de R automaticamente.
    auto *data = new ProblemData(std::move(clients),
                                 std::move(depots),
                                 std::move(vehicle_types),
                                 std::move(dist_mats),
                                 std::move(dur_mats),
                                 std::move(groups));

    return external_pointer<ProblemData>(data);
}

// Resumo do ProblemData, para inspeção/round-trip no lado R.
[[cpp11::register]]
list vrpr_problem_data_summary(SEXP ptr)
{
    external_pointer<ProblemData> data(ptr);
    using namespace cpp11::literals;

    return writable::list({
        "num_clients"_nm = static_cast<int>(data->numClients()),
        "num_depots"_nm = static_cast<int>(data->numDepots()),
        "num_groups"_nm = static_cast<int>(data->numGroups()),
        "num_locations"_nm = static_cast<int>(data->numLocations()),
        "num_vehicle_types"_nm = static_cast<int>(data->numVehicleTypes()),
        "num_vehicles"_nm = static_cast<int>(data->numVehicles()),
        "num_load_dimensions"_nm = static_cast<int>(data->numLoadDimensions()),
        "num_profiles"_nm = static_cast<int>(data->numProfiles()),
        "has_time_windows"_nm = static_cast<bool>(data->hasTimeWindows()),
    });
}
