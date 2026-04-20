# pokemon-card-image-collector

Codex skill to collect and save Pokemon card-only images from web pages.

## What it does

- Collects card images from a card list
- Prioritizes Japanese marketplace sources:
  1. cardrush-pokemon.jp
  2. snkrdunk.com
  3. other product pages
  4. Bulbapedia fallback
- Rejects non-card assets (logos/icons/card backs/wordmarks)
- Applies card-like portrait ratio validation
- Outputs `sources.tsv` and `download_log.tsv`

## Install

Copy this folder into your Codex skills directory:

```bash
cp -R pokemon-card-image-collector ~/.codex/skills/
```

## Usage

```bash
bash ~/.codex/skills/pokemon-card-image-collector/scripts/download_from_tsv.sh /absolute/path/cards.tsv /absolute/path/output_dir
```

`cards.tsv` format:

```tsv
slug\tpage_url
example_card\thttps://www.cardrush-pokemon.jp/product/73305
```
