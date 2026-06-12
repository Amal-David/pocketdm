#!/usr/bin/env python3
"""Rebuild PocketDM pet sprite strips from generated 3D source sheets.

The generated sheets include black contour pixels and gray grid/background
pixels. This script segments the saturated character body, removes large dark
outline components near the silhouette edge, and decontaminates transparent RGB
before resizing so white desktops do not reveal a black halo.

Set POCKETDM_PET_SHEET_DIR to override the source-sheet directory.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[3]
SOURCE_DIR = Path(os.environ.get("POCKETDM_PET_SHEET_DIR", "/Users/amal/Downloads"))
NATIVE_DIR = ROOT / "macos" / "PocketDMCompanion" / "Sources" / "PocketDMCompanion" / "Resources"
WEB_DIR = ROOT / "app" / "static"
FRAME_SIZE = 512
CHARACTER_MAX_SIZE = 438


@dataclass(frozen=True)
class SheetSpec:
    source_name: str
    native_name: str
    web_name: str
    y_bounds: tuple[int, int, int, int]


SHEETS = [
    SheetSpec(
        source_name="Gemini_Generated_Image_g372nqg372nqg372.png",
        native_name="pet-happy.png",
        web_name="dragon-sprites.png",
        y_bounds=(153, 613, 1079, 1536),
    ),
    SheetSpec(
        source_name="Gemini_Generated_Image_g372nqg372nqg372 (1).png",
        native_name="pet-nap.png",
        web_name="dragon-sprites-sad.png",
        y_bounds=(60, 299, 532, 768),
    ),
    SheetSpec(
        source_name="Gemini_Generated_Image_g372nqg372nqg372 (2).png",
        native_name="pet-hyper.png",
        web_name="dragon-sprites-hyper.png",
        y_bounds=(74, 300, 528, 768),
    ),
    SheetSpec(
        source_name="Gemini_Generated_Image_g372nqg372nqg372 (3).png",
        native_name="pet-alert.png",
        web_name="dragon-sprites-scared.png",
        y_bounds=(60, 294, 528, 768),
    ),
]


def component_mask(mask: np.ndarray) -> np.ndarray:
    labels, count = ndimage.label(mask)
    if count == 0:
        return mask
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    return labels == int(areas.argmax())


def remove_outline_components(
    alpha_mask: np.ndarray,
    rgb: np.ndarray,
) -> np.ndarray:
    max_channel = rgb.max(axis=2)
    min_channel = rgb.min(axis=2)
    saturation = (max_channel - min_channel) / np.maximum(max_channel, 1)
    dark = (max_channel < 92) | ((max_channel < 130) & (saturation < 0.24))
    dark = dark & alpha_mask
    labels, count = ndimage.label(dark)
    if count == 0:
        return alpha_mask

    distance_to_edge = ndimage.distance_transform_edt(alpha_mask)
    h, w = alpha_mask.shape
    cell_area = h * w
    next_mask = alpha_mask.copy()

    for label_id in range(1, count + 1):
        component = labels == label_id
        area = int(component.sum())
        if area == 0:
            continue
        ys, xs = np.where(component)
        box_w = int(xs.max() - xs.min() + 1)
        box_h = int(ys.max() - ys.min() + 1)
        median_edge_distance = float(np.median(distance_to_edge[component]))
        large_for_frame = area > cell_area * 0.0015
        spans_body = box_w > w * 0.13 or box_h > h * 0.16
        edge_hugging = median_edge_distance < max(4.0, min(h, w) * 0.02)

        # The contour is a long, edge-hugging dark component. Black eye/ear
        # features are compact or sit deeper inside the filled silhouette.
        if large_for_frame and spans_body and edge_hugging:
            next_mask[component] = False

    return next_mask


def cleaned_frame(cell: Image.Image) -> Image.Image:
    rgb = np.asarray(cell.convert("RGB")).astype(np.uint8)
    rgb_float = rgb.astype(np.float32)
    max_channel = rgb_float.max(axis=2)
    min_channel = rgb_float.min(axis=2)
    saturation = (max_channel - min_channel) / np.maximum(max_channel, 1)

    colored = (saturation > 0.16) & (max_channel > 86)
    yellow_shadow = (rgb[:, :, 0] > 110) & (rgb[:, :, 1] > 70) & (rgb[:, :, 2] < 130)
    red_cheek = (rgb[:, :, 0] > 150) & (rgb[:, :, 1] < 120) & (rgb[:, :, 2] < 120)
    base = colored | yellow_shadow | red_cheek
    base = ndimage.binary_opening(base, iterations=1)
    base = component_mask(base)

    max_channel = rgb.max(axis=2)
    min_channel = rgb.min(axis=2)
    dark = (max_channel < 96) | ((max_channel < 132) & ((max_channel - min_channel) < 28))
    near_body = dark & ndimage.binary_dilation(base, iterations=max(3, min(cell.size) // 90))
    dark_labels, dark_count = ndimage.label(near_body)
    kept_dark = np.zeros_like(base)
    cell_area = cell.width * cell.height
    for label_id in range(1, dark_count + 1):
        component = dark_labels == label_id
        area = int(component.sum())
        if area == 0:
            continue
        ys, xs = np.where(component)
        box_w = int(xs.max() - xs.min() + 1)
        box_h = int(ys.max() - ys.min() + 1)
        compact = (
            area < max(420, cell_area * 0.0045)
            and box_w < cell.width * 0.16
            and box_h < cell.height * 0.26
        )
        if compact:
            kept_dark |= component

    alpha_mask = ndimage.binary_closing(base | kept_dark, iterations=1)
    alpha_mask = ndimage.binary_fill_holes(alpha_mask)
    alpha_mask = remove_outline_components(alpha_mask, rgb)
    alpha_mask = ndimage.binary_opening(alpha_mask, iterations=1)
    alpha_mask = ndimage.binary_fill_holes(alpha_mask)

    if not alpha_mask.any():
        raise RuntimeError("Could not extract character from sprite cell")

    ys, xs = np.where(alpha_mask)
    pad = max(8, min(cell.size) // 32)
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(cell.width, int(xs.max()) + pad + 1)
    y1 = min(cell.height, int(ys.max()) + pad + 1)

    # Transparent pixels must borrow nearby character RGB before resizing;
    # otherwise antialiasing blends black transparent RGB into the edge.
    nearest_y, nearest_x = ndimage.distance_transform_edt(
        ~alpha_mask,
        return_distances=False,
        return_indices=True,
    )
    safe_rgb = rgb.copy()
    safe_rgb[~alpha_mask] = rgb[nearest_y[~alpha_mask], nearest_x[~alpha_mask]]
    alpha = (alpha_mask.astype(np.uint8) * 255)[:, :, None]
    rgba = np.concatenate([safe_rgb, alpha], axis=2)

    cropped = Image.fromarray(rgba[y0:y1, x0:x1], "RGBA")
    scale = min(CHARACTER_MAX_SIZE / cropped.width, CHARACTER_MAX_SIZE / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )

    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - resized.width) // 2
    y = FRAME_SIZE - resized.height - 34
    frame.alpha_composite(resized, (x, y))
    return frame


def cell_boxes(image: Image.Image, spec: SheetSpec) -> list[tuple[int, int, int, int]]:
    x_bounds = [round(image.width * i / 4) for i in range(5)]
    y_bounds = list(spec.y_bounds)
    boxes: list[tuple[int, int, int, int]] = []
    for row in range(3):
        for col in range(4):
            boxes.append(
                (
                    x_bounds[col] + 3,
                    y_bounds[row] + 3,
                    x_bounds[col + 1] - 3,
                    y_bounds[row + 1] - 3,
                )
            )
    return boxes


def build_strip(spec: SheetSpec) -> Image.Image:
    source = SOURCE_DIR / spec.source_name
    if not source.exists():
        raise FileNotFoundError(f"Missing source sheet: {source}")

    image = Image.open(source).convert("RGB")
    frames = [cleaned_frame(image.crop(box)) for box in cell_boxes(image, spec)]
    strip = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
    return strip


def metrics(path: Path) -> str:
    image = Image.open(path).convert("RGBA")
    arr = np.asarray(image)
    alpha = arr[:, :, 3]
    rgb = arr[:, :, :3]
    visible = alpha > 0
    max_channel = rgb.max(axis=2)
    min_channel = rgb.min(axis=2)
    saturation = (max_channel - min_channel) / np.maximum(max_channel, 1)
    dark_visible = visible & (rgb.max(axis=2) < 96)
    dark_low_alpha = (alpha > 0) & (alpha < 245) & (rgb.max(axis=2) < 120)
    edge = visible & (ndimage.distance_transform_edt(visible) <= 2.5)
    dark_edge = edge & (rgb.max(axis=2) < 96)
    gray_halo = edge & (alpha < 245) & (saturation < 0.14) & (max_channel > 80) & (max_channel < 235)
    return (
        f"{path.name}: dark_visible={int(dark_visible.sum())} "
        f"dark_low_alpha={int(dark_low_alpha.sum())} dark_edge={int(dark_edge.sum())} "
        f"gray_halo={int(gray_halo.sum())}"
    )


def main() -> None:
    for spec in SHEETS:
        strip = build_strip(spec)
        native_path = NATIVE_DIR / spec.native_name
        web_path = WEB_DIR / spec.web_name
        strip.save(native_path)
        strip.save(web_path)
        print(metrics(native_path))


if __name__ == "__main__":
    main()
