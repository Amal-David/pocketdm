#!/usr/bin/env python3
"""Remove opaque generated-sheet backgrounds from external pet sprite sheets."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SPRITE_DIR = ROOT / "output" / "sprite-sheets"
FRAME_COUNT = 12


def sheet_layout(image: Image.Image) -> tuple[int, int]:
    aspect = image.width / max(1, image.height)
    if aspect > 6.0:
        return FRAME_COUNT, 1
    return 6, 2


def background_sample(arr: np.ndarray) -> tuple[float, float, float]:
    height, width, _ = arr.shape
    inset = max(0, min(6, min(width, height) // 28))
    points = [
        (inset, inset),
        (width - 1 - inset, inset),
        (inset, height - 1 - inset),
        (width - 1 - inset, height - 1 - inset),
        (width // 2, inset),
        (width // 2, height - 1 - inset),
        (inset, height // 2),
        (width - 1 - inset, height // 2),
    ]
    samples: list[np.ndarray] = []
    for x, y in points:
        pixel = arr[max(0, min(height - 1, y)), max(0, min(width - 1, x))]
        if pixel[3] > 0:
            samples.append(pixel[:3].astype(np.float32))
    if not samples:
        return 255.0, 255.0, 255.0
    mean = np.stack(samples).mean(axis=0)
    return float(mean[0]), float(mean[1]), float(mean[2])


def is_background_pixel(
    pixel: np.ndarray,
    background: tuple[float, float, float],
    *,
    strict: bool,
) -> bool:
    if int(pixel[3]) == 0:
        return True

    red, green, blue = [float(channel) for channel in pixel[:3]]
    max_channel = max(red, green, blue)
    min_channel = min(red, green, blue)
    saturation = (max_channel - min_channel) / max(max_channel, 1.0)
    distance = (
        (red - background[0]) ** 2
        + (green - background[1]) ** 2
        + (blue - background[2]) ** 2
    ) ** 0.5

    pet_yellow = red > 130 and green > 88 and blue < 155 and red > blue + 32 and green > blue + 8
    pet_red = red > 140 and green < 150 and blue < 150 and red > green + 18
    warm_pet_shadow = (
        red > 85
        and green > 45
        and green < 150
        and blue < 130
        and red > blue + 16
        and saturation > 0.17
    )
    if pet_yellow or pet_red or warm_pet_shadow:
        return False

    light_neutral = max_channel > 128 and saturation < 0.24
    sheet_grid_line = max_channel > 54 and max_channel < 188 and saturation < 0.18
    if strict:
        return distance < 48 or (distance < 82 and light_neutral) or (distance < 170 and sheet_grid_line)
    return distance < 72 or (distance < 104 and light_neutral) or (distance < 190 and sheet_grid_line)


def clean_cell(cell: Image.Image) -> tuple[Image.Image, int]:
    arr = np.asarray(cell.convert("RGBA")).copy()
    height, width, _ = arr.shape
    background = background_sample(arr)
    flat = arr.reshape((-1, 4))
    transparent = np.zeros(width * height, dtype=bool)
    stack: list[int] = []

    def enqueue(x: int, y: int) -> None:
        if x < 0 or x >= width or y < 0 or y >= height:
            return
        position = y * width + x
        if transparent[position]:
            return
        if not is_background_pixel(flat[position], background, strict=True):
            return
        transparent[position] = True
        stack.append(position)

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while stack:
        position = stack.pop()
        x = position % width
        y = position // width
        enqueue(x - 1, y)
        enqueue(x + 1, y)
        enqueue(x, y - 1)
        enqueue(x, y + 1)

    softened = transparent.copy()
    for y in range(height):
        row_offset = y * width
        for x in range(width):
            position = row_offset + x
            if transparent[position]:
                continue
            if not is_background_pixel(flat[position], background, strict=False):
                continue
            touches_transparent = (
                (x > 0 and transparent[position - 1])
                or (x + 1 < width and transparent[position + 1])
                or (y > 0 and transparent[position - width])
                or (y + 1 < height and transparent[position + width])
            )
            if touches_transparent:
                softened[position] = True

    flat[softened] = np.array([0, 0, 0, 0], dtype=np.uint8)
    return Image.fromarray(arr, "RGBA"), int(softened.sum())


def clean_sheet(path: Path) -> tuple[int, int]:
    image = Image.open(path).convert("RGBA")
    columns, rows = sheet_layout(image)
    frame_width = image.width // columns
    frame_height = image.height // rows
    output = Image.new("RGBA", image.size, (0, 0, 0, 0))
    removed = 0

    for index in range(min(FRAME_COUNT, columns * rows)):
        column = index % columns
        row = index // columns
        box = (
            column * frame_width,
            row * frame_height,
            (column + 1) * frame_width,
            (row + 1) * frame_height,
        )
        cleaned, count = clean_cell(image.crop(box))
        output.alpha_composite(cleaned, (box[0], box[1]))
        removed += count

    output.save(path)
    return removed, frame_width * frame_height * min(FRAME_COUNT, columns * rows)


def sprite_paths(directory: Path) -> list[Path]:
    return sorted(
        path
        for path in directory.glob("pet-*.png")
        if path.is_file() and path.name != "contact-sheet.png"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "directory",
        nargs="?",
        type=Path,
        default=DEFAULT_SPRITE_DIR,
        help="Directory containing generated pet-*.png sprite sheets.",
    )
    args = parser.parse_args()

    if not args.directory.exists():
        raise SystemExit(f"Missing sprite directory: {args.directory}")

    for path in sprite_paths(args.directory):
        removed, total = clean_sheet(path)
        print(f"{path.name}: transparent_pixels={removed}/{total}")


if __name__ == "__main__":
    main()
