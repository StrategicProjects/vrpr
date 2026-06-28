#!/usr/bin/env python
"""PyVRP side of the parity benchmark. Solves a VRPLIB CVRP instance and prints
JSON with the best cost. The distance matrix uses round-half-up (floor(d+0.5)),
identical to vrpr's euclidean_matrix(), for a fair comparison.

Usage: python pyvrp_side.py <file.vrp> <num_vehicles> <seconds> [seed]
"""
import sys, json, numpy as np, vrplib
from pyvrp import ProblemData, Client, Depot, VehicleType, Solution, CostEvaluator, solve
from pyvrp.stop import MaxRuntime

path, n_veh, secs = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
seed = int(sys.argv[4]) if len(sys.argv) > 4 else 1

inst = vrplib.read_instance(path)
coords = np.asarray(inst["node_coord"], float)
demand = np.asarray(inst["demand"], int)
cap = int(inst["capacity"])
depot = int(np.asarray(inst["depot"]).ravel()[0])  # 0-based depot index

n = len(coords)
D = np.zeros((n, n), int)
for i in range(n):
    for j in range(n):
        D[i, j] = int(np.floor(np.hypot(*(coords[i] - coords[j])) + 0.5))

clients = [Client(x=int(coords[k, 0]), y=int(coords[k, 1]), delivery=[int(demand[k])])
           for k in range(n) if k != depot]
data = ProblemData(
    clients=clients,
    depots=[Depot(x=int(coords[depot, 0]), y=int(coords[depot, 1]))],
    vehicle_types=[VehicleType(num_available=n_veh, capacity=[cap])],
    distance_matrices=[D], duration_matrices=[D],
)
res = solve(data, stop=MaxRuntime(secs), seed=seed, display=False)
print(json.dumps({
    "solver": "pyvrp",
    "cost": int(res.cost()),
    "feasible": bool(res.is_feasible()),
    "num_routes": res.best.num_routes(),
    "iterations": res.num_iterations,
}))
