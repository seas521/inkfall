"""Generate an eight-pose 3D stylized flame atlas; no fluid simulation dependency."""
import bpy
import math
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1024
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.world.color = (0.025, 0.025, 0.025)
scene.view_settings.view_transform = 'Standard'

def material(name, color, emission):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = 0.5
    node.inputs['Emission Color'].default_value = (*color, 1)
    node.inputs['Emission Strength'].default_value = emission
    return mat

outer = material('Amber outer body', (0.8, 0.105, 0.006), 0.4)
middle = material('Golden flame', (1.0, 0.37, 0.015), 0.55)
core = material('Ivory hot core', (1.0, 0.82, 0.38), 1.0)

def tongue(name, x, y, z, height, width, phase, mat):
    vertices, faces = [], []
    rings, sides = 20, 24
    for j in range(rings):
        t = j / (rings - 1)
        radius = width * ((math.sin(math.pi * (0.15 + t * 0.85))) ** 0.8) * (1 - t) ** 0.25
        radius = max(radius, 0.003)
        bend = math.sin(t * 5.5 + phase) * 0.14 * t
        for k in range(sides):
            a = k * math.tau / sides
            vertices.append((x + bend + radius * math.cos(a), y + radius * 0.48 * math.sin(a), z + height * t))
    for j in range(rings - 1):
        for k in range(sides):
            a = j * sides + k
            b = j * sides + (k + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True

for frame in range(8):
    x = -2.4 + (frame % 4) * 1.6
    base = 0.10 if frame < 4 else -1.50
    phase = frame * math.tau / 8
    tongue('outer_%d' % frame, x, 0, base, 1.28 + math.sin(phase) * 0.07, 0.34, phase, outer)
    tongue('side_%d' % frame, x - 0.25, -0.06, base, 0.82 + math.sin(phase+1) * 0.13, 0.18, phase+2, outer)
    tongue('sideB_%d' % frame, x + 0.24, -0.05, base, 0.72 + math.cos(phase) * 0.12, 0.17, phase+3, middle)
    tongue('middle_%d' % frame, x, -0.17, base, 0.98 + math.sin(phase+0.5) * 0.10, 0.24, phase+0.3, middle)
    tongue('core_%d' % frame, x, -0.30, base, 0.57 + math.sin(phase+1.2) * 0.07, 0.12, phase+0.6, core)

for location, energy, size in [((-3,-4,7),1200,5),((4,1,3),350,3)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    lamp = bpy.context.object
    lamp.data.energy, lamp.data.shape, lamp.data.size = energy, 'DISK', size
    lamp.rotation_euler = (Vector((0,0,0)) - lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-12,0))
camera = bpy.context.object
camera.rotation_euler = (Vector((0,0,0)) - camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 6.4
scene.camera = camera
scene.render.filepath = '/private/tmp/inkfall-flame-atlas.png'
bpy.ops.wm.save_as_mainfile(filepath='/private/tmp/inkfall-flame-source.blend')
bpy.ops.render.render(write_still=True)
