## fpm (Fortran Package Manager)

Build system that resolves modules dependencies and compiles in the correct order automatically. No more listing files nor writing the "gfortran" compiling line by hand.

### Install (global, not in a venv)
    pipx install fpm


### Project structure fpm expects
    project/
    |- src/      modules (library code)
    |- app/      main program 
    |- fpm.toml  config file
    |- build/    artifacts (.mod, .o, executables) - gitignore this

### Minimal fpm.toml
    name = "heat2d"
    version = "0.1.0"

### Commands (run from project root)
    fpm build           compile only
    fpm run             compile + run 
    fpm run --profile debug     includes -fcheck=bounds (dev)
    fpm run --profile release   optimized (production)
    fpm test            run tests in test/

### Notes
- fpm runs from the project root, so file paths in code are relative to there.

