"""PROTOCOL:ZERO — tramo inferior del pad (continuacion del descenso).
Uso: blender.exe --background --python pz_pad_steps.py
Sale: stairs_pad.png (480x320) + stairs_pad.blend
"""
import bpy
import os

OUT = r"C:\Users\luis2\AppData\Local\Temp\opencode\bln3"
os.makedirs(OUT, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for x in list(coll):
        coll.remove(x)


def metal(name, base, metallic=0.7, rough=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return m


DARK = metal('Dark', (0.04, 0.045, 0.06), 0.5, 0.6)
AMBER = metal('Amber', (0.60, 0.42, 0.08), 0.2, 0.5)
BOLT = metal('Bolt', (0.22, 0.23, 0.26), 0.9, 0.35)
SH = [metal('P%d' % i, (0.085 - i * 0.012, 0.09 - i * 0.012, 0.105 - i * 0.012)) for i in range(5)]


def box(name, loc, size, mat, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.dimensions = size
    mod = o.modifiers.new('Edge', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    o.data.materials.append(mat)
    return o


# Tramo 4.8 x 3.2 -> 480x320 : 5 peldanos, mas oscuro (profundidad),
# filo ambar solo en el labio sur (borde de salida).
cam_data = bpy.data.cameras.new('TopOrtho')
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 4.8 * 1.02
cam = bpy.data.objects.new('TopOrtho', cam_data)
bpy.context.scene.collection.objects.link(cam)
cam.location = (0, 0, 10)
sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.film_transparent = True
sc.render.resolution_x = 480
sc.render.resolution_y = 320
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
bpy.ops.object.light_add(type='SUN', location=(3, -2, 8))
bpy.context.active_object.data.energy = 1.2
bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
bpy.context.active_object.data.energy = 80.0
bpy.context.active_object.data.size = 6.0

box('Base', (0, 0, 0.02), (4.8, 3.2, 0.08), DARK)
for i in range(5):
    y = 1.20 - i * 0.60
    box('Tread%d' % i, (0, y, 0.08), (4.4, 0.50, 0.10), SH[i], bevel=0.01)
    if i == 4:
        box('Lip', (0, y - 0.24, 0.12), (4.4, 0.06, 0.10), AMBER, bevel=0.005)
for x in (-2.25, 2.25):
    for y in (-1.45, 1.45):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.05, location=(x, y, 0.14))
        bpy.context.active_object.data.materials.append(BOLT)

sc.render.filepath = os.path.join(OUT, 'stairs_pad.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'stairs_pad.blend'))
bpy.ops.render.render(write_still=True)
print('BLN3P DONE')
