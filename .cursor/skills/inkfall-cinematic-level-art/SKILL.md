---
name: inkfall-cinematic-level-art
description: Designs and refactors Inkfall 2D levels to the approved cinematic silhouette standard: multi-plane depth, volumetric lighting, black tactile gameplay silhouettes, dynamic atmosphere, and soft foreground framing. Use when creating level art, reworking an existing level or zone, adding parallax backgrounds, improving platform texture, lighting, fog, dust, foreground, or cinematic 2.5D depth in this project.
---

# Inkfall Cinematic Level Art

Apply the visual quality and implementation pattern approved in the original “沉钟雾谷” demo to existing levels without copying its layout or subject matter.

Read [VISUAL_STANDARD.md](VISUAL_STANDARD.md) before editing.
For character, equipment, or animation work, also read [CHARACTER_STANDARD.md](CHARACTER_STANDARD.md).

## Canonical implementation references

Inspect these files before building a level-specific version:

- `scripts/demos/cinematic_depth_demo_controller.gd`: gameplay-plane silhouettes and integration
- `scripts/art/cinematic_depth_art.gd`: far/mid parallax and atmosphere
- `scripts/art/cinematic_light_art.gd`: light placement and shader-backed cones
- `scripts/art/cinematic_foreground_art.gd`: foreground framing
- `assets/shaders/cinematic_light_cone.gdshader`: animated volumetric light
- `scripts/actors/actor_pose_state.gd`: shared semantic animation contract
- `scripts/actors/actor_style_host.gd`: legacy/new style switching
- `scripts/actors/crooked_tower_vector_actor.gd`: default independent-SVG player
- `scripts/actors/crooked_tower_vector_manifest.gd`: frame counts, timing, canvas, and pivot contract
- `assets/art/actors/crooked_tower_vector/`: one SVG file per action frame
- `scripts/tools/build_crooked_tower_vector_frames.gd`: pose-to-pose vector frame builder
- `scripts/actors/crooked_tower_actor.gd`: preserved GPT-atlas experiment
- `assets/art/actors/crooked_tower/`: preserved GPT source strips and processed atlases
- `scripts/actors/shadow_frame_library.gd`: preserved procedural frame experiment
- `scripts/actors/shadow_frame_actor.gd`: preserved pumpkin-shadow experiment
- `scripts/actors/velvet_doll_actor.gd`: preserved experimental procedural style

Treat them as pattern references, not as scene content to duplicate.

## Non-negotiable rules

1. Preserve existing collision, traversal timing, checkpoints, interactions, and camera limits unless the user explicitly requests gameplay changes.
2. Build at least four readable planes: far background, mid background, gameplay plane, foreground. Atmosphere/light is an additional plane, not a replacement.
3. Keep walkable ground and platforms as near-black silhouettes with irregular contours and soft black edges.
4. Never draw white, gray, or colored rim lines along walkable surfaces.
5. Show platform mass through thickness, overlap, occlusion, underside shape, supports, and contact shadow—not bevel strokes, cracks, rivets, panels, or vector decoration.
6. Use shader-based volumetric light. Never use static translucent triangles, stacked cone polygons, or a painted glow decal as the primary light.
7. Light reveals fog and negative space; it must not outline the gameplay surface.
8. Dust, haze, and light modulation must move. Do not use evenly distributed static white dots.
9. The player remains the sharpest and most readable element; foreground objects may occlude the scene but not sustained traversal visibility.
10. Every new level must have its own visual motif, silhouette language, palette, and focal landmarks. Reuse the system, not the demo composition.
11. Character actions must be driven by semantic pose data and separate high-frame-count clips; do not animate the default player as a runtime limb puppet or draw equipment separately in each level.

## Workflow

### 1. Audit the level

- Read the level controller, platform/collision data, camera behavior, room transitions, hazards, and existing art scripts.
- Run the level and capture representative frames before editing.
- Mark gameplay-critical silhouettes and areas where foreground occlusion is unsafe.

### 2. Write a compact art intent

Define before implementation:

- one environmental fantasy
- one dominant large-scale silhouette motif
- one focal light source or light rhythm
- one restrained palette with localized bright/saturated exposure
- far, mid, gameplay, and foreground content
- motion assignments for fog, dust, hanging objects, and light

Do not pause for approval when the request and level context already determine these choices; implement and show a preview.

### 3. Build in passes

1. Far plane: large low-contrast masses and a broad exposure window.
2. Mid plane: structural landmarks with independent parallax and partial fog occlusion.
3. Gameplay plane: convert collision rectangles into irregular black visual masses while preserving collision exactly.
4. Light plane: place animated shader cones behind gameplay silhouettes.
5. Atmosphere: drifting fog plus depth-separated dust.
6. Foreground: blurred near-black forms, haze, vignette, and restrained grain.
7. Player integration: contact shadow, local contrast, and spawn-point light composition.

Validate a frame after each major pass. Fix hierarchy before adding detail.

### 4. Keep art modular

Prefer this level-local structure:

- `scripts/art/<level>_depth_art.gd`
- `scripts/art/<level>_light_art.gd`
- `scripts/art/<level>_foreground_art.gd`
- `assets/shaders/<level>_light_cone.gdshader` only when the shared shader cannot express the scene

Each art node should expose `sync(delta, camera_axis, active)`. Put depth and light behind the gameplay controller; put foreground above it. Keep rendering code out of gameplay logic except platform silhouette drawing and lamp fixtures that must align with collision.

### 5. Verify

- Run Godot headlessly to catch parse, shader, and import errors.
- Render or capture the actual target level at spawn and at representative traversal points.
- Observe at least several seconds of motion to verify dust, fog, light, parallax, and foreground behavior.
- Check the acceptance list in [VISUAL_STANDARD.md](VISUAL_STANDARD.md).
- Leave the requested level playable with its original controls and progression.

## Handoff

Report:

- the level/zone changed
- the new visual motif and layer structure
- which gameplay behavior was intentionally preserved
- validation performed
- one embedded preview image when available
