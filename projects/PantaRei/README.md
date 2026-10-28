# heat2d — 2D Steady-State Heat Conduction (FEM)

Finite element solver for 2D steady-state heat conduction.

## Scope (v1)
- Elements: T3 (linear triangle) and Q4 (bilinear quad), extensible design
- Mesh: generated with gmsh (Python API), read from .msh 2.2 ASCII
- Boundary conditions: Dirichlet and Neumann
- Linear solver: direct (dense) to start

## Structure
- `mesh/`    — Python script (gmsh) to generate meshes, and .msh files
- `src/`     — Fortran modules and main program
- `results/` — solver output

## Build
(to be added — will use fpm)

## Status
- [ ] Phase 1: mesh parser (read .msh, print nodes/elements)
- [ ] Phase 2: element stiffness (T3)
- [ ] Phase 3: global assembly
- [ ] Phase 4: boundary conditions + solver
- [ ] Phase 5: add Q4 and Neumann
- [ ] Phase 6: post-processing
