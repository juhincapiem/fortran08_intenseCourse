#!/usr/bin/env bash
# =============================================================================
#  run.sh -- lanza todas las combinaciones y junta los datos crudos en un CSV
#
#  Para cada ejecutable en bin/ y cada tamano N:
#     - modo cpu con cada configuracion de hilos (P1 ... ALL24)
#     - modo gpu_kernel
#     - modo gpu_total
#
#  Uso:
#     ./run.sh                          # valores por defecto
#     NREP=50 EXPS="22" ./run.sh        # cambiar parametros sin editar
#     ONLY=gf ./run.sh                  # solo los ejecutables bench_gf_*
#
#  Resultado: results/raw_<fecha>.csv  y  results/sysinfo_<fecha>.txt
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")"

NREP=${NREP:-20}              # repeticiones medidas
NWARM=${NWARM:-3}             # repeticiones de calentamiento (se descartan)
EXPS=${EXPS:-"20 22 24"}      # N = 2^20, 2^22, 2^24
ONLY=${ONLY:-}                # filtro opcional: gf | nv

# -----------------------------------------------------------------------------
# Configuraciones de CPU para el i9-13900:
#   CPU logicas 0-15  = 8 P-cores con hyperthreading (0 y 1 son el mismo nucleo)
#   CPU logicas 16-31 = 16 E-cores
#
# Formato:  etiqueta | hilos | OMP_PLACES
#   {0}:8:2  = 8 lugares empezando en la CPU 0, de 2 en 2 -> 0,2,4,...,14
#              (un hilo por nucleo P fisico, sin compartir nucleo)
# -----------------------------------------------------------------------------
CONFIGS=(
    "P1|1|{0}"
    "P2|2|{0}:2:2"
    "P4|4|{0}:4:2"
    "P8|8|{0}:8:2"
    "P16|16|{0}:16"
    "E16|16|{16}:16"
    "ALL24|24|{0}:8:2,{16}:16"
)

shopt -s nullglob
BINS=(bin/bench_${ONLY}*)
if (( ${#BINS[@]} == 0 )); then
    echo "No hay ejecutables en bin/. Corre primero ./build.sh"; exit 1
fi

mkdir -p results
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="results/raw_${STAMP}.csv"
SYS="results/sysinfo_${STAMP}.txt"
LOG="results/run_${STAMP}.log"

# ---------------- datos de la maquina, para poder comparar despues ----------
{
    echo "fecha: $(date)"
    echo "NREP=$NREP NWARM=$NWARM EXPS=$EXPS"
    echo; lscpu | grep -E "Model name|^CPU\(s\)|Thread|Core|Socket"
    echo; nvidia-smi --query-gpu=name,driver_version,clocks.max.sm,clocks.max.mem --format=csv 2>&1
    echo; command -v gfortran-12 >/dev/null && gfortran-12 --version | head -1
    command -v nvfortran >/dev/null && nvfortran --version | sed -n 2p
} > "$SYS"

echo "compiler,config,precision,mode,threads,N,rep,time_s,max_err" > "$OUT"

# Cuenta total de lanzamientos, para mostrar el progreso
n_exps=$(wc -w <<< "$EXPS")
total=$(( ${#BINS[@]} * n_exps * (${#CONFIGS[@]} + 2) ))
count=0

# -----------------------------------------------------------------------------
# run_one <binario> <compilador> <etiqueta> <modo> <exponente>  [VAR=valor ...]
#   Lanza el programa con las variables de entorno dadas, filtra las lineas
#   de datos (las que empiezan por un digito) y les antepone compilador,config.
# -----------------------------------------------------------------------------
run_one() {
    local bin=$1 comp=$2 label=$3 mode=$4 e=$5; shift 5
    count=$((count + 1))
    printf "[%3d/%3d] %-6s %-10s %-6s N=2^%s\n" "$count" "$total" "$comp" "$mode" "$label" "$e"

    local data
    if ! data=$(env "$@" "$bin" "$mode" "$e" "$NREP" "$NWARM" 2>>"$LOG"); then
        echo "   FALLO (detalles en $LOG)"; return
    fi
    grep -E '^[0-9]' <<< "$data" | sed "s/^/${comp},${label},/" >> "$OUT"
}

for bin in "${BINS[@]}"; do
    comp=$(basename "$bin" | cut -d_ -f2)        # bench_gf_64 -> gf
    for e in $EXPS; do

        # ---- CPU: una ejecucion por configuracion de hilos ----
        for cfg in "${CONFIGS[@]}"; do
            IFS='|' read -r label nthr places <<< "$cfg"
            run_one "$bin" "$comp" "$label" cpu "$e" \
                OMP_NUM_THREADS="$nthr" OMP_PLACES="$places" OMP_PROC_BIND=close
        done

        # ---- GPU: el numero de hilos de CPU no importa aqui ----
        for mode in gpu_kernel gpu_total; do
            run_one "$bin" "$comp" GPU "$mode" "$e" \
                OMP_NUM_THREADS=1 OMP_TARGET_OFFLOAD=MANDATORY
        done
    done
done

rows=$(( $(wc -l < "$OUT") - 1 ))
echo
echo "Hecho: $rows filas en $OUT"
echo "Siguiente paso:  python3 analyze.py $OUT"
