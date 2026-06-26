#!/usr/bin/env bash
# Clone the upstream node sources into vendor/ at the tags matching the pinned
# images in docker-compose.yml, for the opt-in source-build overlay
# (docker-compose.build.yml). vendor/ is gitignored.
#
# Usage:
#   scripts/vendor.sh                 # fetch all three (zebra, zaino, zallet)
#   scripts/vendor.sh zaino           # fetch one
# Re-run after bumping an image pin to update the matching checkout.
#
# Tags track the image pins in docker-compose.yml; bump them together.
set -euo pipefail
cd "$(dirname "$0")/.."

declare -a ALL=(zebra zaino zallet)
declare -A URL=(
  [zebra]="https://github.com/ZcashFoundation/zebra"
  [zaino]="https://github.com/zingolabs/zaino"
  [zallet]="https://github.com/zcash/wallet"
)
declare -A REF=(
  [zebra]="v5.0.0"
  [zaino]="0.4.0-rc.2"
  [zallet]="v0.1.0-alpha.4"
)

vendor_one() {
  local name="$1" dir="vendor/$1" url="${URL[$1]}" ref="${REF[$1]}"
  if [ -d "$dir/.git" ]; then
    echo "==> $name: fetching $ref"
    git -C "$dir" fetch --depth 1 origin "$ref"
    git -C "$dir" checkout --quiet --recurse-submodules FETCH_HEAD
    git -C "$dir" submodule update --init --recursive --depth 1
  else
    echo "==> $name: cloning $ref"
    git clone --depth 1 --branch "$ref" --recurse-submodules --shallow-submodules \
      "$url" "$dir"
  fi
}

targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=("${ALL[@]}")
for t in "${targets[@]}"; do
  [ -n "${URL[$t]:-}" ] || { echo "unknown component: $t (choose: ${ALL[*]})" >&2; exit 1; }
  vendor_one "$t"
done

echo
echo "Done. Build with:"
echo "  docker compose -f docker-compose.yml -f docker-compose.build.yml build ${targets[*]}"
