#ifndef VRPR_MEASURE_BRIDGE_H
#define VRPR_MEASURE_BRIDGE_H

// Fronteira numérica R <-> PyVRP.
//
// As medidas do PyVRP (Cost/Distance/Duration/Load) são int64_t; Coordinate é
// double. R não tem inteiro de 64 bits nativo, então as medidas trafegam como
// `double` (numeric) com semântica inteira, validada aqui:
//
//   * finito + inteiro + |x| <= 2^53  -> int64_t exato
//   * Inf/NA (sentinela "irrestrito")  -> numeric_limits<int64_t>::max()
//
// 2^53 (~9.0e15) é o maior inteiro exatamente representável em double; é
// não-restritivo para magnitudes reais de VRP. Decisão registrada em plano.md.

#include <cpp11.hpp>

#include <cmath>
#include <cstdint>
#include <limits>

namespace vrpr
{
// Maior inteiro exatamente representável como double (2^53).
inline constexpr double kMaxExactInt = 9007199254740992.0;

// Converte um double de R em int64, exigindo semântica inteira.
inline std::int64_t as_i64(double x, char const *what)
{
    if (!std::isfinite(x))
        cpp11::stop(
            "%s deve ser finito; use o valor 'irrestrito' (Inf) só onde permitido.",
            what);

    if (x != std::floor(x))
        cpp11::stop("%s deve ser inteiro (o PyVRP usa medidas inteiras); "
                    "recebido %g. Reescale os dados se necessário.",
                    what, x);

    if (std::abs(x) > kMaxExactInt)
        cpp11::stop("%s excede 2^53 e não é exatamente representável em double.",
                    what);

    return static_cast<std::int64_t>(x);
}

// Como as_i64, mas mapeia não-finito (Inf/NA) para o sentinela int64 max,
// que o PyVRP interpreta como "irrestrito".
inline std::int64_t as_i64_or_max(double x, char const *what)
{
    if (!std::isfinite(x))
        return std::numeric_limits<std::int64_t>::max();
    return as_i64(x, what);
}
}  // namespace vrpr

#endif  // VRPR_MEASURE_BRIDGE_H
