# vrpr: Vehicle Routing Problem Solver Built on 'PyVRP'

A 'tidyverse'-style interface to high-performance vehicle routing
problem (VRP) solving, derived from the 'PyVRP' solver of Wouda, Lan and
Kool (2024)
[doi:10.1287/ijoc.2023.0055](https://doi.org/10.1287/ijoc.2023.0055) .
Vendors the C++ core of 'PyVRP' (<https://github.com/PyVRP/PyVRP>) and
rewires it through 'cpp11'; the iterated local search loop and the
penalty manager that drive that core are ports to R of the corresponding
'Python' code of 'PyVRP', so there is no 'Python' runtime dependency.
Supports the capacitated VRP, time windows, multiple depots,
heterogeneous fleets, prize-collecting and multi-trip variants. Not
affiliated with or endorsed by the 'PyVRP' project.

## See also

Useful links:

- <https://github.com/StrategicProjects/vrpr>

- <https://strategicprojects.github.io/vrpr/>

- Report bugs at <https://github.com/StrategicProjects/vrpr/issues>

## Author

**Maintainer**: André Leite <leite@castlab.org>
([ORCID](https://orcid.org/0000-0002-4718-9766))

Authors:

- André Leite <leite@castlab.org>
  ([ORCID](https://orcid.org/0000-0002-4718-9766))

- Marcos Wasiliew <marcos.wasiliew@gmail.com>
  ([ORCID](https://orcid.org/0009-0004-4694-3159))

- Hugo Vasconcelos <hugo.vasconcelos@ufpe.br>
  ([ORCID](https://orcid.org/0000-0001-6249-0920))

- Carlos Amorim <carlos.agaf@ufpe.br>
  ([ORCID](https://orcid.org/0000-0001-6315-8305))

- Diogo Bezerra <diogo.bezerra@ufpe.br>
  ([ORCID](https://orcid.org/0000-0002-1216-8674))

- Júlia Nascimento Barreto <juliabarreto@gd.seplag.pe.gov.br>
  ([ORCID](https://orcid.org/0009-0004-2851-7770))

Other contributors:

- Niels Wouda (author of the vendored PyVRP C++ core) \[contributor,
  copyright holder\]

- Leon Lan (author of PyVRP) \[contributor\]

- Wouter Kool (author of PyVRP) \[contributor\]

- PyVRP contributors (PyVRP: the vendored C++ core and the Python code
  ported to R) \[copyright holder\]

- Thibaut Vidal (HGS-CVRP, parts of the vendored C++ core) \[copyright
  holder\]

- ORTEC (HGS-DIMACS, parts of the vendored C++ core) \[copyright
  holder\]
