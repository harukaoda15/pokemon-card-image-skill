#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 \"https://tcgstore.io/cards/<id>\" /absolute/path/output_root" >&2
  exit 1
fi

card_url="$1"
output_root="$2"

html="$(curl -sSL "$card_url")"
json="$(printf "%s" "$html" | rg -o '<script id="__NEXT_DATA__" type="application/json">.*</script>' | sed -E 's#^<script id="__NEXT_DATA__" type="application/json">##; s#</script>$##')"

if [ -z "${json:-}" ]; then
  echo "Failed to parse __NEXT_DATA__ from $card_url" >&2
  exit 1
fi

tmp_json="$(mktemp)"
printf "%s" "$json" > "$tmp_json"

parsed_tsv="$(mktemp)"
python3 - "$tmp_json" "$parsed_tsv" <<'PY'
import json
import re
import sys

p = sys.argv[1]
out = sys.argv[2]
with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)

card = d["props"]["pageProps"]["cardData"]
code = str(card.get("code", "")).zfill(5)
name = card.get("name", "").strip() or "カード"
name = re.sub(r'[\\/:*?"<>|]', " ", name)
name = re.sub(r"\s+", " ", name).strip()

urls = []
for k in ("main_image_url", "main_image_url_1", "main_image_url_2", "main_image_url_origin"):
    v = card.get(k)
    if v:
        urls.append(v)
for ci in card.get("card_images", []):
    for k in ("image_url", "image_url_1", "image_url_2", "image_url_origin"):
        v = ci.get(k)
        if v:
            urls.append(v)

seen = set()
uniq = []
for u in urls:
    if u not in seen:
        uniq.append(u)
        seen.add(u)

print(code)
print(name)
with open(out, "w", encoding="utf-8") as wf:
    wf.write(code + "\n")
    wf.write(name + "\n")
    for u in uniq:
        wf.write(u + "\n")
PY

rm -f "$tmp_json"

card_id="$(sed -n '1p' "$parsed_tsv")"
card_name="$(sed -n '2p' "$parsed_tsv")"
urls=()
while IFS= read -r line; do
  [ -z "${line:-}" ] && continue
  urls+=("$line")
done < <(sed -n '3,$p' "$parsed_tsv")
rm -f "$parsed_tsv"

base="$output_root/tcgstore_${card_id}"
with_bg_dir="$base/with_bg"
no_bg_dir="$base/no_bg"
mkdir -p "$with_bg_dir" "$no_bg_dir"

manifest="$base/manifest.tsv"
: > "$manifest"

best_with_bg=""
best_no_bg=""
best_with_bg_score=-999999
best_no_bg_score=-999999

idx=0
for u in "${urls[@]}"; do
  idx=$((idx+1))
  tmp="$base/.tmp_$idx"
  if ! curl -sSL "$u" -o "$tmp"; then
    rm -f "$tmp"
    continue
  fi

  w=$(sips -g pixelWidth "$tmp" 2>/dev/null | awk '/pixelWidth/{print $2}' || true)
  h=$(sips -g pixelHeight "$tmp" 2>/dev/null | awk '/pixelHeight/{print $2}' || true)
  a=$(sips -g hasAlpha "$tmp" 2>/dev/null | awk '/hasAlpha/{print tolower($2)}' || true)
  slot="$(printf "%s" "$u" | sed -nE 's#^.*/cards/[^/]+/([0-9]+)/.*#\1#p')"
  [ -z "${w:-}" ] && w=0
  [ -z "${h:-}" ] && h=0
  [ -z "${a:-}" ] && a=no
  [ -z "${slot:-}" ] && slot=999

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$idx" "$u" "$w" "$h" "$a" "$slot" >> "$manifest"

  # with_bg: square-ish image from slot 0 (front) preferred.
  with_score=0
  if [ "$w" -gt 0 ] && [ "$h" -gt 0 ]; then
    # closeness to square
    sq_diff=$(awk -v w="$w" -v h="$h" 'BEGIN{d=(w>h?w-h:h-w); print d}')
    with_score=$(awk -v d="$sq_diff" -v a="$a" -v slot="$slot" -v u="$u" 'BEGIN{
      s=100000-d;
      if(a=="no") s+=30000;
      if(slot==0) s+=60000; else s-=30000;
      if(u ~ /\/image_url_origin$/) s-=20000;
      print s
    }')
  fi
  if awk -v s="$with_score" -v best="$best_with_bg_score" 'BEGIN{exit !(s>best)}'; then
    best_with_bg_score="$with_score"
    best_with_bg="$tmp"
  else
    rm -f "$tmp"
    continue
  fi
done

# Need re-download for no_bg scoring (best_with_bg temp path is retained)
idx=0
for u in "${urls[@]}"; do
  idx=$((idx+1))
  tmp="$base/.tmp_nobg_$idx"
  if ! curl -sSL "$u" -o "$tmp"; then
    rm -f "$tmp"
    continue
  fi
  w=$(sips -g pixelWidth "$tmp" 2>/dev/null | awk '/pixelWidth/{print $2}' || true)
  h=$(sips -g pixelHeight "$tmp" 2>/dev/null | awk '/pixelHeight/{print $2}' || true)
  a=$(sips -g hasAlpha "$tmp" 2>/dev/null | awk '/hasAlpha/{print tolower($2)}' || true)
  slot="$(printf "%s" "$u" | sed -nE 's#^.*/cards/[^/]+/([0-9]+)/.*#\1#p')"
  [ -z "${w:-}" ] && w=0
  [ -z "${h:-}" ] && h=0
  [ -z "${a:-}" ] && a=no
  [ -z "${slot:-}" ] && slot=999

  no_score=0
  if [ "$w" -gt 0 ] && [ "$h" -gt 0 ]; then
    # no_bg: portrait, alpha, and slot 0 (front) are strongly preferred.
    no_score=$(awk -v w="$w" -v h="$h" -v a="$a" -v slot="$slot" -v u="$u" 'BEGIN{
      r=h/w;
      d=(r>1.40?r-1.40:1.40-r);
      s=100000-(d*10000);
      if(h>w) s+=20000; else s-=20000;
      if(a=="yes") s+=30000; else s-=30000;
      if(slot==0) s+=120000; else s-=70000;
      if(u ~ /\/image_url_origin$/) s-=20000;
      print s
    }')
  fi
  if awk -v s="$no_score" -v best="$best_no_bg_score" 'BEGIN{exit !(s>best)}'; then
    [ -n "$best_no_bg" ] && rm -f "$best_no_bg"
    best_no_bg_score="$no_score"
    best_no_bg="$tmp"
  else
    rm -f "$tmp"
  fi
done

target_base="${card_id}_${card_name}"
with_bg_name="${target_base}.jpg"
no_bg_name="${target_base}.png"
# Clean stale files from previous format rules.
rm -f "$with_bg_dir/${target_base}.png" "$no_bg_dir/${target_base}.jpg"
if [ -n "$best_with_bg" ] && [ -f "$best_with_bg" ]; then
  sips -s format jpeg "$best_with_bg" --out "$with_bg_dir/$with_bg_name" >/dev/null 2>&1 || cp -f "$best_with_bg" "$with_bg_dir/$with_bg_name"
fi
if [ -n "$best_no_bg" ] && [ -f "$best_no_bg" ]; then
  sips -s format png "$best_no_bg" --out "$no_bg_dir/$no_bg_name" >/dev/null 2>&1 || cp -f "$best_no_bg" "$no_bg_dir/$no_bg_name"
fi

rm -f "$base"/.tmp_* "$base"/.tmp_nobg_* 2>/dev/null || true
if [ "${KEEP_DEBUG:-0}" != "1" ]; then
  rm -f "$manifest" "$base"/[0-9]*.png "$base"/[0-9]*.jpg "$base"/[0-9]*.jpeg "$base"/[0-9]*.webp 2>/dev/null || true
fi

echo "saved_with_bg=$with_bg_dir/$with_bg_name"
echo "saved_no_bg=$no_bg_dir/$no_bg_name"
