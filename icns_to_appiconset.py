# /// script
# requires-python = ">=3.11"
# dependencies = ["Pillow"]
# ///
import argparse
from pathlib import Path
from PIL import Image
from PIL.IcnsImagePlugin import IcnsFile
import json

REQUIRED_SIZES = [
    (16, 1),
    (16, 2),
    (32, 1),
    (32, 2),
    (128, 1),
    (128, 2),
    (256, 1),
    (256, 2),
    (512, 1),
    (512, 2),
]


def extract_icns(icns_file: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    with icns_file.open("rb") as f:
        icns_file = IcnsFile(f)
        extracted_sizes = {
            (size[0], size[1], size[2]) for size in icns_file.itersizes()
        }  # Keep (width, height, scale)

        images_info = []
        for width, height, scale in extracted_sizes:
            sorting_key = (width, height, scale)
            postfix = f"@{scale}x" if scale > 1 else ""
            filename = f"icon_{width}x{height}{postfix}.png"
            img = icns_file.getimage((width, height, scale))
            img.save(output_dir / filename)
            images_info.append(
                (
                    sorting_key,
                    {
                        "filename": filename,
                        "idiom": "mac",
                        "scale": f"{scale}x",
                        "size": f"{width}x{height}",
                    },
                )
            )

        # Now fill in the missing smaller sizes by resizing larger images
        for width, scale in REQUIRED_SIZES:
            if (width, width, scale) not in extracted_sizes:  # Check if size is missing
                larger_img = find_larger_image(
                    width, scale, extracted_sizes, output_dir
                )
                if larger_img:
                    resized_img = larger_img.resize(
                        (width * scale, width * scale), Image.LANCZOS
                    )
                    postfix = f"@{scale}x" if scale > 1 else ""
                    filename = f"icon_{width}x{width}{postfix}.png"
                    resized_img.save(output_dir / filename)
                    sorting_key = (width, width, scale)
                    images_info.append(
                        (
                            sorting_key,
                            {
                                "filename": filename,
                                "idiom": "mac",
                                "scale": f"{scale}x",
                                "size": f"{width}x{width}",
                            },
                        )
                    )

        # Create the Contents.json file for Xcode
        manifest = {
            "images": [
                image for resolution, image in sorted(images_info, key=lambda t: t[0])
            ],
            "info": {"author": "xcode", "version": 1},
        }
        # mimicking Xcode's JSON formatting
        (output_dir / "Contents.json").write_text(
            json.dumps(manifest, indent=2, separators=(",", " : ")) + "\n"
        )
        print(f"Extracted images and created manifest at {output_dir}")


def find_larger_image(
    target_size: int, target_scale: int, available_sizes, output_dir: Path
) -> Image:
    """Find the closest larger image from the available sizes for scaling down."""
    larger_sizes = [
        s for s in available_sizes if s[0] >= target_size and s[2] >= target_scale
    ]
    if not larger_sizes:
        return None

    closest_size = min(larger_sizes, key=lambda s: (s[0], s[2]))
    postfix = f"@{closest_size[2]}x" if closest_size[2] > 1 else ""
    filename = f"icon_{closest_size[0]}x{closest_size[1]}{postfix}.png"
    return Image.open(output_dir / filename)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract ICNS file to a specified output directory."
    )
    parser.add_argument("icns_file", type=Path, help="Path to the ICNS file")
    parser.add_argument(
        "output_dir",
        type=Path,
        help="Directory where the extracted files will be saved",
    )

    args = parser.parse_args()

    extract_icns(args.icns_file, args.output_dir)


if __name__ == "__main__":
    main()
