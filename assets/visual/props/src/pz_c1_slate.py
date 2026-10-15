"""PROTOCOL:ZERO C1 — placa de datos (data slate) top-down.
Uso: blender.exe --background --python pz_c1_slate.py
Sale: data_slate.png (120x160) + data_slate.blend
"""
import bpy
import os

OUT = r"C:\Users\luis2\AppData\Local\Temp\opencode\blc1"
os.makedirs(OUT, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for x in list(coll):
        coll.remove(x)


def metal(name, base, metallic=0.7, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return m


SLATE = metal('Slate', (0.13, 0.15, 0.18))
DARK = metal('Dark', (0.05, 0.055, 0.07), 0.5, 0.6)
LINE = metal('Line', (0.30, 0.33, 0.38), 0.6, 0.4)
AMBER = metal('Amber', (0.60, 0.42, 0.08), 0.2, 0.5)
BOLT = metal('Bolt', (0.22, 0.23, 0.26), 0.9, 0.35)


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


# Placa 1.2 x 1.6 -> 120x160
box('Plate', (0, 0, 0.08), (1.20, 1.60, 0.16), SLATE)
# Banda de pantalla superior (oscura: Godot pone el color de estado)
box('ScreenBand', (0, 0.55, 0.13), (0.92, 0.30, 0.18), DARK, bevel=0.01)
# 5 lineas de texto simuladas (grabadas claras)
for i in range(5):
    w = 0.86 - (0.18 if i == 4 else 0.0)
    box('Ln%d' % i, (-0.02, 0.22 - i * 0.17, 0.13),
        (w, 0.055, 0.17), LINE, bevel=0.005)
# Tira ambar inferior + tornillos
box('Strip', (0, -0.68, 0.13), (1.00, 0.10, 0.17), AMBER, bevel=0.008)
for x in (-0.52, 0.52):
    for y in (-0.72, 0.72):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.05, location=(x, y, 0.17))
        bpy.context.active_object.data.materials.append(BOLT)

# Camara orto exacta + luz contenida
cam_data = bpy.data.cameras.new('TopOrtho')
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 1.6 * 1.02
cam = bpy.data.objects.new('TopOrtho', cam_data)
bpy.context.scene.collection.objects.link(cam)
cam.location = (0, 0, 10)
sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.film_transparent = True
sc.render.resolution_x = 120
sc.render.resolution_y = 160
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
bpy.ops.object.light_add(type='SUN', location=(3, -2, 8))
bpy.context.active_object.data.energy = 1.2
bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
bpy.context.active_object.data.energy = 80.0
bpy.context.active_object.data.size = 6.0

sc.render.filepath = os.path.join(OUT, 'data_slate.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'data_slate.blend'))
bpy.ops.render.render(write_still=True)
print('BLC1 DONE')
