# PSA Skill Handoff Memo

## Scope
- This session is **PSA-skill only**.
- Do not run or modify single-card workflows here.

## Sheet
- Source sheet: `https://docs.google.com/spreadsheets/d/1eZSHK5GPy4YfCcGLhKKrDU4E-cWp5Q-aqKEeGOAGWg8/edit?gid=274424284#gid=274424284`
- ID source column: **K column**
- K column format may be:
  - 4/5 digit ID (e.g. `4185`)
  - URL (ID is trailing numeric part)

## IDs To Consider (K column, normalized to 5 digits)
- `04185 05285 05292 04940 04932 05199 05047 05300 05364 03996 01120 01217 01417 02472 02703 01455 04376 04407 05279 05338 05082 04943 04949 04938`

## Previously Confirmed Existing Set (from user-provided screenshot)
- `04185 04376 04407 04932 04938 04940 04943 04949 05047 05082 05199 05279 05285 05292 05338`

## Previously Identified Missing Set
- `01120 01217 01417 01455 02472 02703 03996 05300 05364`

## Output Structure (mandatory)
- Output must be flat two folders only:
  - `with_bg/`
  - `no_bg/`
- Do not keep nested `tcgstore_<id>/` folders in final delivery.

## Mosaic Rule (mandatory)
- Apply mosaic to **both** `with_bg` and `no_bg`.
- Keep mosaic placement consistent with approved reference images:
  - `/Users/uemuraharuka/Library/CloudStorage/GoogleDrive-harukaoda@cryptogames.co.jp/共有ドライブ/TCG STORE/オリパ商品画像/PSAモザイク付き/no_bg/Oripa_Eevee_1/04185_ブラッキーex.png`
  - `/Users/uemuraharuka/Library/CloudStorage/GoogleDrive-harukaoda@cryptogames.co.jp/共有ドライブ/TCG STORE/オリパ商品画像/PSAモザイク付き/with_bg/Oripa_Eevee_1/03511_with_bg.png`

## Redaction Implementation (in this repo)
- Script: `scripts/psa_label_redact.py`
- Baselines doc: `docs/PSA_REDACTION_BASELINES.md`
- Policy: fixed baseline + bounded micro-adjustment (no large drift).

## Safety Rules
- Keep repository on `origin/main` behavior unless user explicitly asks changes.
- No ad-hoc one-off pipeline changes during production output.
- If any mismatch is found, stop and report before bulk rerun.
