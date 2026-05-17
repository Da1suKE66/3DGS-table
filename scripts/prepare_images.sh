#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'MSG'
Usage:
  ./scripts/prepare_images.sh <scene_name> <source_photo_dir>

Example:
  ./scripts/prepare_images.sh desk ~/Desktop/desk_photos
MSG
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

scene_name="$1"
source_dir="$2"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scene_dir="$root_dir/scenes/$scene_name"
raw_dir="$scene_dir/raw"
images_dir="$scene_dir/images"

if [[ ! -d "$source_dir" ]]; then
  printf "Source directory does not exist: %s\n" "$source_dir" >&2
  exit 1
fi

mkdir -p "$raw_dir" "$images_dir"

if find "$images_dir" -maxdepth 1 -type f | grep -q .; then
  cat <<MSG >&2
The images directory already contains files:
  $images_dir

Use a new scene name, or clear that directory before importing again.
MSG
  exit 1
fi

count=0

while IFS= read -r -d '' file; do
  name="$(basename "$file")"
  ext="${name##*.}"
  ext_lower="$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"
  count=$((count + 1))

  case "$ext_lower" in
    jpg|jpeg)
      out="$images_dir/$(printf "img_%04d.jpg" "$count")"
      cp "$file" "$out"
      ;;
    png)
      out="$images_dir/$(printf "img_%04d.png" "$count")"
      cp "$file" "$out"
      ;;
    heic|heif)
      if ! command -v sips >/dev/null 2>&1; then
        printf "Cannot convert HEIC/HEIF without sips: %s\n" "$file" >&2
        exit 1
      fi
      out="$images_dir/$(printf "img_%04d.jpg" "$count")"
      sips -s format jpeg "$file" --out "$out" >/dev/null
      ;;
    *)
      count=$((count - 1))
      ;;
  esac
done < <(find "$source_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' -o -iname '*.heif' \) -print0)

if [[ "$count" -eq 0 ]]; then
  printf "No supported image files found in: %s\n" "$source_dir" >&2
  exit 1
fi

printf "Imported %d image(s) into:\n  %s\n" "$count" "$images_dir"

