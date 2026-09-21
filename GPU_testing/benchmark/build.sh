#!/usr/bin/env bash
# =============================================================================
#  build.sh -- compila las 4 variantes del benchmark
#
#    bin/bench_gf_32   gfortran-12, real32
#    bin/bench_gf_64   gfortran-12, real64
#    bin/bench_nv_32   nvfortran,   real32
#    bin/bench_nv_64   nvfortran,   real64
#
#  Si un compilador no esta instalado, sus variantes se saltan.
#  Los mensajes de cada compilacion quedan en logs/.
#  Uso:  ./build.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"          # trabajar siempre en la carpeta del script

SRC=bench.F90
GF=${GF:-gfortran-12}         # se puede cambiar:  GF=gfortran-11 ./build.sh
NV=${NV:-nvfortran}

mkdir -p bin logs mod
built=0

# ---------------------------- gfortran ---------------------------------------
if command -v "$GF" >/dev/null 2>&1; then
    for p in 32 64; do
        flags=""
        [[ $p == 32 ]] && flags="-DUSE_REAL32"
        mkdir -p "mod/gf_$p"                       # los .mod de cada variante aparte
        echo "compilando bin/bench_gf_$p ..."
        if $GF -O3 -fopenmp -foffload=nvptx-none $flags \
               -J "mod/gf_$p" "$SRC" -o "bin/bench_gf_$p" \
               > "logs/build_gf_$p.log" 2>&1; then
            built=$((built + 1))
        else
            echo "  FALLO. Mira logs/build_gf_$p.log"; cat "logs/build_gf_$p.log"; exit 1
        fi
    done
else
    echo "aviso: '$GF' no encontrado, se saltan las variantes gf"
fi

# ---------------------------- nvfortran --------------------------------------
if command -v "$NV" >/dev/null 2>&1; then
    for p in 32 64; do
        flags=""
        [[ $p == 32 ]] && flags="-DUSE_REAL32"
        mkdir -p "mod/nv_$p"
        echo "compilando bin/bench_nv_$p ..."
        # -mp=gpu     OpenMP en CPU y offload a GPU
        # -gpu=cc75   codigo maquina para Turing (T1000): sin JIT al arrancar
        # -Minfo=mp   informa como repartio cada bucle -> logs/minfo_nv_$p.txt
        if $NV -O3 -mp=gpu -gpu=cc75 -Minfo=mp $flags \
               -module "mod/nv_$p" "$SRC" -o "bin/bench_nv_$p" \
               > "logs/minfo_nv_$p.txt" 2>&1; then
            built=$((built + 1))
        else
            echo "  FALLO. Mira logs/minfo_nv_$p.txt"; cat "logs/minfo_nv_$p.txt"; exit 1
        fi
    done
else
    echo "aviso: '$NV' no encontrado, se saltan las variantes nv"
fi

echo "listo: $built ejecutable(s) en bin/"
ls -1 bin/
