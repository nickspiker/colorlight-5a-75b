#!/usr/bin/env python3
# img_to_fb.py — convert image to 8bpp row-major framebuffer .mem
# Output: 8192 hex bytes, one per line, addr = row*128 + col
# Usage: python3 img_to_fb.py input.jpg output.mem

import sys
from PIL import Image

src  = sys.argv[1] if len(sys.argv) > 1 else "test.jpg"
dst  = sys.argv[2] if len(sys.argv) > 2 else "build/fb_image.mem"

img = Image.open(src).convert("L").resize((128, 64), Image.LANCZOS)

with open(dst, "w") as f:
    for row in range(64):
        for col in range(128):
            f.write(f"{img.getpixel((col, row)):02x}\n")

print(f"Written {dst}  (128×64 grayscale, row-major)")
