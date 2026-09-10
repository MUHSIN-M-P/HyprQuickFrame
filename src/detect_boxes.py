#!/usr/bin/env python3
"""
detect_boxes.py — Theme-adaptive rectangular element & paragraph block detector
Usage: python3 detect_boxes.py <image_path> <monitor_scale>
Output: JSON array of {x, y, width, height} in logical (QML) coordinates
"""
import sys
import json
import cv2
import numpy as np


def auto_canny(image: np.ndarray, sigma: float = 0.33) -> np.ndarray:
    """Adaptive Canny thresholds based on median image brightness.
    Works robustly on dark, light, and OLED themes."""
    v = float(np.median(image))
    lower = int(max(10, (1.0 - sigma) * v))
    upper = int(min(250, (1.0 + sigma) * v))
    if lower >= upper:
        lower = max(10, int(v * 0.5))
        upper = min(250, int(v * 1.5))
    return cv2.Canny(image, lower, upper)


def detect_rectangles(image_path: str, scale: float = 1.0) -> None:
    img = cv2.imread(image_path)
    if img is None:
        print("[]")
        return

    orig_h, orig_w = img.shape[:2]
    D = 0.5  # work at half resolution for speed (4x fewer pixels)

    small = cv2.resize(img, (0, 0), fx=D, fy=D, interpolation=cv2.INTER_AREA)
    sh, sw = small.shape[:2]
    gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)

    factor = 1.0 / (D * scale)  # half-pixel → logical coord
    raw: set[tuple[int, int, int, int]] = set()

    # ── 1. Dedicated Cohesive Paragraph Block Detection (Sobel + Dual Morphology) ──
    grad_x = cv2.Sobel(gray, cv2.CV_16S, 1, 0, ksize=3)
    abs_grad = cv2.convertScaleAbs(grad_x)
    _, thresh = cv2.threshold(abs_grad, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Word closing (horizontal)
    k_word = cv2.getStructuringElement(cv2.MORPH_RECT, (12, 2))
    connected_words = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, k_word)

    # Paragraph closing (vertical line bridging)
    k_block = cv2.getStructuringElement(cv2.MORPH_RECT, (8, 12))
    connected_blocks = cv2.morphologyEx(connected_words, cv2.MORPH_CLOSE, k_block)

    contours, _ = cv2.findContours(connected_blocks, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in contours:
        bx, by, bw, bh = cv2.boundingRect(c)
        if bw >= 20 and bh >= 7:
            pad = 10  # ~10px padding specifically for text-based paragraph boxes
            max_w = int(orig_w / scale)
            max_h = int(orig_h / scale)
            lx = max(0, int(round(bx * factor)) - pad)
            ly = max(0, int(round(by * factor)) - pad)
            lw = min(max_w - lx, int(round(bw * factor)) + 2 * pad)
            lh = min(max_h - ly, int(round(bh * factor)) + 2 * pad)
            if lw >= 24 and lh >= 12:
                raw.add((lx, ly, lw, lh))

    # ── 2. Adaptive Edge Detection for UI Elements (Buttons, Cards, Chips) ─────────
    edges = auto_canny(gray)

    k_tight = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    k_line  = cv2.getStructuringElement(cv2.MORPH_RECT, (14, 4))
    k_large = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 9))

    tight = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, k_tight)
    line  = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, k_line)
    large = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, k_large)

    # Foreground segmentation
    small_f = small.astype(np.float32)
    border  = np.r_[small[0], small[-1], small[:, 0], small[:, -1]]
    bg      = np.median(border, axis=0).astype(np.float32)
    dsq     = np.einsum("ijk,ijk->ij", small_f - bg, small_f - bg)
    fg_map  = cv2.morphologyEx((dsq > 144).astype(np.uint8) * 255, cv2.MORPH_CLOSE, k_line)

    min_ws, min_hs = max(5, int(18 * D)), max(4, int(10 * D))
    for bmap in (tight, line, large, fg_map):
        contours, _ = cv2.findContours(bmap, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
        for c in contours:
            bx, by, bw, bh = cv2.boundingRect(c)
            if bw >= min_ws and bh >= min_hs and bw * bh <= sw * sh * 0.97:
                lx = int(round(bx * factor))
                ly = int(round(by * factor))
                lw = int(round(bw * factor))
                lh = int(round(bh * factor))
                if lw >= 18 and lh >= 10:
                    raw.add((lx, ly, lw, lh))

    # ── Sort by area ascending (inner elements before outer containers) ────────────
    candidates = sorted(raw, key=lambda t: t[2] * t[3])

    # ── Spatial grid deduplication ───────────────────────────────────────────────
    grid: dict[tuple[int, int], list[tuple[int, int, int, int]]] = {}
    cell_size = 32
    filtered: list[tuple[int, int, int, int]] = []

    for lx, ly, lw, lh in candidates:
        cx, cy = lx // cell_size, ly // cell_size
        duplicate = False
        for gx in (cx - 1, cx, cx + 1):
            for gy in (cy - 1, cy, cy + 1):
                cell = grid.get((gx, gy))
                if cell:
                    for fx, fy, fw, fh in cell:
                        if abs(lx - fx) < 8 and abs(ly - fy) < 8 and abs(lw - fw) < 14 and abs(lh - fh) < 14:
                            duplicate = True
                            break
                if duplicate:
                    break
            if duplicate:
                break
        if not duplicate:
            filtered.append((lx, ly, lw, lh))
            grid.setdefault((cx, cy), []).append((lx, ly, lw, lh))

    print(json.dumps([
        {"x": lx, "y": ly, "width": lw, "height": lh}
        for lx, ly, lw, lh in filtered
    ]))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("[]")
        sys.exit(0)
    detect_rectangles(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 1.0)
