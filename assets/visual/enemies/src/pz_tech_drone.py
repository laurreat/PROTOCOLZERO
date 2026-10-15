"""PROTOCOL:ZERO — Tech + drones (Blender 5.2 local headless).
Uso: blender.exe --background --python pz_tech_drone.py
Sale: assets/visual/characters/tech/*.png (128) + enemies/security_drone/*.png
+ .blend en src/. Frente = +Y; sufijos = direccion en pantalla del frente.
Tech: uniforme ambar, casco con lampara, caja de herramientas diminuta (NO arma).
Dron: casco octogonal, ojo frontal por estado, pods laterales, tobera trasera.
"""
import bpy
import mathutils
import os
import math

REPO = r"C:\Users\luis2\Documents\protocol-zero"
TECH_OUT = os.path.join(REPO, "assets", "visual", "characters", "tech")
DRON_OUT = os.path.join(REPO, "assets", "visual", "enemies", "security_drone")
CSRC = os.path.join(REPO, "assets", "visual", "characters", "src")
ESRC = os.path.join(REPO, "assets", "visual", "enemies", "src")
for d in (TECH_OUT, DRON_OUT, CSRC, ESRC):
    os.makedirs(d, exist_ok=True)


def wipe():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for x in list(coll):
            try:
                coll.remove(x)
            except Exception:
                pass


def metal(name, base, metallic=0.6, rough=0.5, emission=None, estr=2.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    for k, v in (('Metallic', metallic), ('Roughness', rough)):
        try:
            bsdf.inputs[k].default_value = v
        except Exception:
            pass
    if emission is not None:
        try:
            bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
            bsdf.inputs['Emission Strength'].default_value = estr
        except Exception:
            pass
    return m


def setup_cam(res):
    cam_data = bpy.data.cameras.new('TopOrtho')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 1.7
    cam = bpy.data.objects.new('TopOrtho', cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0, 0, 10)
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.film_transparent = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
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
    return sc


DIRS = [
    ('north', 0.0), ('north_west', 45.0), ('west', 90.0),
    ('south_west', 135.0), ('south', 180.0), ('south_east', 225.0),
    ('east', 270.0), ('north_east', 315.0),
]

# ================= TECH =================
wipe()
UNI = metal('Uni', (0.32, 0.24, 0.10), 0.2, 0.7)
DARK = metal('Dark', (0.07, 0.06, 0.05), 0.4, 0.6)
AMBER = metal('Amber', (0.85, 0.55, 0.10), 0.0, 0.4)
AMBER_HOT = metal('AmberHot', (1.0, 0.7, 0.2), 0.0, 0.3,
                  emission=(1.0, 0.6, 0.15), estr=2.5)
STEEL = metal('Steel', (0.16, 0.17, 0.20), 0.85, 0.35)

troot = bpy.data.objects.new('TechRoot', None)
bpy.context.scene.collection.objects.link(troot)


def tbox(name, loc, size, mat, bevel=0.02):
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
    o.parent = troot
    return o


def tcyl(name, loc, r, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    o.parent = troot
    return o


tcyl('Torso', (0, 0, 0.10), 0.46, 0.20, UNI)
tbox('VestL', (-0.30, 0.05, 0.20), (0.16, 0.30, 0.04), AMBER, bevel=0.01)
tbox('VestR', (0.30, 0.05, 0.20), (0.16, 0.30, 0.04), AMBER, bevel=0.01)
tcyl('Helmet', (0, 0.28, 0.16), 0.26, 0.15, DARK)
lamp = tbox('Lamp', (0, 0.38, 0.22), (0.16, 0.12, 0.05), AMBER_HOT,
            bevel=0.008)
tbox('ArmL', (-0.58, -0.02, 0.08), (0.18, 0.44, 0.15), UNI, bevel=0.015)
tbox('ArmR', (0.58, -0.02, 0.08), (0.18, 0.44, 0.15), UNI, bevel=0.015)
tool = tbox('Tool', (0.58, 0.14, 0.16), (0.10, 0.16, 0.05), STEEL,
            bevel=0.008)
tbox('BootL', (-0.26, -0.40, 0.06), (0.19, 0.25, 0.12), DARK, bevel=0.01)
tbox('BootR', (0.26, -0.40, 0.06), (0.19, 0.25, 0.12), DARK, bevel=0.01)
tbox('Toolbox', (-0.45, -0.62, 0.07), (0.30, 0.18, 0.14), AMBER, bevel=0.01)
tech_limbs = [o for o in (bpy.data.objects['ArmL'], bpy.data.objects['ArmR'],
                          bpy.data.objects['BootL'],
                          bpy.data.objects['BootR'])]
TECH_BASE = {o.name: o.location.copy() for o in tech_limbs}

sc = setup_cam(128)
bpy.ops.wm.save_as_mainfile(
    filepath=os.path.join(CSRC, 'tech8.blend'))


def t_render(fname):
    sc.render.filepath = os.path.join(TECH_OUT, fname)
    bpy.ops.render.render(write_still=True)
    print('TECH', fname)


def t_reset():
    troot.rotation_euler = (0, 0, 0)
    troot.scale = (1, 1, 1)
    for o in tech_limbs:
        o.location = TECH_BASE[o.name].copy()


STEP = 0.08
for dname, deg in DIRS:
    t_reset()
    troot.rotation_euler[2] = math.radians(deg)
    t_render('tech_idle_%s.png' % dname)
    t_reset()
    troot.rotation_euler[2] = math.radians(deg)
    bpy.data.objects['ArmL'].location.y += STEP
    bpy.data.objects['ArmR'].location.y -= STEP
    bpy.data.objects['BootL'].location.y -= STEP
    bpy.data.objects['BootR'].location.y += STEP
    t_render('tech_move_%s_f0.png' % dname)
    t_reset()
    troot.rotation_euler[2] = math.radians(deg)
    bpy.data.objects['ArmL'].location.y -= STEP
    bpy.data.objects['ArmR'].location.y += STEP
    bpy.data.objects['BootL'].location.y += STEP
    bpy.data.objects['BootR'].location.y -= STEP
    t_render('tech_move_%s_f1.png' % dname)

# reparacion 3 s: arrodillado + herramienta al frente (3 fases)
for i, dy in enumerate((0.10, 0.16, 0.13)):
    t_reset()
    troot.rotation_euler[2] = math.radians(180.0)  # de espaldas-sur: trabaja
    troot.scale = (1.0, 1.0, 0.88)
    bpy.data.objects['ArmL'].location.y += dy
    bpy.data.objects['ArmR'].location.y += dy
    t_render('tech_repair_f%d.png' % i)
t_reset()
bpy.data.objects['ArmR'].location.y += 0.18  # saludo / conversacion
t_render('tech_interact.png')
t_reset()
troot.scale = (1.05, 1.05, 0.92)  # reaccion a energia (sobresalto leve)
t_render('tech_react.png')
t_reset()  # done = idle sur reutilizable; marco dedicado
t_render('tech_done.png')

# ================= DRON =================
wipe()
HULL = metal('Hull', (0.13, 0.14, 0.17), 0.75, 0.4)
DARK2 = metal('Dark2', (0.05, 0.05, 0.07), 0.4, 0.6)
EYE_CYAN = metal('EyeCyan', (0.2, 0.8, 0.9), 0.0, 0.3,
                 emission=(0.2, 0.8, 0.9), estr=3.0)
EYE_AMBER = metal('EyeAmber', (1.0, 0.65, 0.10), 0.0, 0.3,
                  emission=(1.0, 0.6, 0.1), estr=3.0)
EYE_RED = metal('EyeRed', (1.0, 0.15, 0.12), 0.0, 0.3,
                emission=(1.0, 0.1, 0.1), estr=3.5)
EYE_DIM = metal('EyeDim', (0.10, 0.10, 0.12), 0.2, 0.7)
STEEL2 = metal('Steel2', (0.20, 0.21, 0.24), 0.85, 0.35)

droot = bpy.data.objects.new('DroneRoot', None)
bpy.context.scene.collection.objects.link(droot)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.52, depth=0.22,
                                    location=(0, 0, 0.12))
hull = bpy.context.active_object
hull.name = 'Hull'
hull.data.materials.append(HULL)
hull.parent = droot
bpy.ops.mesh.primitive_cylinder_add(radius=0.30, depth=0.10,
                                    location=(0, 0, 0.26))
core = bpy.context.active_object
core.name = 'CoreTop'
core.data.materials.append(DARK2)
core.parent = droot
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.58, 0.25))
eye = bpy.context.active_object
eye.name = 'Eye'
eye.dimensions = (0.38, 0.18, 0.10)
eye.data.materials.append(EYE_CYAN)
eye.parent = droot
for sx in (-1.0, 1.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * 0.62, -0.05, 0.12))
    pod = bpy.context.active_object
    pod.name = 'PodR' if sx > 0 else 'PodL'
    pod.dimensions = (0.20, 0.42, 0.16)
    pod.data.materials.append(STEEL2)
    pod.parent = droot
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.52, 0.12))
noz = bpy.context.active_object
noz.name = 'Nozzle'
noz.dimensions = (0.22, 0.14, 0.12)
noz.data.materials.append(DARK2)
noz.parent = droot

sc2 = setup_cam(128)
bpy.ops.wm.save_as_mainfile(
    filepath=os.path.join(ESRC, 'drone8.blend'))


def set_eye(mat):
    try:
        eye.data.materials.clear()
        eye.data.materials.append(mat)
    except Exception as e:
        print('EYE-WARN', e)


def d_render(fname):
    sc2.render.filepath = os.path.join(DRON_OUT, fname)
    bpy.ops.render.render(write_still=True)
    print('DRONE', fname)


def d_reset():
    droot.rotation_euler = (0, 0, 0)
    droot.scale = (1, 1, 1)
    set_eye(EYE_CYAN)


for dname, deg in DIRS:
    d_reset()
    droot.rotation_euler[2] = math.radians(deg)
    d_render('drone_patrol_%s.png' % dname)
for dname, deg in DIRS:
    d_reset()
    set_eye(EYE_RED)
    droot.rotation_euler[2] = math.radians(deg)
    droot.scale = (0.94, 1.06, 1.0)
    d_render('drone_chase_%s_f0.png' % dname)
    droot.scale = (1.06, 0.94, 1.0)
    d_render('drone_chase_%s_f1.png' % dname)
for dname, deg in DIRS:
    d_reset()
    set_eye(EYE_AMBER)
    droot.rotation_euler[2] = math.radians(deg)
    d_render('drone_alert_%s.png' % dname)
d_reset()
set_eye(EYE_AMBER)
d_render('drone_investigate_f0.png')
droot.rotation_euler[2] = math.radians(35.0)
d_render('drone_investigate_f1.png')
d_reset()
set_eye(EYE_DIM)
droot.scale = (1.0, 1.0, 0.7)
d_render('drone_stunned.png')
d_reset()
droot.rotation_euler[2] = math.radians(180.0)
droot.scale = (1.0, 1.0, 0.45)
set_eye(EYE_DIM)
d_render('drone_dormant.png')
d_reset()
set_eye(EYE_RED)
droot.scale = (0.9, 1.15, 1.0)
d_render('drone_capture.png')

print('TECHDRONE DONE')
