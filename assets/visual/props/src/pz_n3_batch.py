"""PROTOCOL:ZERO N3+N5 — lote props + escaleras (top-down, alfa).
Uso: blender.exe --background --python pz_n3_batch.py
Sale: barrier_h/v, shelf_h, bench_top, stairs_steps, rail_v + .blend c/u.
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


def metal(name, base, metallic=0.7, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*base, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return m


STEEL = metal('Steel', (0.10, 0.11, 0.14))
DARK = metal('Dark', (0.05, 0.055, 0.07), 0.5, 0.6)
PANEL = metal('Panel', (0.09, 0.10, 0.13), 0.75, 0.4)
YELLOW = metal('Yellow', (0.65, 0.47, 0.07), 0.2, 0.5)
BLACK = metal('Black', (0.03, 0.03, 0.04), 0.1, 0.7)
BOXM = metal('Box', (0.20, 0.16, 0.10), 0.3, 0.6)
BOLT = metal('Bolt', (0.22, 0.23, 0.26), 0.9, 0.35)
AMBER = metal('Amber', (0.60, 0.42, 0.08), 0.2, 0.5)
SHADES = [metal('Sh%d' % i, (0.14 - i * 0.022, 0.15 - i * 0.022, 0.17 - i * 0.022)) for i in range(6)]


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


def cam(w, h):
    for o in [o for o in bpy.context.scene.objects if o.type in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)
    cd = bpy.data.cameras.new('TopOrtho')
    cd.type = 'ORTHO'
    cd.ortho_scale = max(w, h) * 1.02
    c = bpy.data.objects.new('TopOrtho', cd)
    bpy.context.scene.collection.objects.link(c)
    c.location = (0, 0, 10)
    sc = bpy.context.scene
    sc.camera = c
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.film_transparent = True
    sc.render.resolution_x = int(w * 100)
    sc.render.resolution_y = int(h * 100)
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    bpy.ops.object.light_add(type='SUN', location=(3, -2, 8))
    bpy.context.active_object.data.energy = 1.2
    bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6))
    bpy.context.active_object.data.energy = 80.0
    bpy.context.active_object.data.size = 6.0


def clear():
    for o in [o for o in bpy.context.scene.objects if o.type not in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)


def done(blend, png):
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, png)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, blend))
    bpy.ops.render.render(write_still=True)
    print('RENDERED', png)


def bolts(xs, ys, z=0.20, r=0.04):
    for x in xs:
        for y in ys:
            bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=0.05, location=(x, y, z))
            bpy.context.active_object.data.materials.append(BOLT)


# ---- barrier_h 5.6 x 1.6 ----
cam(5.6, 1.6)
box('Frame', (0, 0, 0.08), (5.6, 1.6, 0.16), STEEL)
box('Panel', (0, 0, 0.12), (4.4, 1.1, 0.18), PANEL, bevel=0.01)
for i in range(4):
    box('Hz%d' % i, (-2.45 + i * 0.22, 0, 0.13), (0.11, 1.1, 0.18), YELLOW if i % 2 == 0 else BLACK, bevel=0.005)
    box('HzE%d' % i, (2.45 - i * 0.22, 0, 0.13), (0.11, 1.1, 0.18), YELLOW if i % 2 == 0 else BLACK, bevel=0.005)
bolts((-2.65, 2.65), (-0.65, 0.65))
done('barrier_h.blend', 'barrier_h.png')
clear()

# ---- barrier_v 1.6 x 5.6 ----
cam(1.6, 5.6)
box('Frame', (0, 0, 0.08), (1.6, 5.6, 0.16), STEEL)
box('Panel', (0, 0, 0.12), (1.1, 4.4, 0.18), PANEL, bevel=0.01)
for i in range(4):
    box('Hz%d' % i, (0, -2.45 + i * 0.22, 0.13), (1.1, 0.11, 0.18), YELLOW if i % 2 == 0 else BLACK, bevel=0.005)
    box('HzE%d' % i, (0, 2.45 - i * 0.22, 0.13), (1.1, 0.11, 0.18), YELLOW if i % 2 == 0 else BLACK, bevel=0.005)
bolts((-0.65, 0.65), (-2.65, 2.65))
done('barrier_v.blend', 'barrier_v.png')
clear()

# ---- shelf_h 5.6 x 1.6 ----
cam(5.6, 1.6)
box('Frame', (0, 0, 0.08), (5.6, 1.6, 0.16), STEEL)
for i, x in enumerate((-1.8, 0.0, 1.8)):
    box('Bay%d' % i, (x, 0, 0.12), (1.5, 1.1, 0.18), DARK, bevel=0.01)
    box('Goods%d' % i, (x - 0.2 + 0.15 * i, 0, 0.16), (0.7, 0.8, 0.24), BOXM, bevel=0.01)
box('Strip', (0, -0.68, 0.12), (5.2, 0.12, 0.17), AMBER, bevel=0.008)
bolts((-2.65, 2.65), (-0.65, 0.65))
done('shelf_h.blend', 'shelf_h.png')
clear()

# ---- bench_top 4.8 x 1.6 ----
cam(4.8, 1.6)
box('Top', (0, 0, 0.08), (4.8, 1.6, 0.16), PANEL)
box('Vise', (-1.6, 0, 0.14), (0.7, 0.9, 0.24), DARK, bevel=0.01)
box('Mat', (0.3, 0, 0.13), (1.6, 1.0, 0.17), DARK, bevel=0.008)
box('Tool1', (0.0, 0.2, 0.20), (0.9, 0.10, 0.05), STEEL, bevel=0.005)
box('Tool2', (0.4, -0.25, 0.20), (0.6, 0.12, 0.05), BOLT, bevel=0.005)
box('Strip', (0, -0.68, 0.12), (4.4, 0.10, 0.17), AMBER, bevel=0.008)
bolts((-2.25, 2.25), (-0.65, 0.65))
done('bench_top.blend', 'bench_top.png')
clear()

# ---- stairs_steps 4.8 x 4.0 (6 peldanos, oscurecen al norte=profundidad;
# el umbral ambar queda arriba = entrada desde el exterior) ----
cam(4.8, 4.0)
box('Base', (0, 0, 0.02), (4.8, 4.0, 0.08), DARK)
for i in range(6):
    y = 1.55 - i * 0.62
    box('Tread%d' % i, (0, y, 0.10 + (5 - i) * 0.012), (4.4, 0.52, 0.10), SHADES[5 - i], bevel=0.01)
    box('Nose%d' % i, (0, y + 0.24, 0.16 + (5 - i) * 0.012), (4.4, 0.06, 0.10), AMBER if i == 0 else STEEL, bevel=0.005)
done('stairs_steps.blend', 'stairs_steps.png')
clear()

# ---- rail_v 0.64 x 4.0 ----
cam(0.64, 4.0)
box('RailBase', (0, 0, 0.06), (0.64, 4.0, 0.12), STEEL)
box('RailTop', (0, 0, 0.20), (0.30, 4.0, 0.10), PANEL, bevel=0.01)
for i in range(5):
    box('Post%d' % i, (0, -1.6 + i * 0.8, 0.14), (0.44, 0.14, 0.16), DARK, bevel=0.01)
done('rail_v.blend', 'rail_v.png')

print('BLN3 DONE')
