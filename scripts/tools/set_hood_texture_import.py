#!/usr/bin/env python3
"""Sets the hooded boy's frames to VRAM-compressed textures (BPTC at high quality: 4x smaller in video memory than RGBA8).

    godot --headless --path . --import          # once, so Godot writes the .import files
    python3 scripts/tools/set_hood_texture_import.py
    godot --headless --path . --import          # again, to compress them

package_hood_actor.py removes the folder (and the .import files with it) every time it runs, so repeat these steps after it.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "assets/art/actors/hood_boy"
changed = 0
for path in ROOT.rglob("*.png.import"):
    text = path.read_text()
    # mipmaps: the frames are shrunk about 2.6x on screen, and without them the silhouette edges shimmer
    new = (
        text.replace("compress/mode=0", "compress/mode=2")
        .replace("compress/high_quality=false", "compress/high_quality=true")
        .replace("mipmaps/generate=false", "mipmaps/generate=true")
    )
    if new != text:
        path.write_text(new)
        changed += 1
print("patched", changed, "import files")
