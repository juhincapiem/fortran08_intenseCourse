#!/usr/bin/env python3
"""
analyze.py -- estadisticas y graficas a partir del CSV crudo de run.sh

Uso:
    python3 analyze.py                          # usa el raw_*.csv mas reciente
    python3 analyze.py results/raw_XXXX.csv     # un archivo concreto

Genera, junto al CSV:
    summary_<fecha>.csv       una fila por combinacion, con min/media/desv/max
    cpu_scaling_<fecha>.png   tiempo de CPU segun la configuracion de hilos
    cpu_vs_gpu_<fecha>.png    mejor CPU contra GPU (solo kernel y total)
"""
import glob
import sys
from pathlib import Path

import pandas as pd
import matplotlib
matplotlib.use("Agg")                     # sin ventana: solo escribe PNG
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

CONFIG_ORDER = ["P1", "P2", "P4", "P8", "P16", "E16", "ALL24"]

# Colores fijos por variante (siempre el mismo color para la misma variante)
SERIES = {
    ("gf", 32): ("gfortran real32", "#2a78d6", "o", "-"),
    ("gf", 64): ("gfortran real64", "#eb6834", "s", "--"),
    ("nv", 32): ("nvfortran real32", "#1baf7a", "^", "-"),
    ("nv", 64): ("nvfortran real64", "#eda100", "D", "--"),
}
INK, MUTED, GRID = "#1f1f1e", "#6b6a64", "#e4e3dd"


# ---------------------------------------------------------------------------
def load(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    bad = df[df["max_err"] != 0]
    if len(bad):
        print(f"\n!! {len(bad)} filas con max_err distinto de 0 -- resultados incorrectos:")
        print(bad.groupby(["compiler", "precision", "mode", "config", "N"]).size())
    else:
        print(f"Verificacion: las {len(df)} repeticiones dan max_err = 0.")
    return df


def summarize(df: pd.DataFrame) -> pd.DataFrame:
    keys = ["compiler", "precision", "mode", "config", "threads", "N"]
    s = (df.groupby(keys)["time_s"]
           .agg(n="count", min="min", mean="mean", std="std", max="max")
           .reset_index())
    s["cv_pct"] = 100 * s["std"] / s["mean"]                 # dispersion relativa
    # bytes movidos por llamada: leer x, leer y, escribir y
    nbytes = 3 * s["N"] * s["precision"] // 8
    s["GB_s"] = nbytes / s["min"] / 1e9                       # con el mejor tiempo
    return s


def print_tables(s: pd.DataFrame) -> None:
    ms = s.copy()
    for c in ["min", "mean", "std", "max"]:
        ms[c] = ms[c] * 1e3                                   # a milisegundos
    ms["config"] = pd.Categorical(ms["config"], CONFIG_ORDER + ["GPU"], ordered=True)
    cols = ["compiler", "precision", "mode", "config", "n",
            "min", "mean", "std", "max", "cv_pct", "GB_s"]
    for N, g in ms.sort_values(["compiler", "precision", "mode", "config"]).groupby("N"):
        print(f"\n=== N = {N:,}  (tiempos en ms) ===")
        print(g[cols].to_string(index=False, float_format=lambda v: f"{v:8.3f}"))


# ---------------------------------------------------------------------------
def style(ax, title):
    ax.set_title(title, color=INK, fontsize=11, loc="left")
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(MUTED)
    ax.tick_params(colors=MUTED, labelsize=9)


def plot_cpu_scaling(s: pd.DataFrame, out: Path) -> None:
    cpu = s[s["mode"] == "cpu"]
    Ns = sorted(cpu["N"].unique())
    fig, axes = plt.subplots(1, len(Ns), figsize=(5 * len(Ns), 4.2), squeeze=False)
    for ax, N in zip(axes[0], Ns):
        for (comp, prec), (name, color, marker, ls) in SERIES.items():
            g = cpu[(cpu["N"] == N) & (cpu["compiler"] == comp) & (cpu["precision"] == prec)]
            if g.empty:
                continue
            g = g.set_index("config").reindex([c for c in CONFIG_ORDER if c in set(g["config"])])
            x = [CONFIG_ORDER.index(c) for c in g.index]
            ax.errorbar(x, g["mean"] * 1e3, yerr=g["std"] * 1e3, label=name,
                        color=color, marker=marker, markersize=6, linestyle=ls,
                        linewidth=2, capsize=3)
        ax.set_xticks(range(len(CONFIG_ORDER)), CONFIG_ORDER)
        ax.set_ylabel("tiempo por llamada (ms)", color=MUTED)
        ax.set_ylim(bottom=0)
        style(ax, f"CPU, N = 2^{int(N).bit_length() - 1}")
    axes[0][0].legend(frameon=False, fontsize=9)
    fig.suptitle("Escalado en CPU: media ± desviación estándar", color=INK, x=0.01, ha="left")
    fig.tight_layout()
    fig.savefig(out, dpi=130)
    plt.close(fig)


def plot_cpu_vs_gpu(s: pd.DataFrame, out: Path) -> None:
    cats = ["CPU P1", "CPU mejor", "GPU kernel", "GPU total"]
    Ns = sorted(s["N"].unique())
    fig, axes = plt.subplots(1, len(Ns), figsize=(5 * len(Ns), 4.2), squeeze=False)
    present = [k for k in SERIES if not s[(s["compiler"] == k[0]) & (s["precision"] == k[1])].empty]
    width = 0.8 / max(len(present), 1)

    for ax, N in zip(axes[0], Ns):
        for j, key in enumerate(present):
            name, color, _, _ = SERIES[key]
            g = s[(s["N"] == N) & (s["compiler"] == key[0]) & (s["precision"] == key[1])]
            cpu = g[g["mode"] == "cpu"]
            rows = [
                cpu[cpu["config"] == "P1"],
                cpu.nsmallest(1, "mean"),
                g[g["mode"] == "gpu_kernel"],
                g[g["mode"] == "gpu_total"],
            ]
            means = [r["mean"].iloc[0] * 1e3 if len(r) else float("nan") for r in rows]
            stds = [r["std"].iloc[0] * 1e3 if len(r) else 0.0 for r in rows]
            x = [i - 0.4 + width * (j + 0.5) for i in range(len(cats))]
            ax.bar(x, means, width=width * 0.92, yerr=stds, capsize=2, color=color, ecolor=INK,
                   hatch="//" if key[1] == 64 else None, edgecolor="white",
                   linewidth=0, label=name)
        ax.set_yscale("log")
        ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g}"))
        ax.yaxis.set_minor_formatter(FuncFormatter(lambda v, _: ""))
        ax.set_xticks(range(len(cats)), cats)
        ax.set_ylabel("tiempo por llamada (ms, escala log)", color=MUTED)
        style(ax, f"N = 2^{int(N).bit_length() - 1}")
    handles, labels = axes[0][0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", ncol=len(present), frameon=False, fontsize=9)
    fig.subplots_adjust(bottom=0.2)
    fig.suptitle("CPU contra GPU (rayado = real64)", color=INK, x=0.01, ha="left")
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    fig.savefig(out, dpi=130)
    plt.close(fig)


# ---------------------------------------------------------------------------
def main() -> None:
    if len(sys.argv) > 1:
        path = Path(sys.argv[1])
    else:
        files = sorted(glob.glob(str(Path(__file__).parent / "results" / "raw_*.csv")))
        if not files:
            sys.exit("No hay results/raw_*.csv. Corre primero ./run.sh")
        path = Path(files[-1])
    print(f"Leyendo {path}")

    df = load(path)
    s = summarize(df)
    print_tables(s)

    stamp = path.stem.replace("raw_", "")
    outdir = path.parent
    s.to_csv(outdir / f"summary_{stamp}.csv", index=False)
    plot_cpu_scaling(s, outdir / f"cpu_scaling_{stamp}.png")
    plot_cpu_vs_gpu(s, outdir / f"cpu_vs_gpu_{stamp}.png")
    print(f"\nEscritos en {outdir}/: summary_{stamp}.csv, "
          f"cpu_scaling_{stamp}.png, cpu_vs_gpu_{stamp}.png")


if __name__ == "__main__":
    main()
