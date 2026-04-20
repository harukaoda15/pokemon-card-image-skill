#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 /absolute/path/cards.tsv /absolute/path/output_dir" >&2
  exit 1
fi

in_tsv="$1"
out_dir="$2"

mkdir -p "$out_dir"
: > "$out_dir/sources.tsv"
: > "$out_dir/download_log.tsv"

is_excluded_url() {
  local u="$1"
  printf "%s" "$u" | rg -qi 'bulbapedia_wordmark|tcg_card_back|rarity_|-attack\.png|project_tcg_logo|/logo|/icon|energy|wordmark|opengraph-image'
}

is_card_like_image() {
  local img="$1"
  local dims
  dims=$(sips -g pixelWidth -g pixelHeight "$img" 2>/dev/null | awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{print w" "h}')
  local w h
  w=$(printf "%s" "$dims" | awk '{print $1}')
  h=$(printf "%s" "$dims" | awk '{print $2}')

  if [ -z "${w:-}" ] || [ -z "${h:-}" ]; then
    return 1
  fi
  if [ "$w" -lt 200 ] || [ "$h" -lt 280 ]; then
    return 1
  fi
  if [ "$h" -le "$w" ]; then
    return 1
  fi

  # Typical TCG card portrait is roughly h/w ~= 1.39. Allow tolerance.
  awk -v w="$w" -v h="$h" 'BEGIN { r=h/w; exit !(r >= 1.28 && r <= 1.55) }'
}

while IFS=$'\t' read -r slug page; do
  [ -z "${slug:-}" ] && continue
  [ -z "${page:-}" ] && continue

  html=$(curl -sSL "$page" || true)
  if [ -z "$html" ]; then
    echo -e "$slug\t$page\tNO_IMAGE_FOUND" >> "$out_dir/download_log.tsv"
    continue
  fi

  # Prefer card marketplace product images first, then Bulbapedia archive images.
  if printf "%s" "$page" | rg -q 'cardrush-pokemon\.jp|snkrdunk\.com'; then
    candidates=$(
      {
        printf "%s" "$html" | rg -o "https://[^\" ]+\\.(jpg|jpeg|png|webp)(\\?[^\" ]+)?" || true
        printf "%s" "$html" | rg -o 'property="og:image" content="[^"]+"' | sed -E 's/^property="og:image" content="//; s/"$//' || true
      } | sort -u
    )
  else
    candidates=""
  fi

  if [ -z "${candidates:-}" ]; then
    candidates=$(printf "%s" "$html" \
      | rg -o "https://archives\\.bulbagarden\\.net/media/upload/[^\" ]+" \
      | rg -v "TCG_Card_Back" \
      | sort -u || true)
  fi

  if [ -z "${candidates:-}" ]; then
    echo -e "$slug\t$page\tNO_IMAGE_FOUND" >> "$out_dir/download_log.tsv"
    continue
  fi

  chosen=""
  while IFS= read -r img; do
    [ -z "${img:-}" ] && continue
    if is_excluded_url "$img"; then
      continue
    fi

    clean="${img%%\?*}"
    ext="${clean##*.}"
    case "$ext" in
      jpg|jpeg|png|webp) ;;
      *) ext="jpg" ;;
    esac

    tmp="$out_dir/.tmp_${slug}.${ext}"
    if ! curl -sSL "$img" -o "$tmp"; then
      rm -f "$tmp"
      continue
    fi

    if is_card_like_image "$tmp"; then
      chosen="$img"
      mv "$tmp" "$out_dir/${slug}.${ext}"
      break
    fi
    rm -f "$tmp"
  done <<< "$candidates"

  if [ -n "$chosen" ]; then
    clean="${chosen%%\?*}"
    ext="${clean##*.}"
    case "$ext" in
      jpg|jpeg|png|webp) ;;
      *) ext="jpg" ;;
    esac
    save="$out_dir/${slug}.${ext}"
    echo -e "$slug\t$page\t$chosen" >> "$out_dir/sources.tsv"
    echo -e "$slug\t$save\tOK" >> "$out_dir/download_log.tsv"
  else
    echo -e "$slug\t$page\tNO_VALID_CARD_IMAGE" >> "$out_dir/download_log.tsv"
  fi
done < "$in_tsv"
