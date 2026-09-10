#!/usr/bin/env python3
"""
test_smart_selection.py — Unit test suite for smart circle-to-select:
- Case 1: Paragraph coalescing on white page
- Case 2: Multi-card merging with sufficient coverage
- Case 3: Accidental grazing rejection (< 20% coverage)
- Case 4: Single button / inner element inside container
- Case 5: Entire card container selection vs children
"""
import json
import subprocess
import cv2
import numpy as np

def create_synthetic_test_image():
    # 1000x800 white image
    img = np.full((800, 1000, 3), 255, dtype=np.uint8)
    
    # 1. Paragraph with 4 lines on white background (x: 100..500, y: 100..200)
    # Line height: 16px, line spacing: 14px
    for i in range(4):
        ly = 100 + i * 26
        # draw text simulation line
        cv2.rectangle(img, (100, ly), (480, ly + 14), (20, 20, 20), -1)
    
    # 2. Card 1 and Card 2 in a grid (y: 350..550)
    # Card 1: x: 100..320 (width 220, height 200)
    cv2.rectangle(img, (100, 350), (320, 550), (230, 230, 235), -1)
    cv2.rectangle(img, (100, 350), (320, 550), (160, 160, 170), 2)
    # Card 1 inner button
    cv2.rectangle(img, (130, 480), (220, 520), (50, 100, 220), -1)
    
    # Card 2: x: 380..600 (width 220, height 200)
    cv2.rectangle(img, (380, 350), (600, 550), (230, 230, 235), -1)
    cv2.rectangle(img, (380, 350), (600, 550), (160, 160, 170), 2)
    # Card 2 inner text lines
    for i in range(3):
        cv2.rectangle(img, (400, 380 + i * 20), (580, 380 + i * 20 + 10), (50, 50, 50), -1)
    
    # Card 3 (neighbor, grazing candidate): x: 660..880
    cv2.rectangle(img, (660, 350), (880, 550), (230, 230, 235), -1)
    cv2.rectangle(img, (660, 350), (880, 550), (160, 160, 170), 2)

    test_img_path = "/tmp/test_synth_screen.png"
    cv2.imwrite(test_img_path, img)
    return test_img_path

def point_in_polygon(px, py, pts):
    inside = False
    n = len(pts)
    j = n - 2
    for i in range(0, n, 2):
        xi, yi = pts[i], pts[i+1]
        xj, yj = pts[j], pts[j+1]
        intersect = ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 1e-7) + xi)
        if intersect:
            inside = not inside
        j = i
    return inside

def resolve_selection(boxes, pts, circleMinX, circleMinY, circleMaxX, circleMaxY):
    cW = circleMaxX - circleMinX
    cH = circleMaxY - circleMinY
    cArea = cW * cH
    if cArea <= 0 or not boxes:
        return None

    hasPoly = pts is not None and len(pts) >= 8
    qualifying = []
    bestSingle = None
    bestSingleScore = -1.0

    for b in boxes:
        bx, by, bw, bh = b["x"], b["y"], b["width"], b["height"]
        ix1 = max(bx, circleMinX)
        iy1 = max(by, circleMinY)
        ix2 = min(bx + bw, circleMaxX)
        iy2 = min(by + bh, circleMaxY)
        if ix2 <= ix1 or iy2 <= iy1:
            continue

        interArea = (ix2 - ix1) * (iy2 - iy1)
        bArea = bw * bh
        boxCov = interArea / bArea
        circleCov = interArea / cArea
        iou = interArea / (cArea + bArea - interArea)

        polyInsideCount = 0
        if hasPoly:
            cx = bx + bw * 0.5
            cy = by + bh * 0.5
            if point_in_polygon(cx, cy, pts):
                polyInsideCount += 2
            if point_in_polygon(bx, by, pts):
                polyInsideCount += 1
            if point_in_polygon(bx + bw, by, pts):
                polyInsideCount += 1
            if point_in_polygon(bx, by + bh, pts):
                polyInsideCount += 1
            if point_in_polygon(bx + bw, by + bh, pts):
                polyInsideCount += 1

        score = iou * 0.55 + circleCov * 0.25 + boxCov * 0.2
        if score > bestSingleScore:
            bestSingleScore = score
            bestSingle = b

        isCenterInPoly = hasPoly and polyInsideCount >= 2
        isSubstantiallyCovered = boxCov >= 0.35 or (isCenterInPoly and boxCov >= 0.20)

        if isSubstantiallyCovered and bArea <= cArea * 2.2 and interArea >= 150:
            qualifying.append({
                "box": b,
                "coverage": boxCov,
                "area": bArea,
                "score": score
            })

    def find_enclosing_box(target_box):
        if not target_box or not boxes:
            return target_box
        is_text_or_section = (target_box["width"] >= 130 and target_box["height"] >= 35) or (target_box["width"] >= 160) or (target_box["height"] >= 60)
        if not is_text_or_section:
            return target_box
        tx1, ty1 = target_box["x"], target_box["y"]
        tx2, ty2 = tx1 + target_box["width"], ty1 + target_box["height"]
        tArea = target_box["width"] * target_box["height"]
        containers = []
        for b in boxes:
            bx1, by1 = b["x"], b["y"]
            bx2, by2 = bx1 + b["width"], by1 + b["height"]
            bArea = b["width"] * b["height"]
            if bx1 <= tx1 + 6 and by1 <= ty1 + 6 and bx2 >= tx2 - 6 and by2 >= ty2 - 6:
                if bArea >= tArea * 1.2 and (b["width"] < 1920 * 0.95 or b["height"] < 1080 * 0.95):
                    containers.append(b)
        if not containers:
            return target_box
        containers.sort(key=lambda c: c["width"] * c["height"])
        return containers[0]

    if len(qualifying) >= 2:
        qualifying.sort(key=lambda item: item["area"], reverse=True)
        topLevel = []
        for i in range(len(qualifying)):
            q = qualifying[i]["box"]
            isChild = False
            for j in range(len(topLevel)):
                parent = topLevel[j]["box"]
                if (q["x"] >= parent["x"] - 4 and q["y"] >= parent["y"] - 4
                    and q["x"] + q["width"] <= parent["x"] + parent["width"] + 4
                    and q["y"] + q["height"] <= parent["y"] + parent["height"] + 4):
                    isChild = True
                    break
            if not isChild:
                topLevel.append(qualifying[i])

        if len(topLevel) >= 2:
            ux1 = min(item["box"]["x"] for item in topLevel)
            uy1 = min(item["box"]["y"] for item in topLevel)
            ux2 = max(item["box"]["x"] + item["box"]["width"] for item in topLevel)
            uy2 = max(item["box"]["y"] + item["box"]["height"] for item in topLevel)
            uW = ux2 - ux1
            uH = uy2 - uy1
            if uW > 0 and uH > 0 and (uW * uH) <= cArea * 3.0:
                return {"x": ux1, "y": uy1, "width": uW, "height": uH}
        elif len(topLevel) == 1:
            return find_enclosing_box(topLevel[0]["box"])

    if bestSingle and bestSingleScore >= 0.08:
        return find_enclosing_box(bestSingle)

    return None

def test_suite():
    img_path = create_synthetic_test_image()
    proc = subprocess.run([
        "python3",
        "/home/ldzbeta/.config/quickshell/HyprQuickFrame/src/detect_boxes.py",
        img_path,
        "1.0"
    ], capture_output=True, text=True, check=True)
    
    boxes = json.loads(proc.stdout)
    print(f"Total detected boxes: {len(boxes)}")

    # ── Test 1: Circling the 4-line paragraph ──
    # Paragraph spans approx x: 100..480, y: 100..192
    # Circle around paragraph: x: 80..500, y: 80..210
    poly_para = [
        80, 145, 120, 80, 460, 80, 500, 145,
        460, 210, 120, 210, 80, 145
    ]
    res_para = resolve_selection(boxes, poly_para, 80, 80, 500, 210)
    print("\n--- Test 1: Paragraph Circling ---")
    print("Resolved Box:", res_para)
    assert res_para is not None, "Failed to resolve paragraph"
    assert abs(res_para["x"] - 100) <= 15, f"Expected x ~ 100, got {res_para['x']}"
    assert abs(res_para["y"] - 100) <= 15, f"Expected y ~ 100, got {res_para['y']}"
    assert res_para["width"] >= 370, f"Expected full paragraph width, got {res_para['width']}"
    assert res_para["height"] >= 80, f"Expected full paragraph height, got {res_para['height']}"
    print("✓ Test 1 Passed: Complete paragraph accurately enclosed and snapped!")

    # ── Test 2: Circling Two Cards (Card 1 and Card 2) ──
    # Card 1: 100..320, Card 2: 380..600
    # Combined: 100..600 (width 500), height 200 (350..550)
    # Circle spans x: 80..620, y: 330..570
    poly_cards = [
        80, 450, 100, 330, 600, 330, 620, 450,
        600, 570, 100, 570, 80, 450
    ]
    res_cards = resolve_selection(boxes, poly_cards, 80, 330, 620, 570)
    print("\n--- Test 2: Multi-Card Circling (Card 1 + Card 2) ---")
    print("Resolved Box:", res_cards)
    assert res_cards is not None, "Failed to resolve multi-card"
    assert abs(res_cards["x"] - 100) <= 15, f"Expected union x ~ 100, got {res_cards['x']}"
    assert abs(res_cards["y"] - 350) <= 15, f"Expected union y ~ 350, got {res_cards['y']}"
    assert res_cards["width"] >= 480, f"Expected merged width >= 480, got {res_cards['width']}"
    assert abs(res_cards["height"] - 200) <= 20, f"Expected height ~ 200, got {res_cards['height']}"
    print("✓ Test 2 Passed: Both cards merged into unified bounding box!")

    # ── Test 3: Circling Card 1 and Card 2 with slight graze of Card 3 ──
    # Card 3 starts at 660. Gesture reaches 675 (only 15px graze = 6.8% coverage).
    poly_graze = [
        80, 450, 100, 330, 665, 330, 675, 450,
        665, 570, 100, 570, 80, 450
    ]
    res_graze = resolve_selection(boxes, poly_graze, 80, 330, 675, 570)
    print("\n--- Test 3: Grazing Rejection (Card 3 grazed by 15px) ---")
    print("Resolved Box:", res_graze)
    assert res_graze is not None
    # Ensure Card 3 is NOT in the selection (maxX must be <= 620)
    assert res_graze["x"] + res_graze["width"] <= 630, f"Card 3 was accidentally included: right edge = {res_graze['x'] + res_graze['width']}"
    print("✓ Test 3 Passed: Grazed neighbor rejected cleanly!")

    # ── Test 4: Circling button inside Card 1 ──
    # Button is at x: 130..220, y: 480..520 (width 90, height 40)
    poly_btn = [
        120, 500, 130, 475, 220, 475, 230, 500,
        220, 525, 130, 525, 120, 500
    ]
    res_btn = resolve_selection(boxes, poly_btn, 120, 475, 230, 525)
    print("\n--- Test 4: Inner Element / Button inside Card ---")
    print("Resolved Box:", res_btn)
    assert res_btn is not None
    assert abs(res_btn["x"] - 130) <= 15
    assert abs(res_btn["y"] - 480) <= 15
    assert abs(res_btn["width"] - 90) <= 15
    assert abs(res_btn["height"] - 40) <= 15
    print("✓ Test 4 Passed: Button snapped accurately without selecting entire parent card!")

    # ── Test 5: Circling text section inside Card 2 snaps to text block ──
    # Text section is at x: 400..580, y: 380..430 inside Card 2 (380..600, 350..550)
    poly_card_text = [
        390, 405, 410, 375, 570, 375, 590, 405,
        570, 435, 410, 435, 390, 405
    ]
    res_card_text = resolve_selection(boxes, poly_card_text, 390, 375, 590, 435)
    print("\n--- Test 5: Text block inside Card snaps to paragraph block ---")
    print("Resolved Box:", res_card_text)
    assert res_card_text is not None
    # Verifies the exact paragraph text block is selected directly
    assert abs(res_card_text["x"] - 400) <= 15, f"Expected text block x ~ 400, got {res_card_text['x']}"
    assert abs(res_card_text["y"] - 380) <= 15, f"Expected text block y ~ 380, got {res_card_text['y']}"
    assert abs(res_card_text["width"] - 180) <= 15, f"Expected text block width ~ 180, got {res_card_text['width']}"
    assert abs(res_card_text["height"] - 50) <= 15, f"Expected text block height ~ 50, got {res_card_text['height']}"
    print("✓ Test 5 Passed: Text section inside Card 2 snapped directly to paragraph block!")

    print("\n==========================================")
    print(" ALL 5 SMART SELECTION TESTS PASSED 100%!")
    print("==========================================")

if __name__ == "__main__":
    test_suite()
