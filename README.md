# vrpr

> PyVRP para R — solver de roteirização veicular (VRP) de produção.

`vrpr` porta o solver [PyVRP](https://github.com/PyVRP/PyVRP) (núcleo C++ de alto desempenho,
licença MIT) para um pacote **R** idiomático, no estilo **tidyverse**: API pipe-friendly, dados
em tibbles, logs via [`{cli}`](https://cli.r-lib.org) e o núcleo C++ religado com
[`{cpp11}`](https://cpp11.r-lib.org) — **sem dependência de runtime Python**.

Preenche uma lacuna real do ecossistema R: há `ompr`, `ROI`, `lpSolve`, `igraph` e `dodgr`,
mas nenhum solver moderno, forte e amigável para VRP de produção.

## Status

🚧 **Desenvolvimento inicial** — **CVRP, VRPTW** (janelas de tempo), **frota heterogênea**,
**múltiplos depósitos (MDVRP)** e **prize-collecting** (clientes opcionais + grupos mutuamente
exclusivos) já resolvem end-to-end. Faltam variantes avançadas (pickup & delivery, multi-trip) e polish.

- **VRPTW:** acrescente `tw_early`, `tw_late`, `service` aos clientes; `routes()` traz
  `start_service` e `wait` por visita.
- **Frota heterogênea:** chame `add_vehicle_type()` várias vezes com capacidades, custos
  (`fixed_cost`, `unit_distance_cost`) e turnos distintos.
- **MDVRP:** chame `add_depot()` várias vezes e use `add_vehicle_type(depot = i)` para basear
  cada tipo de veículo num depósito; `routes()` traz a coluna `depot`.
- **Prize-collecting:** marque clientes com `required = FALSE` e `prize`; o solver decide quais
  visitar. `add_client_group()` define alternativas mutuamente exclusivas. Veja os pulados com
  `unvisited_clients()`.

```r
library(vrpr)

clientes <- tibble::tibble(
  x = c(10, 25, 40, 15), y = c(5, 30, 12, 22),
  demand = c(10, 15, 8, 12)
)

res <- vrp_model() |>
  add_depot(x = 0, y = 0) |>
  add_clients(clientes) |>
  add_vehicle_type(num_available = 3, capacity = 50) |>
  vrp_solve(stop = max_runtime(2))

cost(res)      # custo objetivo
routes(res)    # tibble: route_id, position, client, vehicle_type
summary(res)   # resumo de uma linha
```

## Variantes alvo

CVRP · VRPTW (janelas de tempo) · MDVRP (múltiplos depósitos) · frota heterogênea ·
prize-collecting / clientes opcionais · pickup & delivery · backhaul · multi-trip.

## Algoritmo

Iterated Local Search (ILS) — herdado do PyVRP v0.13.x.

## Licença

MIT. Deriva do PyVRP (© PyVRP authors), cujo copyright é preservado.
