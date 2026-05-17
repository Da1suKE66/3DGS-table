#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'MSG'
Usage:
  ./scripts/run_colmap_sparse.sh <scene_name> [--force]

Examples:
  ./scripts/run_colmap_sparse.sh desk
  ./scripts/run_colmap_sparse.sh desk --force
  MATCHER=exhaustive ./scripts/run_colmap_sparse.sh desk --force

MATCHER can be:
  sequential   good default when photos were shot in order
  exhaustive   slower, better when photo order is mixed
MSG
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

scene_name="$1"
force="${2:-}"

if [[ -n "$force" && "$force" != "--force" ]]; then
  usage
  exit 1
fi

if ! command -v colmap >/dev/null 2>&1; then
  printf "COLMAP is not installed or not on PATH. Run ./scripts/check_env.sh first.\n" >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scene_dir="$root_dir/scenes/$scene_name"
images_dir="$scene_dir/images"
database_path="$scene_dir/database.db"
sparse_dir="$scene_dir/sparse"
matcher="${MATCHER:-sequential}"
max_image_size="${COLMAP_MAX_IMAGE_SIZE:-2000}"
feature_threads="${COLMAP_FEATURE_THREADS:-2}"
match_threads="${COLMAP_MATCH_THREADS:-4}"
max_num_features="${COLMAP_MAX_NUM_FEATURES:-6000}"

if [[ ! -d "$images_dir" ]]; then
  printf "Images directory does not exist: %s\n" "$images_dir" >&2
  exit 1
fi

image_count="$(find "$images_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | wc -l | tr -d ' ')"

if [[ "$image_count" -eq 0 ]]; then
  printf "No JPG/JPEG/PNG images found in: %s\n" "$images_dir" >&2
  exit 1
fi

if [[ -e "$database_path" || -d "$sparse_dir" ]]; then
  if [[ "$force" == "--force" ]]; then
    rm -rf "$database_path" "$sparse_dir"
  else
    cat <<MSG >&2
Existing COLMAP output found for scene "$scene_name".
Rerun with --force to rebuild:

  ./scripts/run_colmap_sparse.sh $scene_name --force

MSG
    exit 1
  fi
fi

mkdir -p "$sparse_dir"

printf "Running COLMAP sparse reconstruction for scene '%s' with %s image(s).\n" "$scene_name" "$image_count"
printf "Matcher: %s\n\n" "$matcher"
printf "Max image size: %s\n" "$max_image_size"
printf "Feature threads: %s\n" "$feature_threads"
printf "Matching threads: %s\n" "$match_threads"
printf "Max SIFT features/image: %s\n\n" "$max_num_features"

colmap feature_extractor \
  --database_path "$database_path" \
  --image_path "$images_dir" \
  --ImageReader.single_camera 1 \
  --ImageReader.camera_model OPENCV \
  --FeatureExtraction.use_gpu 0 \
  --FeatureExtraction.num_threads "$feature_threads" \
  --FeatureExtraction.max_image_size "$max_image_size" \
  --SiftExtraction.max_num_features "$max_num_features"

case "$matcher" in
  sequential)
    colmap sequential_matcher \
      --database_path "$database_path" \
      --FeatureMatching.use_gpu 0 \
      --FeatureMatching.num_threads "$match_threads"
    ;;
  exhaustive)
    colmap exhaustive_matcher \
      --database_path "$database_path" \
      --FeatureMatching.use_gpu 0 \
      --FeatureMatching.num_threads "$match_threads"
    ;;
  *)
    printf "Unsupported MATCHER: %s\n" "$matcher" >&2
    exit 1
    ;;
esac

colmap mapper \
  --database_path "$database_path" \
  --image_path "$images_dir" \
  --output_path "$sparse_dir" \
  --Mapper.ba_refine_focal_length 1 \
  --Mapper.ba_refine_principal_point 0 \
  --Mapper.ba_refine_extra_params 1

cat <<MSG

Sparse reconstruction finished.

Check for model files under:
  $sparse_dir/0

Next:
  ./scripts/export_sparse_ply.sh $scene_name

MSG
