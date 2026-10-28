"""Exercise the screenshot gate against blank and absent HUD frames."""

import tempfile
from pathlib import Path

from PIL import Image, ImageDraw
from check_frame import check_frame


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    scene = Image.new("RGB", (640, 360), "#20222b")
    ImageDraw.Draw(scene).rectangle((0, 120, 639, 359), fill="#7d6b58")
    scene.save(root / "without.png")
    with_hud = scene.copy()
    ImageDraw.Draw(with_hud).rectangle((250, 20, 390, 50), fill="white")
    with_hud.save(root / "hud.png")
    check_frame(root / "hud.png", root / "without.png")
    for name in ("without.png", "blank.png"):
        if name == "blank.png":
            Image.new("RGB", (640, 360), "black").save(root / name)
        try:
            check_frame(root / name, root / "without.png")
        except ValueError:
            pass
        else:
            raise AssertionError(f"Accepted invalid frame {name}")
    print("SCREENSHOT_TEST rejected missing HUD and blank frame")
