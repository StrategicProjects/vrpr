# Benchmark de paridade — vrpr vs PyVRP

Valida que o `vrpr` (port R do PyVRP via cpp11) é fiel à referência Python/C++,
em duas dimensões: **corretude do objetivo** e **qualidade da solução**.

## Como reproduzir

```sh
# 1. PyVRP num venv (a parte de referência)
python3 -m venv /tmp/vrpr_bench && /tmp/vrpr_bench/bin/pip install pyvrp

# 2. instalar o vrpr (build de RELEASE — ver a ressalva abaixo)
R CMD INSTALL .

# 3. rodar o driver (baixa a instância do conjunto X se ausente)
VRPR_PYVRP_PYTHON=/tmp/vrpr_bench/bin/python \
  Rscript tools/benchmark/parity.R X-n101-k25 10 1
```

> ⚠️ **Sempre meça o build de RELEASE** (`R CMD INSTALL`), não o de debug do
> `devtools::load_all()`. O build de debug compila sem `-O2` e com os `assert()`
> do núcleo ativos (sem `-DNDEBUG`), ficando ~20× mais lento — o que distorce
> totalmente qualquer comparação de throughput.

## Parte A — paridade do objetivo (exata, determinística)

Mesma instância e **mesma solução** (mesmas rotas) avaliadas nos dois lados.
Como `vrpr` e PyVRP compartilham o mesmo núcleo C++ (`CostEvaluator`,
`Solution`), o custo **tem** de coincidir bit a bit.

Instância `sample-n6-k2`, rotas `[[1,2],[3,4,5]]`:

| | viável | distância | custo |
|---|---|---|---|
| PyVRP | true | 81 | 81 |
| vrpr  | true | 81 | 81 |

✅ Idêntico. Valida o modelo de dados, o cálculo de distância (EUC_2D
round-half-up) e a função objetivo.

## Parte B — paridade de qualidade

Instância `X-n101-k25` (100 clientes, ótimo conhecido **27591**), 10 s por solver,
build de release:

| Solver | custo | gap ao ótimo | iterações (10s) |
|---|---|---|---|
| PyVRP | 27591 | 0,00 % | ~18.000 |
| vrpr  | 27591 | 0,00 % | ~24.000 |

✅ Ambos atingem o **ótimo** em 10 s. O throughput do `vrpr` é da mesma ordem do
PyVRP (aqui até um pouco maior) — o laço ILS em R não é gargalo no build de release.
Em vários seeds o `vrpr` fica em 0,00–0,1 % do ótimo.

## Por que há paridade

O `vrpr` vendoriza o núcleo C++ do PyVRP e religa-o com cpp11; o laço ILS em R é
um **port fiel** do `IteratedLocalSearch.py`: Late Acceptance Hill-Climbing
(Burke & Bykov, 2017) + reinício após estagnação + busca exaustiva ao achar um
novo melhor, com os mesmos parâmetros default (`history_length = 300`). O trabalho
pesado (busca local, avaliação de custo) roda no mesmo C++; a orquestração em R
acrescenta um overhead por iteração que, no build de release, é pequeno frente ao
custo da busca local.

## Notas

- O número de veículos é fixado folgado (30 > k=25); como o CVRP minimiza só
  distância (sem custo fixo de veículo), veículos ociosos não alteram o ótimo.
- A matriz de distância é Euclidiana com round-half-up (`floor(d + 0.5)`) nos dois
  lados, a convenção EUC_2D do TSPLIB — necessária para reproduzir o BKS 27591.
