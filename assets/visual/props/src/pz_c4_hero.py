"""PROTOCOL:ZERO C4 — protagonista cenital (explorador industrial).
Uso: blender.exe --background --python pz_c4_hero.py
Sale: hero_explorer.png (160x160) + hero_explorer.blend
Frente = +Y (cunya visor arriba); Godot rota el sprite con el heading.
"""
import bpy
import os

OUT = r"C:\Users\luis2\AppData\Local\Temp\opencode\blc4"
os.makedirs(OUT, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for x in list(coll):
        coll.remove(x)


def metal(name, base, metallic=0.6, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return m


SUIT = metal('Suit', (0.11, 0.12, 0.15))
DARK = metal('Dark', (0.05, 0.055, 0.07), 0.4, 0.6)
PACK = metal('Pack', (0.14, 0.13, 0.11), 0.7, 0.45)
CYAN = metal('Cyan', (0.10, 0.55, 0.65), 0.0, 0.4)
STEEL = metal('Steel', (0.25, 0.26, 0.30), 0.85, 0.35)


def box(name, loc, size, mat, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.dimensions = size
    mod = o.modifiers.new('Edge', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    o.data.materials.append(mat)
    return o


def cyl(name, loc, r, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    return o


# Torso 1.0 (compacto) + hombreras + mochila abajo + visor cian arriba
cyl('Torso', (0, 0, 0.10), 0.50, 0.20, SUIT)
box('PadL', (-0.52, 0.05, 0.10), (0.24, 0.40, 0.22), DARK)
box('PadR', (0.52, 0.05, 0.10), (0.24, 0.40, 0.22), DARK)
box('Pack', (0, -0.58, 0.09), (0.62, 0.34, 0.18), PACK)
cyl('Tank', (0, -0.58, 0.22), 0.10, 0.10, STEEL)
box('Visor', (0, 0.42, 0.21), (0.44, 0.16, 0.04), CYAN, bevel=0.01)
box('Chest', (0, 0.05, 0.21), (0.16, 0.16, 0.04), CYAN, bevel=0.01)
box('BootL', (-0.28, -0.42, 0.06), (0.20, 0.26, 0.12), DARK, bevel=0.01)
box('BootR', (0.28, -0.42, 0.06), (0.20, 0.26, 0.12), DARK, bevel=0.01)
for x in (-0.52, 0.52):
    cyl('Rivet', (x, 0.05, 0.22), 0.035, 0.03, STEEL)

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
sc.render.resolution_x = 160
sc.render.resolution_y = 160
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
bpy.ops.object.light_add(type='SUN', location=(3, -2, 8))
bpy.context.active_object.data.energy = 1.2
bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
bpy.context.active_object.data.energy = 80.0
bpy.context.active_object.data.size = 6.0

sc.render.filepath = os.path.join(OUT, 'hero_explorer.png')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'hero_explorer.blend'))
bpy.ops.render.render(write_still=True)
print('BLC4 DONE')
