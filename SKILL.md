---
name: pokemon-card-image-collector
description: Collect and save Pokémon card images from the web when the user provides a card list and asks to gather images, download them, and report the Finder path. Use for requests like "このカード画像を全部集めて保存して", "download these Pokémon card images", or similar bulk card-image collection tasks.
---

# Pokemon Card Image Collector

## Overview

Use this skill when the user provides a list of Pokémon cards and asks to gather images from the web, save them locally, and share the folder location.

## Workflow

1. Parse the card list into one item per line.
2. Create an output folder in the workspace with a timestamp-like suffix, e.g. `pokemon_card_images_YYYYMMDD`.
3. For each card item, find a reliable card page and extract a direct image URL.
Preferred source order:
- Cardrush (`cardrush-pokemon.jp`)
- SNKRDUNK (`snkrdunk.com`)
- Other card marketplace/listing pages with product images
- Bulbapedia (`archives.bulbagarden.net`) as fallback
4. Download one image per card into the output folder using a deterministic slug filename.
5. Create logs:
- `sources.tsv`: `slug<TAB>source_page<TAB>image_url`
- `download_log.tsv`: `slug<TAB>saved_path<TAB>status`
6. Validate downloaded file count matches requested item count, and fix obvious mismatches when a wrong non-card image is detected.
7. Return the absolute folder path so the user can open it in Finder.

## Quality Rules

- Prefer stable, reference-like sources over random marketplace thumbnails.
- Prefer Japanese card retail pages (Cardrush first) when available.
- Keep exactly one file per requested card unless the user asks for front/back or multiple variants.
- If numbering/edition ambiguity exists, prioritize the exact number the user provided.
- If one card cannot be resolved reliably, log it as `NO_IMAGE_FOUND` and continue with the rest.
- **Mandatory**: save only background-free card-only images. Do not save screenshots, marketplace UI captures, logos, icons, or pages with surrounding UI.
- **Mandatory**: reject non-card assets (e.g. rarity icons, attack symbols, card backs, wordmarks).
- **Mandatory**: reject images whose geometry is not card-like portrait ratio.
- If all candidates fail these checks, write `NO_VALID_CARD_IMAGE` in `download_log.tsv`.

## Validation Standard (Required)

Treat an image as valid only if all are true:

1. Source is a direct image file URL (not HTML page URL).
2. URL is not an excluded asset pattern (`wordmark`, `rarity`, `attack`, `logo`, `icon`, `card_back` etc.).
3. Image is portrait and card-like (`height > width`, ratio close to trading card).
4. Visual target is the card itself (no marketplace frame/background capture).

If uncertain, skip the candidate and continue searching.

## Command Pattern

Use the helper script for repeatable execution:

```bash
bash /Users/uemuraharuka/.codex/skills/pokemon-card-image-collector/scripts/download_from_tsv.sh /absolute/path/cards.tsv /absolute/path/output_dir
```

Input TSV format:

```tsv
slug\tpage_url
2016_Pikachu_Poncho_208P\thttps://bulbapedia.bulbagarden.net/wiki/Poncho-wearing_Pikachu_(XY-P_Promo_208)
```

If the user only gives card names (no URLs), search first, then generate this TSV and run the script.
