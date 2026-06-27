# vrpr

> PyVRP para R — solver de roteirização veicular (VRP) de produção.

`vrpr` porta o solver [PyVRP](https://github.com/PyVRP/PyVRP) (núcleo C++ de alto desempenho,
licença MIT) para um pacote **R** idiomático, no estilo **tidyverse**: API pipe-friendly, dados
em tibbles, logs via [`{cli}`](https://cli.r-lib.org) e o núcleo C++ religado com
[`{cpp11}`](https://cpp11.r-lib.org) — **sem dependência de runtime Python**.

Preenche uma lacuna real do ecossistema R: há `ompr`, `ROI`, `lpSolve`, `igraph` e `dodgr`,
mas nenhum solver moderno, forte e amigável para VRP de produção.

## Status

🚧 **Em planejamento / desenvolvimento inicial.** Ainda não é um pacote instalável.

## Variantes alvo

CVRP · VRPTW (janelas de tempo) · MDVRP (múltiplos depósitos) · frota heterogênea ·
prize-collecting / clientes opcionais · pickup & delivery · backhaul · multi-trip.

## Algoritmo

Iterated Local Search (ILS) — herdado do PyVRP v0.13.x.

## Licença

MIT. Deriva do PyVRP (© PyVRP authors), cujo copyright é preservado.
