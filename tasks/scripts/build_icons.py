"""Brand icons: every launcher, notification, web and store icon of the app.

usage: python tasks/scripts/build_icons.py   (from anywhere; paths are
resolved from this file's location)

Needs Pillow (`pip install pillow`) and nothing else. Reads only the Owner's
artwork in `docs/store/graphics/source/` (`DL-116` (11)) and writes, printing
each path and size:

- Android `mipmap-*/ic_launcher_{foreground,background,monochrome}.png`
  (108 dp) and `ic_launcher.png` (48 dp, the full icon);
- Android `drawable-*/ic_stat_notify.png` (24 dp, white with alpha only);
- `frontend/web/favicon.png` and `frontend/web/icons/Icon-*.png`; the
  maskable ones are the adaptive layers composed (the mark reaches 30.6% of
  the width from the centre), because the full icon's mark reaches 40.1%, the
  edge of the maskable safe zone;
- `docs/store/graphics/play-icon-512.png` (RGBA).

The monochrome layer and the notification icon are silhouettes: a pixel
keeps its alpha scaled by `1 - w`, `w = clamp((min(R, G, B) - 160) / 80, 0,
1)`, so the white counters of the letter become holes and the green leaf and
cart stay. The generated files are never edited by hand.
"""

import pathlib

from PIL import Image, ImageChops

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs" / "store" / "graphics" / "source"
RES = ROOT / "frontend" / "android" / "app" / "src" / "main" / "res"
WEB = ROOT / "frontend" / "web"
PLAY_ICON = ROOT / "docs" / "store" / "graphics" / "play-icon-512.png"

DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
LAYER_DP = 108
LAUNCHER_DP = 48
NOTIFY_DP = 24
NOTIFY_PADDING_DP = 2


def px(dp: int, scale: float) -> int:
    return round(dp * scale)


def save(image: Image.Image, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"{path.relative_to(ROOT).as_posix()} {image.width}x{image.height} {image.mode}")


def scaled(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.LANCZOS)


def silhouette_alpha(artwork: Image.Image) -> Image.Image:
    """The alpha of the silhouette: white counters cut out, colour kept."""
    rgba = artwork.convert("RGBA")
    red, green, blue, alpha = rgba.split()
    lowest = ImageChops.darker(ImageChops.darker(red, green), blue)
    whiteness = lowest.point(lambda v: round(min(max((v - 160) / 80, 0), 1) * 255))
    return ImageChops.multiply(alpha, ImageChops.invert(whiteness))


def solid_with_alpha(alpha: Image.Image, colour: int) -> Image.Image:
    image = Image.new("RGBA", alpha.size, (colour, colour, colour, 0))
    image.putalpha(alpha)
    return image


def notification_icon(mark: Image.Image, scale: float) -> Image.Image:
    """White silhouette of the mark, centred on a 24 dp square with padding."""
    alpha = silhouette_alpha(mark)
    box = mark.convert("RGBA").getchannel("A").getbbox()
    if box is None:
        raise ValueError("the mark has no visible pixel")
    alpha = alpha.crop(box)
    size = px(NOTIFY_DP, scale)
    inner = size - 2 * px(NOTIFY_PADDING_DP, scale)
    ratio = inner / max(alpha.size)
    fitted = alpha.resize(
        (max(1, round(alpha.width * ratio)), max(1, round(alpha.height * ratio))),
        Image.LANCZOS,
    )
    canvas = Image.new("L", (size, size), 0)
    canvas.paste(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return solid_with_alpha(canvas, 255)


def main() -> None:
    foreground = Image.open(SOURCE / "baraka-bozor-icon-foreground.png").convert("RGBA")
    background = Image.open(SOURCE / "baraka-bozor-icon-background.png").convert("RGB")
    full = Image.open(SOURCE / "baraka-bozor-icon-full.png").convert("RGB")
    mark = Image.open(SOURCE / "baraka-bozor-mark-2048.png").convert("RGBA")
    monochrome = solid_with_alpha(silhouette_alpha(foreground), 0)

    for name, scale in DENSITIES.items():
        layer = px(LAYER_DP, scale)
        save(scaled(foreground, layer), RES / f"mipmap-{name}" / "ic_launcher_foreground.png")
        save(scaled(background, layer), RES / f"mipmap-{name}" / "ic_launcher_background.png")
        save(scaled(monochrome, layer), RES / f"mipmap-{name}" / "ic_launcher_monochrome.png")
        save(scaled(full, px(LAUNCHER_DP, scale)), RES / f"mipmap-{name}" / "ic_launcher.png")
        save(notification_icon(mark, scale), RES / f"drawable-{name}" / "ic_stat_notify.png")

    maskable = Image.alpha_composite(background.convert("RGBA"), foreground).convert("RGB")
    save(scaled(full, 32), WEB / "favicon.png")
    for size in (192, 512):
        save(scaled(full, size), WEB / "icons" / f"Icon-{size}.png")
        save(scaled(maskable, size), WEB / "icons" / f"Icon-maskable-{size}.png")
    save(scaled(full, 512).convert("RGBA"), PLAY_ICON)


if __name__ == "__main__":
    main()
