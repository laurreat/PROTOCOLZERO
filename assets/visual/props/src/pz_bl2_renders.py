"""PROTOCOL:ZERO acabado BL2 — renders headless top-down (EEVEE, alfa).
Uso: blender.exe --background --python pz_bl2_renders.py
Sale: door_slab.png (112x400), terminal_console.png (144x176),
      zero_console.png (160x224) + .blend fuentes junto a este script.
"""
import bpy
import os

OUT = r"C:\Users\luis2\AppData\Local\Temp\opencode\bl2"
os.makedirs(OUT, exist_ok=True)

# --- Limpieza total de la escena demo (proceso background propio) ---
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for x in list(coll):
        coll.remove(x)


def metal(name, base, metallic=0.85, rough=0.45):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return m


STEEL = metal('Steel', (0.10, 0.11, 0.14))
DARK = metal('Dark', (0.05, 0.055, 0.07), 0.6, 0.6)
BOLT = metal('Bolt', (0.22, 0.23, 0.26), 0.9, 0.35)
YELLOW = metal('Yellow', (0.65, 0.47, 0.07), 0.2, 0.5)
BLACK = metal('Black', (0.03, 0.03, 0.04), 0.1, 0.7)
SCREEN = metal('Screen', (0.02, 0.05, 0.07), 0.0, 0.45)
TRIM = metal('Trim', (0.38, 0.27, 0.09), 0.9, 0.4)


def box(name, loc, size, mat, bevel=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.dimensions = size
    mod = o.modifiers.new('Edge', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    o.data.materials.append(mat)
    return o


def bolt(loc, r=0.05):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=0.06, location=loc)
    o = bpy.context.active_object
    o.data.materials.append(BOLT)
    return o


def setup_camera(w, h):
    # Camara y luces frescas por pieza (ortho_scale + resolucion exactas).
    for o in [o for o in bpy.context.scene.objects if o.type in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)
    cam_data = bpy.data.cameras.new('TopOrtho')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = max(w, h) * 1.02
    cam = bpy.data.objects.new('TopOrtho', cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0, 0, 10)
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.film_transparent = True
    sc.render.resolution_x = int(w * 100)
    sc.render.resolution_y = int(h * 100)
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    # Luz neutra de estudio (contenida: acero oscuro, sin fundidos).
    bpy.ops.object.light_add(type='SUN', location=(3, -2, 8))
    sun = bpy.context.active_object
    sun.data.energy = 1.2
    bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
    area = bpy.context.active_object
    area.data.energy = 80.0
    area.data.size = 6.0
    return [sun, area]


def clear_stage(keep=()):
    for o in list(bpy.context.scene.objects):
        if o not in keep and o.type not in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o, do_unlink=True)


def save_and_render(blend_name, png_name):
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, png_name)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, blend_name))
    bpy.ops.render.render(write_still=True)
    print('RENDERED', png_name)


# ============ 1) DOOR SLAB 1.12 x 4.0 -> 112x400 ============
rig = setup_camera(1.12, 4.0)
box('Slab', (0, 0, 0.10), (1.12, 4.0, 0.20), STEEL)
box('SlabInner', (0, 0.3, 0.16), (0.80, 2.90, 0.22), DARK, bevel=0.02)
box('SlabRib1', (0, 1.0, 0.17), (0.80, 0.10, 0.22), STEEL, bevel=0.01)
box('SlabRib2', (0, -0.4, 0.17), (0.80, 0.10, 0.22), STEEL, bevel=0.01)
for i, y in enumerate((1.85, -1.75)):
    for x in (-0.44, 0.44):
        bolt((x, y, 0.22))
# Franja de peligro inferior (6 bandas)
for i in range(6):
    box('Hz%d' % i, (-0.40 + i * 0.16, -1.55, 0.17),
        (0.08, 0.50, 0.22), YELLOW if i % 2 == 0 else BLACK, bevel=0.005)
save_and_render('door_slab.blend', 'door_slab.png')
clear_stage()

# ============ 2) TERMINAL 1.44 x 1.76 -> 144x176 ============
setup_camera(1.44, 1.76)
box('TBody', (0, 0, 0.10), (1.44, 1.76, 0.20), STEEL)
box('TScreenWell', (0, 0.42, 0.14), (0.96, 0.62, 0.16), BLACK, bevel=0.02)
box('TScreen', (0, 0.42, 0.16), (0.84, 0.50, 0.16), SCREEN, bevel=0.01)
box('TVent', (0, -0.55, 0.16), (1.00, 0.34, 0.22), DARK, bevel=0.01)
for i in range(4):
    box('TKey%d' % i, (-0.45 + i * 0.30, -0.10, 0.21),
        (0.18, 0.10, 0.04), DARK, bevel=0.008)
for x in (-0.62, 0.62):
    for y in (-0.78, 0.78):
        bolt((x, y, 0.22), r=0.045)
save_and_render('terminal_console.blend', 'terminal_console.png')
clear_stage()

# ============ 3) ZERO FRAME 1.6 x 2.24, centro transparente ============
setup_camera(1.6, 2.24)
# Marco exterior (el diamante de estado se ve por el hueco central).
box('ZTop', (0, 0.96, 0.10), (1.60, 0.32, 0.24), STEEL)
box('ZBot', (0, -0.96, 0.10), (1.60, 0.32, 0.24), STEEL)
box('ZLeft', (-0.70, 0, 0.10), (0.20, 1.60, 0.24), STEEL)
box('ZRight', (0.70, 0, 0.10), (0.20, 1.60, 0.24), STEEL)
box('ZTrimT', (0, 0.86, 0.22), (1.20, 0.08, 0.26), TRIM, bevel=0.01)
box('ZTrimB', (0, -0.86, 0.22), (1.20, 0.08, 0.26), TRIM, bevel=0.01)
box('ZWell', (0, 0, 0.02), (1.14, 1.64, 0.06), BLACK, bevel=0.02)
for x in (-0.70, 0.70):
    for y in (-0.95, 0.95):
        bolt((x, y, 0.24), r=0.05)
save_and_render('zero_console.blend', 'zero_console.png')

print('BL2 DONE')
