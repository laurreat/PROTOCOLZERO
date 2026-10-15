"""PROTOCOL:ZERO — parche ojo del dron (reutiliza drone8.blend editable).
Uso: blender.exe --background --python pz_drone_fix.py
El ojo quedaba enterrado en el casco; se sube (z) y se adelanta (y) + se
agranda para leerse en cenital. Re-renderiza solo los frames del dron.
"""
import bpy
import os
import math

REPO = r"C:\Users\luis2\Documents\protocol-zero"
DRON_OUT = os.path.join(REPO, "assets", "visual", "enemies", "security_drone")
ESRC = os.path.join(REPO, "assets", "visual", "enemies", "src")
BLEND = os.path.join(ESRC, 'drone8.blend')

bpy.ops.wm.open_mainfile(filepath=BLEND)

droot = bpy.data.objects['DroneRoot']
eye = bpy.data.objects['Eye']
eye.location = (0, 0.58, 0.25)
eye.dimensions = (0.38, 0.18, 0.10)

def ensure_mat(name, base, emission, estr=3.0):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    try:
        bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
        bsdf.inputs['Emission Strength'].default_value = estr
    except Exception as e:
        print('EMAT-WARN', e)
    return m


EYE_CYAN = ensure_mat('EyeCyan', (0.0, 0.45, 0.55), (0.0, 0.85, 1.0), 2.0)
EYE_AMBER = ensure_mat('EyeAmber', (0.55, 0.30, 0.02), (1.0, 0.55, 0.05), 2.0)
EYE_RED = ensure_mat('EyeRed', (0.55, 0.03, 0.03), (1.0, 0.08, 0.08), 2.2)
EYE_DIM = bpy.data.materials.get('EyeDim')
if EYE_DIM is None:
    EYE_DIM = bpy.data.materials.new('EyeDim')
    EYE_DIM.use_nodes = True
    b = next(n for n in EYE_DIM.node_tree.nodes
             if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (0.10, 0.10, 0.12, 1.0)

sc = bpy.context.scene
sc.render.resolution_x = 128
sc.render.resolution_y = 128

DIRS = [
    ('north', 0.0), ('north_west', 45.0), ('west', 90.0),
    ('south_west', 135.0), ('south', 180.0), ('south_east', 225.0),
    ('east', 270.0), ('north_east', 315.0),
]


def set_eye(mat):
    eye.data.materials.clear()
    eye.data.materials.append(mat)


def d_render(fname):
    sc.render.filepath = os.path.join(DRON_OUT, fname)
    bpy.ops.render.render(write_still=True)
    print('DRONE-FIX', fname)


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

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print('DRONE-FIX DONE')
