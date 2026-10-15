"""PROTOCOL:ZERO — protagonista 8-dir SIN ARMAS (Blender 5.2 local headless).
Uso: blender.exe --background --python pz_hero8.py
Sale: assets/visual/characters/player/*.png (160x160 RGBA) + hero8.blend en src/.
Frente del modelo = +Y. La camara orto cenital muestra +Y arriba en el PNG.
Sufijos = direccion EN PANTALLA hacia donde mira el visor:
north=0 (visor arriba), north_west=45, west=90, south_west=135, south=180,
south_east=225, east=270, north_east=315 (rotacion del rig sobre Z).
SIN ARMAS: solo traje, casco+visor cian, mochila, dispositivo de diagnostico.
"""
import bpy
import mathutils
import os
import math

REPO = r"C:\Users\luis2\Documents\protocol-zero"
OUT = os.path.join(REPO, "assets", "visual", "characters", "player")
SRC = os.path.join(REPO, "assets", "visual", "characters", "src")
os.makedirs(OUT, exist_ok=True)
os.makedirs(SRC, exist_ok=True)

# --- Limpieza ---
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
    for x in list(coll):
        try:
            coll.remove(x)
        except Exception:
            pass


def metal(name, base, metallic=0.6, rough=0.5, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    try:
        bsdf.inputs['Metallic'].default_value = metallic
    except Exception:
        pass
    try:
        bsdf.inputs['Roughness'].default_value = rough
    except Exception:
        pass
    if emission is not None:
        try:
            bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
            bsdf.inputs['Emission Strength'].default_value = 2.0
        except Exception:
            pass
    return m


SUIT = metal('Suit', (0.11, 0.12, 0.15))
DARK = metal('Dark', (0.05, 0.055, 0.07), 0.4, 0.6)
PACK = metal('Pack', (0.10, 0.095, 0.085), 0.7, 0.45)
CYAN = metal('Cyan', (0.10, 0.55, 0.65), 0.0, 0.4)
CYAN_HOT = metal('CyanHot', (0.35, 0.95, 1.0), 0.0, 0.3,
                 emission=(0.2, 0.8, 1.0))
STEEL = metal('Steel', (0.16, 0.17, 0.20), 0.85, 0.35)

root = bpy.data.objects.new('HeroRoot', None)
bpy.context.scene.collection.objects.link(root)


def box(name, loc, size, mat, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.dimensions = size
    try:
        mod = o.modifiers.new('Edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    except Exception:
        pass
    o.data.materials.append(mat)
    o.parent = root
    return o


def cyl(name, loc, r, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    o.parent = root
    return o


torso = cyl('Torso', (0, 0, 0.10), 0.50, 0.20, SUIT)
padL = box('PadL', (-0.52, 0.05, 0.10), (0.24, 0.40, 0.22), DARK)
padR = box('PadR', (0.52, 0.05, 0.10), (0.24, 0.40, 0.22), DARK)
pack = box('Pack', (0, -0.58, 0.09), (0.62, 0.34, 0.18), PACK)
tank = cyl('Tank', (0, -0.58, 0.22), 0.10, 0.10, STEEL)
helm = cyl('Helmet', (0, 0.30, 0.16), 0.28, 0.16, DARK)
visor = box('Visor', (0, 0.42, 0.24), (0.44, 0.16, 0.05), CYAN, bevel=0.01)
chest = box('Chest', (0, 0.05, 0.21), (0.16, 0.16, 0.04), CYAN, bevel=0.01)
armL = box('ArmL', (-0.66, -0.02, 0.08), (0.20, 0.48, 0.16), SUIT, bevel=0.015)
armR = box('ArmR', (0.66, -0.02, 0.08), (0.20, 0.48, 0.16), SUIT, bevel=0.015)
diag = box('DiagDev', (-0.66, 0.10, 0.17), (0.12, 0.14, 0.04), CYAN,
           bevel=0.008)
bootL = box('BootL', (-0.28, -0.42, 0.06), (0.20, 0.26, 0.12), DARK,
            bevel=0.01)
bootR = box('BootR', (0.28, -0.42, 0.06), (0.20, 0.26, 0.12), DARK,
            bevel=0.01)
for x in (-0.52, 0.52):
    cyl('Rivet', (x, 0.05, 0.22), 0.035, 0.03, STEEL)

BASE = {
    armL.name: armL.location.copy(),
    armR.name: armR.location.copy(),
    bootL.name: bootL.location.copy(),
    bootR.name: bootR.location.copy(),
}

# --- Camara orto cenital + luz neutra ---
cam_data = bpy.data.cameras.new('TopOrtho')
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 1.7
cam = bpy.data.objects.new('TopOrtho', cam_data)
bpy.context.scene.collection.objects.link(cam)
cam.location = (0, 0, 10)
sc = bpy.context.scene
sc.camera = cam
sc.render.film_transparent = True
sc.render.resolution_x = 160
sc.render.resolution_y = 160
sc.render.resolution_percentage = 100
try:
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
except Exception as e:
    print('IMGSET-WARN', e)
bpy.ops.object.light_add(type='SUN', location=(3, -2, 8))
try:
    bpy.context.active_object.data.energy = 1.0
except Exception:
    pass
bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
try:
    bpy.context.active_object.data.energy = 40.0
    bpy.context.active_object.data.size = 6.0
except Exception:
    pass

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, 'hero8.blend'))

DIRS = [
    ('north', 0.0), ('north_west', 45.0), ('west', 90.0),
    ('south_west', 135.0), ('south', 180.0), ('south_east', 225.0),
    ('east', 270.0), ('north_east', 315.0),
]


def set_visor(hot):
    try:
        visor.data.materials.clear()
        visor.data.materials.append(CYAN_HOT if hot else CYAN)
    except Exception as e:
        print('VISOR-WARN', e)


def pose(arm_dy=0.0, boot_dy=0.0, mirror=False):
    s = 1.0 if not mirror else -1.0
    armL.location = BASE[armL.name].copy()
    armR.location = BASE[armR.name].copy()
    bootL.location = BASE[bootL.name].copy()
    bootR.location = BASE[bootR.name].copy()
    armL.location.y += s * arm_dy
    armR.location.y -= s * arm_dy
    bootL.location.y -= s * boot_dy
    bootR.location.y += s * boot_dy


def render_frame(fname):
    sc.render.filepath = os.path.join(OUT, fname)
    bpy.ops.render.render(write_still=True)
    print('FRAME', fname)


def reset_rig():
    root.rotation_euler = (0, 0, 0)
    root.scale = (1, 1, 1)
    set_visor(False)
    armL.location = BASE[armL.name].copy()
    armR.location = BASE[armR.name].copy()
    bootL.location = BASE[bootL.name].copy()
    bootR.location = BASE[bootR.name].copy()


STEP = 0.09
# idle + move (2 frames)
for dname, deg in DIRS:
    reset_rig()
    root.rotation_euler[2] = math.radians(deg)
    render_frame('hero_idle_%s.png' % dname)
    reset_rig()
    root.rotation_euler[2] = math.radians(deg)
    pose(STEP, STEP)
    render_frame('hero_move_%s_f0.png' % dname)
    reset_rig()
    root.rotation_euler[2] = math.radians(deg)
    pose(STEP, STEP, mirror=True)
    render_frame('hero_move_%s_f1.png' % dname)

# dash: anticipacion + 8 desplazamientos + recuperacion
reset_rig()
root.scale = (1.1, 0.9, 0.85)
set_visor(False)
render_frame('hero_dash_start.png')
for dname, deg in DIRS:
    reset_rig()
    root.rotation_euler[2] = math.radians(deg)
    root.scale = (0.9, 1.12, 1.0)
    set_visor(True)
    pose(-STEP, STEP)
    render_frame('hero_dash_%s.png' % dname)
reset_rig()
set_visor(False)
render_frame('hero_dash_recovery.png')

# interaccion (4 gestos: brazos al frente, sobre el dispositivo)
for iname in ('generator', 'terminal', 'zero', 'read'):
    reset_rig()
    armL.location.y += 0.16
    armR.location.y += 0.16
    bootL.location.y -= 0.03
    bootR.location.y -= 0.03
    render_frame('hero_interact_%s.png' % iname)

# deteccion y captura (estados existentes: sobresalto + derrota)
reset_rig()
set_visor(True)
root.scale = (1.05, 1.05, 0.9)
render_frame('hero_detected.png')
reset_rig()
root.rotation_euler[2] = math.radians(90.0)
root.scale = (1.0, 1.0, 0.55)
set_visor(False)
render_frame('hero_captured.png')

print('HERO8 DONE')
