# GPT6 Hood Motion Study

Standalone prototype. The level-one controller, existing character assets,
project input map and main scene are unchanged.

## Open

Open `scenes/prototypes/gpt6_hood_motion_lab.tscn` in Godot and run the current
scene with F6. The scene starts a 25.5-second automatic sequence.

Alternatively, from the project root:

```sh
"/Applications/Godot 2.app/Contents/MacOS/Godot" --path . \
  --scene scenes/prototypes/gpt6_hood_motion_lab.tscn
```

## Controls

| Input | Action |
| --- | --- |
| A / D or left / right | Walk; automatically enter manual mode |
| Shift + direction | Run |
| Space / W | Jump; release early for a shorter jump |
| Tab | Automatic / manual mode |
| P | Pause / resume |
| R | Reset |
| Playback selector | 1x, 0.5x or 0.25x |

## Assets And Animation

- The reference is the user's pointed-hood child: charcoal silhouette, amber eye,
  flared coat, slim legs and small hands.
- Blender source: `artifacts/gpt6_motion/source/gpt6_hood_boy.blend`.
- Imported skinned model: `assets/art/prototypes/gpt6_hood/gpt6_hood_boy.glb`.
- Rebuild script: `scripts/tools/blender/build_gpt6_hood.py`.
- Twenty bones, explicitly weighted clothing, separate fingers and boot meshes.
- The Blender file is an editable model/rig, **not** a finished baked Action library.
  The sample's poses are generated at runtime by `gpt6_hood_rig.gd`.
- Locomotion is distance-driven, with stance-foot anchoring, two-bone leg solving,
  opposing arm swing, speed-dependent stride and walk/run blending.
- Acceleration, braking, turning, jumping and landing feed torso/head posture.
- Hood and coat have damped secondary motion. There is no live cloth simulation.
- Godot's `CharacterBody3D` owns movement and collision. Visual posture does not
  delay jump input. Jump buffering, coyote time and variable jump height are local
  to this prototype.

## Walk Revision

The initial walk was too crouched and had incorrect same-side arm/leg timing.
The revised walk uses opposing arms, a higher support-leg posture, lower foot
clearance, less torso lean, neutral-to-heel-leading swing-foot orientation,
and a fresh gait phase after landing. Sleeves and arm bind geometry were extended
together to keep the hands connected and visible below the coat.

A second posture pass separates support-foot constraints from swing-foot reach.
An airborne foot no longer lowers the pelvis and bends the grounded leg.
Walking is now the default manual movement, with a nearly upright torso and
more extended support leg; Shift selects running with a modest forward lean.

## Verification

```sh
"/Applications/Godot 2.app/Contents/MacOS/Godot" --headless --path . \
  --fixed-fps 60 --script scripts/prototypes/gpt6_motion/gpt6_motion_verify.gd

GPT6_CAPTURE=1 "/Applications/Godot 2.app/Contents/MacOS/Godot" --path . \
  --fixed-fps 60 --disable-vsync \
  --script scripts/prototypes/gpt6_motion/gpt6_motion_verify.gd
```

The runner checks state coverage, finite bone poses, floor collision, stance
drift, leg reach, manual reversal, braking, jump release, pause, slow playback
and reset. The visual run also captures multiple poses and smaller windows,
checks that the character renders, and converts HDR captures to sRGB.
Reports and screenshots are in `artifacts/gpt6_motion/`, excluded from Godot
resource import with `.gdignore`.

This is a side-view animation prototype, not a production-ready character or a
claim of parity with LIMBO. Proportions, hood silhouette, animation personality
and transition polish still need visual approval. No first-level replacement
has been performed.
