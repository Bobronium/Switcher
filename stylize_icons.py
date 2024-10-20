"""
This script was written via https://chatgpt.com/g/g-Z5tFTQt5G-pseudocoder.
"""
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "Pillow",
#   "numpy",
# ]
# ///

from PIL import Image, ImageTk, ImageEnhance
import numpy as np
from pathlib import Path
import argparse
from os import environ
from sys import base_prefix

# Set environment variables to locate Tcl/Tk properly
environ["TCL_LIBRARY"] = str(Path(base_prefix) / "lib" / "tcl8.6")
environ["TK_LIBRARY"] = str(Path(base_prefix) / "lib" / "tk8.6")


def create_centered_mask(width: int, height: int, angle: float, offset: float) -> Image:
    """Create a linear gradient mask where the transition line pivots around the center, with optional offset."""
    mask = np.zeros((height, width), dtype=np.uint8)
    center_x = width / 2 + offset
    center_y = height / 2 + offset

    # Normalize angle to [0, 360] range
    angle = angle % 360

    # Flip the mask based on angle ranges to maintain the top-left non-pixelated area
    flip_mask = False
    if 90 <= angle < 270:
        flip_mask = True

    # Calculate the slope from the angle
    slope = np.tan(np.radians(angle))

    for y in range(height):
        for x in range(width):
            # Equation of line through center (y - center_y) = slope * (x - center_x)
            if flip_mask:
                # Flip the logic for angles between 90 and 270
                if y < slope * (x - center_x) + center_y:
                    mask[y, x] = 255  # bottom-right part (high-quality)
            else:
                if y > slope * (x - center_x) + center_y:
                    mask[y, x] = 255  # bottom-right part (high-quality)

    return Image.fromarray(mask)


def pixelate_mask(mask: Image, pixelation_factor: int) -> Image:
    """Pixelate the mask to create a jagged, blocky transition."""
    small_mask = mask.resize(
        (mask.width // pixelation_factor, mask.height // pixelation_factor),
        resample=Image.NEAREST,
    )
    pixelated_mask = small_mask.resize(mask.size, Image.NEAREST)
    return pixelated_mask


def pixelate_with_jpeg_artifacts(
    image: Image, pixelation_factor: int, quality: int
) -> Image:
    """Pixelate the image and apply JPEG compression artifacts."""
    # Ensure pixelation_factor is never 0 to avoid ZeroDivisionError
    pixelation_factor = max(1, int(pixelation_factor))

    small_image = image.resize(
        (image.width // pixelation_factor, image.height // pixelation_factor),
        resample=Image.NEAREST,
    )
    pixelated_image = small_image.resize(image.size, Image.NEAREST)

    if pixelated_image.mode == "RGBA":
        pixelated_image = pixelated_image.convert("RGB")

    temp_jpeg_path = Path("temp_pixelated_compressed.jpg")
    pixelated_image.save(temp_jpeg_path, format="JPEG", quality=quality)
    jpeg_artifact_image = Image.open(temp_jpeg_path)
    temp_jpeg_path.unlink()

    return jpeg_artifact_image


def apply_quality_mask(
    image_path: Path,
    output_path: Path,
    dry_run: bool = False,
    pixelation_factor: int = 10,
    jpeg_quality: int = 25,
    saturation_factor: float = 0.5,
    angle: float = 45,
    offset: float = 0,
    pixelated_line: bool = True,
) -> None:
    image = Image.open(image_path)
    if image.mode == "RGBA":
        rgb_image, alpha_channel = image.convert("RGB"), image.split()[3]
    else:
        rgb_image, alpha_channel = image, None

    width, height = rgb_image.size

    mask = create_centered_mask(width, height, angle, offset)
    if pixelated_line:
        mask = pixelate_mask(mask, pixelation_factor)

    bad_quality = pixelate_with_jpeg_artifacts(
        rgb_image, pixelation_factor, jpeg_quality
    )
    enhancer = ImageEnhance.Color(bad_quality)
    bad_quality = enhancer.enhance(saturation_factor)

    combined = Image.composite(rgb_image, bad_quality, mask)
    if alpha_channel:
        combined.putalpha(alpha_channel)

    if dry_run:
        combined.show()
    else:
        combined.save(output_path)


def update_preview():
    """Update the image preview based on the current settings."""
    angle = angle_slider.get()
    offset = offset_slider.get()
    pixelation_factor = max(
        1, int(pixelation_slider.get())
    )  # Ensure pixelation_factor is never 0
    jpeg_quality = 25
    saturation_factor = 0.5
    pixelated_line = pixelated_line_var.get()

    mask = create_centered_mask(width, height, angle, offset)
    if pixelated_line:
        mask = pixelate_mask(mask, pixelation_factor)

    bad_quality = pixelate_with_jpeg_artifacts(
        rgb_image, pixelation_factor, jpeg_quality
    )
    enhancer = ImageEnhance.Color(bad_quality)
    bad_quality = enhancer.enhance(saturation_factor)

    combined = Image.composite(rgb_image, bad_quality, mask)
    if alpha_channel:
        combined.putalpha(alpha_channel)

    preview_image = ImageTk.PhotoImage(combined)
    canvas.itemconfig(image_on_canvas, image=preview_image)
    canvas.image = preview_image


def load_image(image_path: Path):
    global rgb_image, alpha_channel, width, height
    image = Image.open(image_path)
    if image.mode == "RGBA":
        rgb_image, alpha_channel = image.convert("RGB"), image.split()[3]
    else:
        rgb_image, alpha_channel = image, None

    width, height = rgb_image.size
    return image


from PIL import Image
from pathlib import Path
import threading
from os import environ
from sys import base_prefix

# Set environment variables to locate Tcl/Tk properly
environ["TCL_LIBRARY"] = str(Path(base_prefix) / "lib" / "tcl8.6")
environ["TK_LIBRARY"] = str(Path(base_prefix) / "lib" / "tk8.6")

# Global flag to avoid multiple concurrent updates
updating = False


def create_centered_mask(width: int, height: int, angle: float, offset: float) -> Image:
    """Create a linear gradient mask where the transition line pivots around the center, with optional offset."""
    mask = np.zeros((height, width), dtype=np.uint8)
    center_x = width / 2 + offset
    center_y = height / 2 + offset

    # Normalize angle to [0, 360] range
    angle = angle % 360

    # Flip the mask based on angle ranges to maintain the top-left non-pixelated area
    flip_mask = False
    if 90 <= angle < 270:
        flip_mask = True

    # Calculate the slope from the angle
    slope = np.tan(np.radians(angle))

    for y in range(height):
        for x in range(width):
            # Equation of line through center (y - center_y) = slope * (x - center_x)
            if flip_mask:
                if y < slope * (x - center_x) + center_y:
                    mask[y, x] = 255  # bottom-right part (high-quality)
            else:
                if y > slope * (x - center_x) + center_y:
                    mask[y, x] = 255  # bottom-right part (high-quality)

    return Image.fromarray(mask)


def pixelate_mask(mask: Image, pixelation_factor: int) -> Image:
    """Pixelate the mask to create a jagged, blocky transition."""
    small_mask = mask.resize(
        (mask.width // pixelation_factor, mask.height // pixelation_factor),
        resample=Image.NEAREST,
    )
    pixelated_mask = small_mask.resize(mask.size, Image.NEAREST)
    return pixelated_mask


def pixelate_with_jpeg_artifacts(
    image: Image, pixelation_factor: int, quality: int
) -> Image:
    """Pixelate the image and apply JPEG compression artifacts."""
    pixelation_factor = max(1, int(pixelation_factor))  # Ensure it's not zero
    small_image = image.resize(
        (image.width // pixelation_factor, image.height // pixelation_factor),
        resample=Image.NEAREST,
    )
    pixelated_image = small_image.resize(image.size, Image.NEAREST)

    if pixelated_image.mode == "RGBA":
        pixelated_image = pixelated_image.convert("RGB")

    temp_jpeg_path = Path("temp_pixelated_compressed.jpg")
    pixelated_image.save(temp_jpeg_path, format="JPEG", quality=quality)
    jpeg_artifact_image = Image.open(temp_jpeg_path)
    temp_jpeg_path.unlink()

    return jpeg_artifact_image


def update_preview_thread():
    """Function to run in a separate thread for updating the preview."""
    global updating
    if updating:
        return
    updating = True

    try:
        update_preview()
    finally:
        updating = False


def update_preview():
    """Update the image preview based on the current settings."""
    angle = angle_slider.get()
    offset = offset_slider.get()
    pixelation_factor = max(
        1, int(pixelation_slider.get())
    )  # Ensure pixelation_factor is never 0
    jpeg_quality = 25
    saturation_factor = (
        saturation_slider.get()
    )  # Get the value from the saturation slider
    pixelated_line = pixelated_line_var.get()

    mask = create_centered_mask(width, height, angle, offset)
    if pixelated_line:
        mask = pixelate_mask(mask, pixelation_factor)

    bad_quality = pixelate_with_jpeg_artifacts(
        rgb_image, pixelation_factor, jpeg_quality
    )
    enhancer = ImageEnhance.Color(bad_quality)
    bad_quality = enhancer.enhance(saturation_factor)

    combined = Image.composite(rgb_image, bad_quality, mask)
    if alpha_channel:
        combined.putalpha(alpha_channel)

    preview_image = ImageTk.PhotoImage(combined)
    canvas.itemconfig(image_on_canvas, image=preview_image)
    canvas.image = preview_image


def load_image(image_path: Path):
    global rgb_image, alpha_channel, width, height
    image = Image.open(image_path)
    if image.mode == "RGBA":
        rgb_image, alpha_channel = image.convert("RGB"), image.split()[3]
    else:
        rgb_image, alpha_channel = image, None

    width, height = rgb_image.size
    return image


def run_ui(image_path):
    import tkinter as tk
    from tkinter import ttk

    global \
        canvas, \
        image_on_canvas, \
        angle_slider, \
        offset_slider, \
        pixelation_slider, \
        saturation_slider, \
        pixelated_line_var
    root = tk.Tk()
    root.title("Image Transition Preview")

    image = load_image(image_path)

    # Create a frame for the preview and controls
    frame = tk.Frame(root)
    frame.pack(side=tk.TOP)

    # Canvas to display the image
    canvas = tk.Canvas(frame, width=image.width, height=image.height)
    canvas.pack()
    preview_image = ImageTk.PhotoImage(image)
    image_on_canvas = canvas.create_image(0, 0, anchor=tk.NW, image=preview_image)

    # Create a new window for controls
    control_window = tk.Toplevel(root)
    control_window.title("Controls")

    # Labels to display the current values of sliders
    angle_value_label = tk.Label(control_window, text="Angle: 45")
    offset_value_label = tk.Label(control_window, text="Offset: 0")
    pixelation_value_label = tk.Label(control_window, text="Pixelation: 10")
    saturation_value_label = tk.Label(control_window, text="Saturation: 0.5")

    # Function to update labels dynamically
    def update_labels():
        angle_value_label.config(text=f"Angle: {int(angle_slider.get())}")
        offset_value_label.config(text=f"Offset: {int(offset_slider.get())}")
        pixelation_value_label.config(
            text=f"Pixelation: {int(pixelation_slider.get())}"
        )
        saturation_value_label.config(text=f"Saturation: {saturation_slider.get():.2f}")

    # Controls layout in the new window
    ttk.Label(control_window, text="Angle").grid(row=0, column=0, padx=5, pady=5)
    angle_slider = ttk.Scale(
        control_window,
        from_=0,
        to=360,
        length=200,
        command=lambda val: [
            threading.Thread(target=update_preview_thread).start(),
            update_labels(),
        ],
    )
    angle_slider.grid(row=1, column=0, padx=5, pady=5)
    angle_value_label.grid(row=2, column=0)

    ttk.Label(control_window, text="Offset").grid(row=0, column=1, padx=5, pady=5)
    offset_slider = ttk.Scale(
        control_window,
        from_=-500,
        to=500,
        length=200,
        command=lambda val: [
            threading.Thread(target=update_preview_thread).start(),
            update_labels(),
        ],
    )
    offset_slider.grid(row=1, column=1, padx=5, pady=5)
    offset_value_label.grid(row=2, column=1)

    ttk.Label(control_window, text="Pixelation").grid(row=0, column=2, padx=5, pady=5)
    pixelation_slider = ttk.Scale(
        control_window,
        from_=1,
        to=20,
        length=200,
        command=lambda val: [
            threading.Thread(target=update_preview_thread).start(),
            update_labels(),
        ],
    )
    pixelation_slider.grid(row=1, column=2, padx=5, pady=5)
    pixelation_value_label.grid(row=2, column=2)

    # Use tk.Scale for Saturation to get finer control with resolution
    ttk.Label(control_window, text="Saturation").grid(row=0, column=3, padx=5, pady=5)
    saturation_slider = tk.Scale(
        control_window,
        from_=0.0,
        to=1.0,
        resolution=0.01,
        orient=tk.HORIZONTAL,
        length=200,
        command=lambda val: [
            threading.Thread(target=update_preview_thread).start(),
            update_labels(),
        ],
    )
    saturation_slider.grid(row=1, column=3, padx=5, pady=5)
    saturation_value_label.grid(row=2, column=3)

    # Checkbox to toggle between pixelated and smooth transition line
    pixelated_line_var = tk.BooleanVar()
    pixelated_line_checkbox = ttk.Checkbutton(
        control_window,
        text="Pixelated Line",
        variable=pixelated_line_var,
        command=lambda: threading.Thread(target=update_preview_thread).start(),
    )
    pixelated_line_checkbox.grid(row=3, column=0, columnspan=4, pady=10)

    # Start with some initial values
    angle_slider.set(45)
    offset_slider.set(0)
    pixelation_slider.set(10)
    saturation_slider.set(0.5)
    pixelated_line_var.set(True)

    root.mainloop()


def run_cli(args):
    apply_quality_mask(
        args.input,
        args.output,
        args.dry_run,
        args.pixelation_factor,
        args.jpeg_quality,
        args.saturation_factor,
        args.angle,
        args.offset,
        args.pixelated_line,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Apply a custom quality mask to an image with pixelation, JPEG artifacts, and color degradation."
    )
    parser.add_argument(
        "input", type=Path, help="Path to the input image file (PNG format)."
    )
    parser.add_argument("output", type=Path, help="Path to save the output image.")
    parser.add_argument(
        "--pixelation-factor",
        type=int,
        default=10,
        help="Factor to control the pixelation intensity.",
    )
    parser.add_argument(
        "--jpeg-quality",
        type=int,
        default=25,
        help="JPEG compression quality (1-100, lower means more artifacts).",
    )
    parser.add_argument(
        "--saturation-factor",
        type=float,
        default=0.5,
        help="Factor to reduce the saturation (1.0 is original color, 0.0 is grayscale).",
    )
    parser.add_argument(
        "--angle",
        type=float,
        default=45,
        help="Angle of the transition line, pivoting around the center of the image.",
    )
    parser.add_argument(
        "--offset",
        type=float,
        default=0,
        help="Offset to move the transition line horizontally/vertically.",
    )
    parser.add_argument(
        "--pixelated-line",
        action="store_true",
        help="If set, the transition line will be pixelated. Leave unset for a smooth line.",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Show the output without saving."
    )
    parser.add_argument(
        "--ui", action="store_true", help="Launch the UI for real-time preview."
    )
    args = parser.parse_args()

    if args.ui:
        run_ui(args.input)
    else:
        run_cli(args)


if __name__ == "__main__":
    main()
