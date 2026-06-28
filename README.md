# vrpr

> PyVRP para R — solver de roteirização veicular (VRP) de produção.

`vrpr` porta o solver [PyVRP](https://github.com/PyVRP/PyVRP) (núcleo C++ de alto desempenho,
licença MIT) para um pacote **R** idiomático, no estilo **tidyverse**: API pipe-friendly, dados
em tibbles, logs via [`{cli}`](https://cli.r-lib.org) e o núcleo C++ religado com
[`{cpp11}`](https://cpp11.r-lib.org) — **sem dependência de runtime Python**.

Preenche uma lacuna real do ecossistema R: há `ompr`, `ROI`, `lpSolve`, `igraph` e `dodgr`,
mas nenhum solver moderno, forte e amigável para VRP de produção.

## Status

🚧 **Desenvolvimento inicial** — **todas as variantes do PyVRP** já resolvem end-to-end: CVRP,
VRPTW (janelas de tempo), frota heterogênea, MDVRP (múltiplos depósitos), prize-collecting
(opcionais + grupos), coleta-e-entrega simultânea / backhaul e multi-trip. Próximo: vignettes, CI, CRAN.

**Paridade com o PyVRP** verificada (ver `tools/benchmark/`): objetivo idêntico bit a bit e, na
instância X-n101-k25 (ótimo 27591), ambos atingem o ótimo em 10 s.

- **VRPTW:** acrescente `tw_early`, `tw_late`, `service` aos clientes; `routes()` traz
  `start_service` e `wait` por visita.
- **Frota heterogênea:** chame `add_vehicle_type()` várias vezes com capacidades, custos
  (`fixed_cost`, `unit_distance_cost`) e turnos distintos.
- **MDVRP:** chame `add_depot()` várias vezes e use `add_vehicle_type(depot = i)` para basear
  cada tipo de veículo num depósito; `routes()` traz a coluna `depot`.
- **Prize-collecting:** marque clientes com `required = FALSE` e `prize`; o solver decide quais
  visitar. `add_client_group()` define alternativas mutuamente exclusivas. Veja os pulados com
  `unvisited_clients()`.
- **Coleta-e-entrega / backhaul:** acrescente a coluna `pickup` aos clientes (a carga coletada
  conta para a capacidade ao longo da rota).
- **Multi-trip:** `add_vehicle_type(reload_depots = i, max_reloads = k)` deixa um veículo voltar
  ao depósito para reabastecer e fazer várias viagens (`summary()$num_trips`).

### Ler instâncias-padrão

```r
m <- read_vrplib(system.file("extdata", "sample-n6-k2.vrp", package = "vrpr"))
m <- read_solomon(system.file("extdata", "sample-solomon.txt", package = "vrpr"))
res <- m |> vrp_solve(stop = max_runtime(5))
```

`read_vrplib()` lê CVRP/VRPTW no formato VRPLIB/TSPLIB (EUC_2D); `read_solomon()` lê VRPTW no
formato de Solomon. Ambos devolvem um `vrpr_model`.

### Visualizar

```r
plot(res)   # depósitos, clientes e rotas (uma cor por rota) com {ggplot2}
```

`plot()` (em um resultado ou modelo) desenha os depósitos (quadrados), os clientes (pontos;
opcionais não visitados aparecem vazados) e as rotas coloridas. Requer `{ggplot2}`.

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
