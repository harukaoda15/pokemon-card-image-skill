#!/usr/bin/env python3
"""PSA label redaction for with_bg/no_bg outputs.

Policy: fixed baseline + micro-adjustment.
- with_bg: 1620x1620 baseline, then bounded search.
- no_bg: 987x1620 baseline by ratio, then bounded search.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable


def require_deps():
    try:
        import numpy as np  # noqa: F401
        from PIL import Image, ImageFilter  # noqa: F401
    except Exception as e:  # pragma: no cover
        raise SystemExit(
            "Missing dependencies. Install with: python3 -m pip install pillow numpy\n"
            f"Detail: {e}"
        )


# with_bg baseline (1620x1620)
WITH_BG_BAR_BASE = (446, 262, 672, 308)
WITH_BG_NUM_BASE = (961, 271, 1195, 308)

# no_bg baseline (987x1620) -> ratio
NO_BG_BAR_BASE = (133, 264, 350, 311)
NO_BG_NUM_BASE = (654, 268, 853, 311)


def clamp(rect: tuple[int, int, int, int], w: int, h: int) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = rect
    x1 = max(0, min(w - 2, x1))
    y1 = max(0, min(h - 2, y1))
    x2 = max(x1 + 1, min(w, x2))
    y2 = max(y1 + 1, min(h, y2))
    return x1, y1, x2, y2


def no_bg_rects(w: int, h: int) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    bx1, by1, bx2, by2 = NO_BG_BAR_BASE
    nx1, ny1, nx2, ny2 = NO_BG_NUM_BASE
    b = (int(bx1 / 987 * w), int(by1 / 1620 * h), int(bx2 / 987 * w), int(by2 / 1620 * h))
    n = (int(nx1 / 987 * w), int(ny1 / 1620 * h), int(nx2 / 987 * w), int(ny2 / 1620 * h))
    return b, n


def with_bg_rects(w: int, h: int) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    bx1, by1, bx2, by2 = WITH_BG_BAR_BASE
    nx1, ny1, nx2, ny2 = WITH_BG_NUM_BASE
    b = (int(bx1 / 1620 * w), int(by1 / 1620 * h), int(bx2 / 1620 * w), int(by2 / 1620 * h))
    n = (int(nx1 / 1620 * w), int(ny1 / 1620 * h), int(nx2 / 1620 * w), int(ny2 / 1620 * h))
    return b, n


def tune_rect(gray, base: tuple[int, int, int, int], *, dx_max: int, dy_max: int, mode: str):
    import numpy as np

    bx1, by1, bx2, by2 = base
    rw = bx2 - bx1
    rh = by2 - by1
    best = base
    best_score = -10**18

    for dy in range(-dy_max, dy_max + 1):
        for dx in range(-dx_max, dx_max + 1):
            rect = clamp((bx1 + dx, by1 + dy, bx1 + dx + rw, by1 + dy + rh), gray.shape[1], gray.shape[0])
            x1, y1, x2, y2 = rect
            c = gray[y1:y2, x1:x2].astype(np.float32)
            if c.size == 0:
                continue
            gx = np.abs(np.diff(c, axis=1)).sum()
            gy = np.abs(np.diff(c, axis=0)).sum()
            dark = float((c < 145).mean())

            if mode == "barcode":
                score = (gx - 0.55 * gy) * (0.7 + dark)
            else:
                bar_like = gx - gy
                score = -abs(dark - 0.17) * 1200 + 0.03 * (gx + gy) - 0.015 * max(0, bar_like)

            if score > best_score:
                best_score = score
                best = rect

    return best


def blur_rects(img, rects: Iterable[tuple[int, int, int, int]], radius: int):
    from PIL import ImageFilter

    for x1, y1, x2, y2 in rects:
        patch = img.crop((x1, y1, x2, y2)).filter(ImageFilter.GaussianBlur(radius=radius))
        img.paste(patch, (x1, y1, x2, y2))


def process_one(path: Path, variant: str, radius: int):
    import numpy as np
    from PIL import Image

    img = Image.open(path).convert("RGBA" if variant == "no_bg" else "RGB")
    gray = np.array(img.convert("L"))
    w, h = img.size

    if variant == "with_bg":
        b0, n0 = with_bg_rects(w, h)
    else:
        b0, n0 = no_bg_rects(w, h)

    b = tune_rect(gray, b0, dx_max=28, dy_max=14, mode="barcode")
    n = tune_rect(gray, n0, dx_max=35, dy_max=12, mode="number")

    # Keep micro-adjust bounded
    if abs(b[0] - b0[0]) > 40 or abs(b[1] - b0[1]) > 18:
        b = clamp(b0, w, h)
    if abs(n[0] - n0[0]) > 40 or abs(n[1] - n0[1]) > 18:
        n = clamp(n0, w, h)

    blur_rects(img, [b, n], radius=radius)

    if variant == "with_bg":
        img.convert("RGB").save(path, quality=95)
    else:
        img.save(path)


def collect_files(with_bg_dir: Path, no_bg_dir: Path, files_csv: str):
    selected = {x.strip() for x in files_csv.split(",") if x.strip()} if files_csv else None

    with_bg_files = sorted(with_bg_dir.glob("*.jpg"))
    no_bg_files = sorted(no_bg_dir.glob("*.png"))

    if selected is not None:
        with_bg_files = [p for p in with_bg_files if p.name in selected]
        no_bg_files = [p for p in no_bg_files if p.name in selected]

    return with_bg_files, no_bg_files


def main():
    require_deps()

    p = argparse.ArgumentParser(description="Apply PSA label blur to with_bg/no_bg outputs")
    p.add_argument("--with-bg-dir", default="/Users/uemuraharuka/CascadeProjects/PSA-card-image-skill/outputs/with_bg")
    p.add_argument("--no-bg-dir", default="/Users/uemuraharuka/CascadeProjects/PSA-card-image-skill/outputs/no_bg")
    p.add_argument("--mode", choices=["check", "apply"], default="apply")
    p.add_argument("--files", default="", help="comma-separated filenames to process only specific files")
    p.add_argument("--radius", type=int, default=6)
    args = p.parse_args()

    with_bg_dir = Path(args.with_bg_dir)
    no_bg_dir = Path(args.no_bg_dir)

    if not with_bg_dir.exists() or not no_bg_dir.exists():
        raise SystemExit("with_bg/no_bg directory not found")

    with_bg_files, no_bg_files = collect_files(with_bg_dir, no_bg_dir, args.files)

    if args.mode == "check":
        print(f"with_bg={len(with_bg_files)}")
        print(f"no_bg={len(no_bg_files)}")
        for pth in with_bg_files:
            print("WITH", pth)
        for pth in no_bg_files:
            print("NO", pth)
        return

    ok = 0
    ng = 0
    for pth in with_bg_files:
        try:
            process_one(pth, "with_bg", args.radius)
            ok += 1
            print("OK", pth)
        except Exception as e:
            ng += 1
            print("NG", pth, e)

    for pth in no_bg_files:
        try:
            process_one(pth, "no_bg", args.radius)
            ok += 1
            print("OK", pth)
        except Exception as e:
            ng += 1
            print("NG", pth, e)

    print(f"done ok={ok} ng={ng}")


if __name__ == "__main__":
    main()
