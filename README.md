# Fortran 2008 Learning

Learning lab for modern Fortran 2008: object-oriented programming,
software engineering practices, and the road to GPU computing with OpenACC.

## Structure
- `notes/` — topic notes, in my own words
- `exercises/` — exercises organized by week
- `projects/` — weekly mini-projects and the final integrative project

## Progress
- [ ] Week 1 — Modern syntax, modules, arrays
- [ ] Week 2 — Pure procedures, precision, file I/O
- [ ] Week 3 — Derived types and type-bound procedures
- [ ] Week 4 — Inheritance, polymorphism, integrative project

## Environment
- Compiler: gfortran with `-std=f2008 -Wall`
- Editor: VSCode + Modern Fortran extension
- Platform: WSL2 (Ubuntu)

## Build
```bash
gfortran -std=f2008 -Wall -O2 file.f90 -o program && ./program
```
