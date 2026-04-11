from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_IMAGE = ROOT / "assets" / "branding" / "shaumsi_icon_source.jpeg"
OUTPUT_IMAGE = ROOT / "assets" / "branding" / "shaumsi_icon_1024.png"
SIZE = 1024

ANDROID_ICON_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def load_source_image() -> Image.Image:
    image = Image.open(SOURCE_IMAGE).convert("RGBA")
    if image.width != image.height:
        raise ValueError(
            f"A imagem do icone precisa ser quadrada. Recebido: {image.width}x{image.height}",
        )
    return image


def export_icons(image: Image.Image) -> None:
    launcher_image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    OUTPUT_IMAGE.parent.mkdir(parents=True, exist_ok=True)
    launcher_image.save(OUTPUT_IMAGE)

    for folder, icon_size in ANDROID_ICON_SIZES.items():
        resized = launcher_image.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        resized.save(
            ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        )

    launcher_image.save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def main() -> None:
    export_icons(load_source_image())


if __name__ == "__main__":
    main()
