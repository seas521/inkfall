# Seedance predator clip v1

Source: user-provided 5-second Seedance video, 2026-11-10. Original download is unchanged. SHA-256 and original filename are retained in manifest.json.

All 121 native frames are extracted continuously. The container has a 60 fps timebase but approximately 24 actual frames per second; source timestamps are retained in the audit directory. Runtime uses a 24 fps base timeline, with a faster complete windup for responsive gameplay.

One source root (480,880), one pack scale 0.4, one 384px logical canvas and one display scale 0.82 are shared by every frame. Transparent borders are cropped for storage only; the original logical crop offsets remain in the manifest. No individual frame is resized/recentered. Minimum full-canvas margin: 24px.

Root is planted 95 gameplay pixels below the forest bank, putting the filmed horizontal mouth at actor body height. Per-frame source-space oral contact tracks drive both feeding and actor swallowing. No whole-plant rotation, static-jaw shader or crossfaded alternate image is used.

Frames 0–12: idle; 13–39: windup; 40–49: bite; 50–64: initial digestion; 65–88: matched digestion cycle; 89–120: reopen. All source frames remain packaged and used.

Rebuild: /tmp/inkfall-predator-venv/bin/python scripts/tools/build_forest_predator_clip.py VIDEO. Dependencies: ffmpeg, Pillow, NumPy, SciPy. Source review, all-frame contact sheets, fixed-canvas audit and motion GIF are under artifacts/forest-predator/video-v1/.
