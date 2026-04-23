# PSA Redaction Baselines

This repository now owns the PSA label redaction logic.

## Policy

- Fixed baseline first
- Then micro-adjustment only (bounded)
- Apply to both folders:
  - `outputs/with_bg`
  - `outputs/no_bg`

## Baseline Coordinates

### with_bg baseline (1620x1620 origin)
- barcode: `(446,262,672,308)`
- number: `(961,271,1195,308)`

### no_bg baseline (987x1620 origin, ratio applied)
- barcode: `(133,264,350,311)`
- number: `(654,268,853,311)`

## Command

```bash
python3 /Users/uemuraharuka/CascadeProjects/PSA-card-image-skill/scripts/psa_label_redact.py --mode apply
```

Check target files only:

```bash
python3 /Users/uemuraharuka/CascadeProjects/PSA-card-image-skill/scripts/psa_label_redact.py --mode check
```

Specific files only:

```bash
python3 /Users/uemuraharuka/CascadeProjects/PSA-card-image-skill/scripts/psa_label_redact.py --mode apply --files "01120_エーフィ.jpg,01120_エーフィ.png"
```
