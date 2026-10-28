"""Verify the real frame and compare its HUD with a matching HUD-hidden frame."""

import argparse
from pathlib import Path

from PIL import Image, ImageChops


def check_frame(frame_path: Path, no_hud_path: Path) -> None:
    frame = Image.open(frame_path).convert("RGB")
    no_hud = Image.open(no_hud_path).convert("RGB")
    if frame.size != no_hud.size or frame.width < 640 or frame.height < 360:
        raise ValueError("Screenshots have unexpected or mismatched sizes")
    if len(frame.getcolors(maxcolors=256) or []) == 1:
        raise ValueError("Rendered frame is a single colour")
    # The match score/timer live in the upper central HUD; compare with the same scene without UI.
    box = (frame.width // 4, 0, 3 * frame.width // 4, frame.height // 4)
    delta = ImageChops.difference(frame.crop(box), no_hud.crop(box))
    changed = sum(1 for r, g, b in delta.getdata() if max(r, g, b) >= 20)
    if changed < 50:
        raise ValueError(f"HUD is missing or invisible in the upper screen ({changed} changed pixels)")
    print(f"SCREENSHOT_OK {frame.width}x{frame.height}, HUD pixels={changed}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("frame", type=Path)
    parser.add_argument("without_hud", type=Path)
    args = parser.parse_args()
    check_frame(args.frame, args.without_hud)
