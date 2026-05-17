#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'MSG'
Usage:
  ./scripts/export_sparse_ply.sh <scene_name> [model_id]

Examples:
  ./scripts/export_sparse_ply.sh desk
  ./scripts/export_sparse_ply.sh desk 1
MSG
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

scene_name="$1"
model_id="${2:-0}"

if ! command -v colmap >/dev/null 2>&1; then
  printf "COLMAP is not installed or not on PATH. Run ./scripts/check_env.sh first.\n" >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scene_dir="$root_dir/scenes/$scene_name"
model_dir="$scene_dir/sparse/$model_id"
output_path="$scene_dir/sparse/model_$model_id.ply"

if [[ ! -d "$model_dir" ]]; then
  printf "COLMAP model directory does not exist: %s\n" "$model_dir" >&2
  exit 1
fi

colmap model_converter \
  --input_path "$model_dir" \
  --output_path "$output_path" \
  --output_type PLY

printf "Exported sparse point cloud:\n  %s\n" "$output_path"

