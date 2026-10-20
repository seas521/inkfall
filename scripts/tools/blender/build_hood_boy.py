"""Builds a simplified 3D hooded boy (matching the silhouette of concept D) with a Mixamo-named skeleton.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/tools/blender/build_hood_boy.py

Only the side silhouette matters in the game, so the model is made of primitives, fused into one
surface and skinned with automatic weights. Units: metres, 1.6 m tall, facing +X, +Z up. The
measurements come from the 1024px concept image (777 px from hood tip to feet = 1.6 m).
Output: assets/art/prototypes/hood3d/hood_boy.glb
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[3] / "assets/art/prototypes/hood3d/hood_boy.glb"


def clean():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def ellipsoid(name, center, radii, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=18, radius=1.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def tube(name, p0, p1, r0, r1, squash=1.0):
    """A cone from p0 to p1. `squash` narrows the section along Y (side-to-side)."""
    a, b = Vector(p0), Vector(p1)
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=28, radius1=r0, radius2=r1, depth=direction.length,
                                    location=(a + b) / 2.0, end_fill_type="NGON")
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (1.0, squash, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def curve_tube(name, points, radii):
    """A tapered tube through points (x, z), lying in the XZ plane."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = 6
    curve.resolution_u = 10
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, (x, z), radius in zip(spline.points, points, radii):
        point.co = (x, 0.0, z, 1.0)
        point.radius = radius
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def build_body():
    parts = []
    # Hood: the shell, a pointed crown and the drooping tip that curls back.
    parts.append(ellipsoid("hood_shell", (0.04, 0.0, 1.27), (0.25, 0.18, 0.27)))
    parts.append(ellipsoid("hood_crown", (-0.04, 0.0, 1.47), (0.17, 0.14, 0.14), (0, math.radians(-25), 0)))
    parts.append(curve_tube("hood_tip", [(-0.02, 1.50), (-0.14, 1.60), (-0.26, 1.57), (-0.36, 1.50), (-0.395, 1.43)],
                            [0.11, 0.07, 0.045, 0.03, 0.016]))
    parts.append(ellipsoid("hood_cowl", (-0.07, 0.0, 1.10), (0.16, 0.15, 0.14)))
    parts.append(tube("collar", (0.0, 0.0, 1.00), (0.0, 0.0, 1.10), 0.13, 0.11, 0.9))
    # Robe and shorts.
    parts.append(tube("robe", (0.0, 0.0, 0.42), (0.0, 0.0, 1.0), 0.26, 0.13, 0.78))
    parts.append(tube("shorts", (0.0, 0.0, 0.28), (0.0, 0.0, 0.44), 0.15, 0.16, 0.75))
    for side, s in (("L", 1.0), ("R", -1.0)):
        # Sleeve: narrow at the shoulder, wide cuff, small hand.
        parts.append(tube("arm_up_" + side, (0.0, 0.11 * s, 0.97), (0.0, 0.20 * s, 0.76), 0.065, 0.058))
        parts.append(tube("arm_fore_" + side, (0.0, 0.20 * s, 0.76), (0.0, 0.29 * s, 0.50), 0.058, 0.098))
        parts.append(ellipsoid("hand_" + side, (0.0, 0.305 * s, 0.445), (0.032, 0.024, 0.055)))
        parts.append(tube("thigh_" + side, (0.0, 0.07 * s, 0.34), (0.0, 0.07 * s, 0.18), 0.036, 0.032))
        parts.append(tube("shin_" + side, (0.0, 0.07 * s, 0.18), (0.0, 0.07 * s, 0.045), 0.032, 0.027))
        parts.append(ellipsoid("foot_" + side, (0.065, 0.07 * s, 0.032), (0.105, 0.045, 0.034)))
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "Body"
    import os
    # Make every piece point outwards, otherwise the voxel remesh treats thin tubes as holes.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if os.environ.get("SKIP_REMESH"):
        return body
    # Fuse every piece into one watertight surface so automatic weights behave.
    remesh = body.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.010
    bpy.ops.object.modifier_apply(modifier="Remesh")
    smooth = body.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.8
    smooth.iterations = 6
    bpy.ops.object.modifier_apply(modifier="Smooth")
    decimate = body.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = 0.25
    bpy.ops.object.modifier_apply(modifier="Decimate")
    bpy.ops.object.shade_smooth()
    return body


BONES = {
    # name: (parent, head, tail)
    "mixamorig:Hips": (None, (0, 0, 0.40), (0, 0, 0.48)),
    "mixamorig:Spine": ("mixamorig:Hips", (0, 0, 0.48), (0, 0, 0.64)),
    "mixamorig:Spine1": ("mixamorig:Spine", (0, 0, 0.64), (0, 0, 0.80)),
    "mixamorig:Spine2": ("mixamorig:Spine1", (0, 0, 0.80), (0, 0, 0.97)),
    "mixamorig:Neck": ("mixamorig:Spine2", (0, 0, 0.97), (0, 0, 1.08)),
    "mixamorig:Head": ("mixamorig:Neck", (0, 0, 1.08), (0, 0, 1.40)),
    "HoodTip1": ("mixamorig:Head", (-0.02, 0, 1.50), (-0.15, 0, 1.60)),
    "HoodTip2": ("HoodTip1", (-0.15, 0, 1.60), (-0.28, 0, 1.55)),
    "HoodTip3": ("HoodTip2", (-0.28, 0, 1.55), (-0.395, 0, 1.43)),
}
for _side, _name, _s in (("L", "Left", 1.0), ("R", "Right", -1.0)):
    BONES[f"mixamorig:{_name}Shoulder"] = ("mixamorig:Spine2", (0, 0.03 * _s, 0.97), (0, 0.11 * _s, 0.97))
    BONES[f"mixamorig:{_name}Arm"] = (f"mixamorig:{_name}Shoulder", (0, 0.11 * _s, 0.97), (0, 0.20 * _s, 0.76))
    BONES[f"mixamorig:{_name}ForeArm"] = (f"mixamorig:{_name}Arm", (0, 0.20 * _s, 0.76), (0, 0.29 * _s, 0.50))
    BONES[f"mixamorig:{_name}Hand"] = (f"mixamorig:{_name}ForeArm", (0, 0.29 * _s, 0.50), (0, 0.32 * _s, 0.40))
    BONES[f"mixamorig:{_name}UpLeg"] = ("mixamorig:Hips", (0, 0.07 * _s, 0.38), (0, 0.07 * _s, 0.18))
    BONES[f"mixamorig:{_name}Leg"] = (f"mixamorig:{_name}UpLeg", (0, 0.07 * _s, 0.18), (0, 0.07 * _s, 0.045))
    BONES[f"mixamorig:{_name}Foot"] = (f"mixamorig:{_name}Leg", (0, 0.07 * _s, 0.045), (0.10, 0.07 * _s, 0.02))
    BONES[f"mixamorig:{_name}ToeBase"] = (f"mixamorig:{_name}Foot", (0.10, 0.07 * _s, 0.02), (0.18, 0.07 * _s, 0.015))


def build_armature():
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (parent, head, tail) in BONES.items():
        bone = arm_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = arm_data.edit_bones[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# How far (metres) each bone pulls on the surface around it. Small radii on the legs keep the robe
# hem from following them; the hood bones are large because the hood is.
RADIUS = {
    "mixamorig:Hips": 0.30, "mixamorig:Spine": 0.26, "mixamorig:Spine1": 0.26, "mixamorig:Spine2": 0.26,
    "mixamorig:Neck": 0.16, "mixamorig:Head": 0.30, "HoodTip1": 0.12, "HoodTip2": 0.10, "HoodTip3": 0.09,
}
for _n in ("Left", "Right"):
    RADIUS.update({f"mixamorig:{_n}Shoulder": 0.07, f"mixamorig:{_n}Arm": 0.11, f"mixamorig:{_n}ForeArm": 0.15,
                   f"mixamorig:{_n}Hand": 0.09, f"mixamorig:{_n}UpLeg": 0.075, f"mixamorig:{_n}Leg": 0.07,
                   f"mixamorig:{_n}Foot": 0.09, f"mixamorig:{_n}ToeBase": 0.06})


def segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def weight_body(body, arm):
    body.parent = arm
    body.matrix_parent_inverse = arm.matrix_world.inverted()
    body.modifiers.new("Armature", "ARMATURE").object = arm
    groups = {name: body.vertex_groups.new(name=name) for name in BONES}
    segments = {name: (Vector(head), Vector(tail)) for name, (_, head, tail) in BONES.items()}
    unweighted = 0
    for vertex in body.data.vertices:
        p = body.matrix_world @ vertex.co
        weights = {}
        for name, (a, b) in segments.items():
            w = max(0.0, 1.0 - segment_distance(p, a, b) / RADIUS[name]) ** 2
            if w > 0.002:
                weights[name] = w
        if not weights:
            unweighted += 1
            weights["mixamorig:Hips" if p.z < 0.7 else "mixamorig:Spine2"] = 1.0
        total = sum(weights.values())
        for name, w in sorted(weights.items(), key=lambda kv: -kv[1])[:4]:
            groups[name].add([vertex.index], w / total, "REPLACE")
    print("unweighted vertices:", unweighted)


def main():
    clean()
    body = build_body()
    mat = bpy.data.materials.new("Ink")
    mat.diffuse_color = (0.0, 0.0, 0.0, 1.0)
    body.data.materials.append(mat)
    arm = build_armature()
    weight_body(body, arm)
    print("vertex groups:", len(body.vertex_groups), "verts:", len(body.data.vertices), "faces:", len(body.data.polygons))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_apply=False, export_yup=True, export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath="/tmp/hood_boy.blend")
    print("exported", OUT)


main()
