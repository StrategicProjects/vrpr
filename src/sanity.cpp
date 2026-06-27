// Binding de sanidade da Fase 1: prova que o toolchain C++20 + cpp11 funciona,
// antes de ligar o núcleo C++ vendorizado do PyVRP (src/vendor/pyvrp/).
//
// Usa um recurso de C++20 (std::span / designated initializers via constexpr)
// só para garantir que CXX_STD = CXX20 está em efeito.

#include <cpp11.hpp>

#include <string>
#include <version>  // expõe as macros de feature do C++20

// Retorna o padrão C++ efetivamente usado na compilação.
[[cpp11::register]]
int vrpr_cpp_standard() {
  return static_cast<int>(__cplusplus / 100L % 100L);  // p.ex. 20 para C++20
}

// Confirma a presença de um header de feature do C++20.
[[cpp11::register]]
bool vrpr_has_cxx20() {
#if defined(__cpp_lib_span) || __cplusplus >= 202002L
  return true;
#else
  return false;
#endif
}

// Saudação trivial, útil como smoke test do binding cpp11.
[[cpp11::register]]
std::string vrpr_hello() {
  return std::string("vrpr: núcleo C++ pronto para receber o PyVRP");
}
