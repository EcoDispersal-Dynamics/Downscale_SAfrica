#!/bin/bash
# SLURM array job script for ESA deterministic variant regions
#SBATCH --partition=rogp
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=3-00:00:00

set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
variant_label="$(basename "$script_dir")"

if [ -f /etc/profile.d/modules.sh ]; then
    . /etc/profile.d/modules.sh
fi

module purge
module load r/4.2.2-gcc-11.3.1

: "${R_SCRIPT:?R_SCRIPT not set}"
: "${SCENARIO:?SCENARIO not set}"
: "${SLURM_ARRAY_TASK_ID:?SLURM_ARRAY_TASK_ID not set}"

echo "Running ESA ${variant_label}: $SCENARIO region ${SLURM_ARRAY_TASK_ID}"
echo "Host: $(hostname)  CPUs: ${SLURM_CPUS_PER_TASK:-unknown}  Mem: ${SLURM_MEM_PER_NODE:-unknown}"
Rscript "$R_SCRIPT" "$SCENARIO" "$SLURM_ARRAY_TASK_ID"
