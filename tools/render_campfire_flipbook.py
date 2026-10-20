import bpy
import math
from pathlib import Path

OUTPUT = Path("/tmp/inkfall_fire_frames")
OUTPUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 128
scene.render.resolution_y = 160
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.render.image_settings.color_depth = "8"
scene.render.fps = 24

scene.view_settings.look = "AgX - Medium High Contrast"

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.18, location=(0.0, 0.0, 0.20))
flow = bpy.context.object
flow.name = "CampfireFuel"
flow.scale = (1.0, 0.72, 0.34)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

flow.select_set(True)
bpy.context.view_layer.objects.active = flow
bpy.ops.object.quick_smoke(style="FIRE", show_flows=False)

domain = next(obj for obj in scene.objects if obj.name != flow.name and any(mod.type == "FLUID" for mod in obj.modifiers))
domain.name = "CampfireDomain"
domain.scale = (2.0, 1.65, 2.55)
domain.location.z = 1.45
bpy.context.view_layer.objects.active = domain
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

domain_mod = next(mod for mod in domain.modifiers if mod.type == "FLUID")
settings = domain_mod.domain_settings
settings.cache_type = "REPLAY"
settings.resolution_max = 64
settings.time_scale = 1.35
settings.vorticity = 2.0
settings.use_dissolve_smoke = True
settings.dissolve_speed = 14
settings.use_dissolve_smoke_log = True
settings.cache_frame_start = 1
settings.cache_frame_end = 72

flow_mod = next(mod for mod in flow.modifiers if mod.type == "FLUID")
flow_settings = flow_mod.flow_settings
flow_settings.flow_behavior = "INFLOW"
flow_settings.fuel_amount = 1.5
flow_settings.surface_distance = 1.7

bpy.ops.object.camera_add(location=(0.0, -7.0, 1.48), rotation=(math.pi / 2.0, 0.0, 0.0))
camera = bpy.context.object
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.80
scene.camera = camera

for frame in range(1, 61):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    if frame >= 29 and (frame - 29) % 2 == 0:
        output_index = (frame - 29) // 2
        scene.render.filepath = str(OUTPUT / f"fire_{output_index:02d}.png")
        bpy.ops.render.render(write_still=True)
