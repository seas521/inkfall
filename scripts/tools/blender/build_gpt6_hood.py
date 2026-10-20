"""Build the isolated GPT6 motion-study character. Run with Blender -b -P this_file.

The side silhouette follows the user's hooded-child reference. Explicit skin
weights keep the sleeves, coat hem and hood independent of the moving limbs.
The game supplies contact-aware animation; this file is the editable source rig.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "assets/art/prototypes/gpt6_hood"
SOURCE = ROOT / "artifacts/gpt6_motion/source"
BONES = {}
SKINNED = []


def material(name, color, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = next((node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        output = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.95
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def bone(name, parent, head, tail):
    BONES[name] = (parent, Vector(head), Vector(tail))


def mesh(name, verts, faces, mat, weight_fn):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    groups = {}
    for vert in data.vertices:
        weights = weight_fn(vert.co)
        total = sum(weights.values())
        for key, value in weights.items():
            if value <= 0:
                continue
            if key not in groups:
                groups[key] = obj.vertex_groups.new(name=key)
            groups[key].add([vert.index], value / total, "REPLACE")
    for polygon in data.polygons:
        polygon.use_smooth = True
    SKINNED.append(obj)
    return obj


def fixed(name):
    return lambda point: {name: 1.0}


def blend_chain(point, names):
    distances = [(point - BONES[name][1]).length for name in names]
    weights = [1 / max(0.035, distance) ** 4 for distance in distances]
    return dict(zip(names, weights))


def loft(name, rings, mat, weight_fn, count=24):
    """Horizontal ellipse rings: (x, y, z, x-radius, y-radius)."""
    verts = []
    for x, y, z, rx, ry in rings:
        for i in range(count):
            angle = math.tau * i / count
            verts.append((x + rx * math.cos(angle), y + ry * math.sin(angle), z))
    faces = []
    for j in range(len(rings) - 1):
        for i in range(count):
            a = j * count + i
            b = j * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    faces.append(tuple(reversed(range(count))))
    faces.append(tuple((len(rings) - 1) * count + i for i in range(count)))
    return mesh(name, verts, faces, mat, weight_fn)


def tube(name, points, radii, mat, weight_fn, count=12):
    verts = []
    for i, point in enumerate(points):
        p = Vector(point)
        before = Vector(points[max(0, i - 1)])
        after = Vector(points[min(len(points) - 1, i + 1)])
        tangent = (after - before).normalized()
        first = tangent.cross(Vector((0, 1, 0))).normalized()
        second = tangent.cross(first).normalized()
        for k in range(count):
            angle = math.tau * k / count
            verts.append(p + radii[i] * (first * math.cos(angle) + second * math.sin(angle)))
    faces = []
    for j in range(len(points) - 1):
        for i in range(count):
            a = j * count + i
            b = j * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    faces.append(tuple(reversed(range(count))))
    faces.append(tuple((len(points) - 1) * count + i for i in range(count)))
    return mesh(name, verts, faces, mat, weight_fn)


def smooth_outline(points, steps=5):
    out = []
    for index in range(len(points)):
        a, b, c, d = [Vector(points[(index + offset) % len(points)]) for offset in (-1, 0, 1, 2)]
        for j in range(steps):
            t = j / steps
            out.append(0.5 * ((2 * b) + (-a + c) * t
                             + (2 * a - 5 * b + 4 * c - d) * t * t
                             + (-a + 3 * b - 3 * c + d) * t * t * t))
    return out


def profile(name, outline, depth, mat, weight_fn, center=None):
    """A rounded side-profile volume, not a collection of intersecting spheres."""
    outline = smooth_outline(outline)
    if center is None:
        center = sum(outline, Vector((0, 0))) / len(outline)
    else:
        center = Vector(center)
    verts = []
    rings = [(-1.0, 0.04), (-0.94, 0.48), (-0.72, 0.86),
             (-0.3, 0.99), (0.3, 0.99), (0.72, 0.86), (0.94, 0.48), (1.0, 0.04)]
    for y, scale in rings:
        for point in outline:
            p = center.lerp(point, scale)
            verts.append((p.x, y * depth, p.y))
    count = len(outline)
    faces = []
    for j in range(len(rings) - 1):
        for i in range(count):
            a = j * count + i
            b = j * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    faces.extend([tuple(reversed(range(count))),
                  tuple((len(rings) - 1) * count + i for i in range(count))])
    return mesh(name, verts, faces, mat, weight_fn)


def make_rig():
    bone("Root", None, (0, 0, 0), (0, 0, 0.15))
    bone("Pelvis", "Root", (0, 0, 0.76), (0, 0, 0.92))
    bone("Chest", "Pelvis", (0, 0, 0.99), (0, 0, 1.30))
    bone("Head", "Chest", (0, 0, 1.34), (0, 0, 1.76))
    bone("HoodA", "Head", (-0.08, 0, 1.93), (-0.32, 0, 2.03))
    bone("HoodB", "HoodA", (-0.32, 0, 2.03), (-0.57, 0, 1.91))
    for side, depth in (("Near", -0.13), ("Far", 0.13)):
        bone("UpperArm" + side, "Chest", (0, depth, 1.27), (0, depth * 1.2, 1.02))
        bone("Forearm" + side, "UpperArm" + side, (0, depth * 1.2, 1.02), (0.02, depth * 1.3, 0.69))
        bone("Hand" + side, "Forearm" + side, (0.02, depth * 1.3, 0.69), (0.04, depth * 1.3, 0.57))
        bone("Thigh" + side, "Pelvis", (0, depth * 0.55, 0.76), (0, depth * 0.55, 0.42))
        bone("Shin" + side, "Thigh" + side, (0, depth * 0.55, 0.42), (0, depth * 0.55, 0.09))
        bone("Foot" + side, "Shin" + side, (0, depth * 0.55, 0.09), (0.15, depth * 0.55, 0.045))
    bone("HemBack", "Pelvis", (-0.13, 0, 0.9), (-0.23, 0, 0.64))
    bone("HemFront", "Pelvis", (0.13, 0, 0.9), (0.23, 0, 0.64))
    data = bpy.data.armatures.new("GPT6_Hood_Rig")
    arm = bpy.data.objects.new("GPT6_Hood_Rig", data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (parent, head, tail) in BONES.items():
        b = data.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.show_in_front = True
    return arm


def make_body(ink, cloth, face, eye):
    def coat_weights(p):
        hem = max(0, min(1, (0.98 - p.z) / 0.3)) * 0.9
        chest = max(0, min(1, (p.z - 0.84) / 0.37))
        return {"Chest": chest, "Pelvis": (1 - chest) * (1 - hem),
                "HemFront" if p.x > 0 else "HemBack": (1 - chest) * hem}

    loft("Coat", [
        (-0.01, 0, .64, .252, .148), (-0.015, 0, .67, .25, .149),
        (-.025, 0, .77, .232, .143), (-.025, 0, .9, .20, .128),
        (-.015, 0, 1.04, .167, .117), (0, 0, 1.18, .139, .126),
        (0, 0, 1.27, .126, .133), (0, 0, 1.31, .093, .109),
    ], cloth, coat_weights, 40)
    loft("Collar", [(0, 0, 1.26, .102, .11), (-.02, 0, 1.34, .14, .135),
                    (-.035, 0, 1.4, .16, .14)], ink, fixed("Head"))

    def hood_weights(p):
        tip = max(0, min(1, (-p.x - .12) / .3)) * max(0, min(1, (p.z - 1.72) / .2))
        end = max(0, min(1, (-p.x - .30) / .23))
        return {"Head": 1 - tip, "HoodA": tip * (1 - end), "HoodB": tip * end}

    profile("Hood", [
        (-.16, 1.34), (-.29, 1.43), (-.28, 1.58), (-.30, 1.77),
        (-.40, 1.88), (-.57, 1.88), (-.55, 1.96), (-.40, 2.075),
        (-.22, 2.12), (-.05, 2.085), (.15, 1.98), (.30, 1.86),
        (.28, 1.72), (.24, 1.57), (.27, 1.49), (.19, 1.40), (.04, 1.34),
    ], .19, cloth, hood_weights, center=(-.07, 1.72))
    # Dark recessed face on each side; the eye disappears naturally during a turn.
    for sign in (-1, 1):
        aperture = profile("Face_%s" % sign, [
            (.02, 1.42), (-.015, 1.49), (.015, 1.64), (.10, 1.78),
            (.245, 1.84), (.235, 1.68), (.20, 1.58), (.225, 1.50), (.15, 1.44),
        ], .006, face, fixed("Head"), center=(.12, 1.61))
        for v in aperture.data.vertices:
            v.co.y += sign * .17
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1,
                                           location=(.155, sign * .186, 1.625))
        obj = bpy.context.object
        obj.name = "AmberEye_%s" % sign
        obj.scale = (.022, .012, .041)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.data.materials.append(eye)
        obj.vertex_groups.new(name="Head").add(list(range(len(obj.data.vertices))), 1, "REPLACE")
        for p in obj.data.polygons:
            p.use_smooth = True
        SKINNED.append(obj)
    for side, depth in (("Far", .13), ("Near", -.13)):
        upper, lower = "UpperArm" + side, "Forearm" + side

        def sleeve_weights(p, up=upper, low=lower):
            w = max(0, min(1, (1.11 - p.z) / .18))
            return {up: 1 - w, low: w}

        loft("Sleeve" + side, [
            (.02, depth * 1.30, .79, .083, .077),
            (.02, depth * 1.29, .82, .082, .074),
            (.01, depth * 1.25, .93, .068, .064),
            (0, depth * 1.20, 1.01, .061, .058),
            (0, depth * 1.17, 1.06, .064, .060),
            (0, depth * 1.06, 1.19, .072, .068),
            (0, depth, 1.27, .066, .062),
            (0, depth, 1.30, .04, .04),
        ], cloth, sleeve_weights)
        hand = "Hand" + side
        loft(hand + "Mesh", [
            (.022, depth * 1.3, .72, .039, .022), (.02, depth * 1.3, .76, .041, .026),
            (.02, depth * 1.3, .81, .027, .024),
        ], ink, fixed(hand), 16)
        for i in range(4):
            x = -.012 + i * .023
            end = .656 + abs(i - 1.5) * .014
            tube("Finger%s%d" % (side, i), [
                (x, depth * 1.3, .74), (x + .006, depth * 1.3, .70),
                (x - .009, depth * 1.3, end), (x - .014, depth * 1.3, end + .004),
            ], [.010, .009, .006, .0025], ink, fixed(hand), 8)
        tube("Thumb" + side, [(.05, depth * 1.3, .76), (.076, depth * 1.3, .735),
                             (.072, depth * 1.3, .70)], [.014, .011, .004], ink, fixed(hand))
        zdepth = depth * .55

        def leg_weights(p, s=side):
            w = max(0, min(1, (.48 - p.z) / .12))
            return {"Thigh" + s: 1 - w, "Shin" + s: w}

        loft("Leg" + side, [
            (0, zdepth, .08, .039, .036), (0, zdepth, .15, .041, .037),
            (-.012, zdepth, .26, .048, .041), (0, zdepth, .38, .044, .041),
            (0, zdepth, .42, .044, .041), (0, zdepth, .47, .049, .044),
            (0, zdepth, .60, .068, .056), (0, zdepth, .76, .08, .060),
        ], ink, leg_weights)
        foot = profile("Boot" + side, [
            (-.046, .015), (-.052, .06), (-.038, .13), (.014, .14),
            (.045, .08), (.115, .044), (.175, .035), (.185, .015), (.11, .008),
        ], .045, ink, fixed("Foot" + side), center=(.035, .055))
        for v in foot.data.vertices:
            v.co.y += zdepth


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    ink = material("Ink", (.008, .009, .009))
    cloth = material("CharcoalCloth", (.016, .018, .018))
    face = material("FaceVoid", (.001, .001, .001))
    eye = material("Amber", (1.0, .43, .055), 2.0)
    arm = make_rig()
    make_body(ink, cloth, face, eye)
    for obj in SKINNED:
        if obj.name.startswith(("Sleeve", "Hand", "Finger", "Thumb")):
            for vertex in obj.data.vertices:
                if vertex.co.z < 0.78:
                    vertex.co.z -= 0.09
                elif vertex.co.z < 1.02:
                    vertex.co.z = 1.02 - (1.02 - vertex.co.z) * 1.375
        modifier = obj.modifiers.new("Skin", "ARMATURE")
        modifier.object = arm
        obj.parent = arm
    bpy.ops.object.select_all(action="DESELECT")
    for obj in SKINNED + [arm]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    OUTPUT.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / "gpt6_hood_boy.glb"), export_format="GLB",
        use_selection=True, export_animations=False, export_yup=True,
        export_apply=False, export_materials="EXPORT",
    )
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "gpt6_hood_boy.blend"))
    print("GPT6 asset:", len(SKINNED), "meshes,", len(BONES), "bones")


main()
