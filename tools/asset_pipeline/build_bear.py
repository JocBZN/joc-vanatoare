"""Articulated rig and five in-place actions for STKRudy85's CC0 bear mesh.
Source supplied the mesh, not these animations. Run with Blender 4.5 background.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'work/animal_sources'
WORK.mkdir(parents=True, exist_ok=True)
OUT = ROOT / 'assets/animals/stylized/bear.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/animals/forest/bear.glb'))
mesh = max((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
mesh.name = 'BearMesh'
mesh.animation_data_clear()
mesh.parent = None
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
for modifier in list(mesh.modifiers):
    mesh.modifiers.remove(modifier)
mesh.vertex_groups.clear()
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for obj in list(bpy.context.scene.objects):
    if obj != mesh:
        bpy.data.objects.remove(obj, do_unlink=True)
floor = min(vertex.co.z for vertex in mesh.data.vertices)
for vertex in mesh.data.vertices:
    vertex.co.z -= floor
    if vertex.co.y > 1.50 and vertex.co.z > .80:
        vertex.co.x *= 1.05

# Weld duplicated face boundaries and repair their normals before skinning.
# A small tolerance preserves the genuine source silhouette and its facial detail.
topology = bmesh.new()
topology.from_mesh(mesh.data)
bmesh.ops.remove_doubles(topology, verts=list(topology.verts), dist=.002)
boundaries = [edge for edge in topology.edges if edge.is_boundary]
if boundaries:
    bmesh.ops.holes_fill(topology, edges=boundaries, sides=0)
bmesh.ops.recalc_face_normals(topology, faces=list(topology.faces))
topology.to_mesh(mesh.data)
topology.free()
mesh.data.validate(clean_customdata=True)
mesh.data.update()
smooth_surface = mesh.modifiers.new('SoftStylizedForms', 'SMOOTH')
smooth_surface.factor = .12
smooth_surface.iterations = 1
bpy.ops.object.modifier_apply(modifier=smooth_surface.name)
for polygon in mesh.data.polygons:
    polygon.use_smooth = True

# The legacy atlas repeats tiny face images across the mesh. Give the bear a clean
# authored fur palette, dark snout, claws and actual eye geometry instead.
def painted_material(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    node = material.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = .88
    return material

palette = [
    painted_material('BearFur', (.28, .15, .075)),
    painted_material('BearFurShade', (.23, .12, .060)),
    painted_material('BearFurHighlight', (.34, .20, .105)),
    painted_material('BearMuzzle', (.16, .084, .044)),
    painted_material('BearNose', (.018, .014, .012)),
    painted_material('BearClaws', (.40, .35, .24)),
    painted_material('BearEyes', (.008, .007, .005)),
]
mesh.data.materials.clear()
for material in palette:
    mesh.data.materials.append(material)
for polygon in mesh.data.polygons:
    center = sum((mesh.data.vertices[i].co for i in polygon.vertices), Vector()) / len(polygon.vertices)
    x, y, z = center
    index = 1 if z < 1.0 else 2 if z > 1.92 else 0
    if y > 2.02 and .76 < z < 1.42:
        index = 3
    if y > 2.26 and .86 < z < 1.35:
        index = 4
    if z < .145 and ((y > 1.40) or (-.69 < y < -.48)):
        index = 5
    polygon.material_index = index
eyes = []
for side in [-1, 1]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.055, location=(side * .416, 1.86, 1.435))
    eye = bpy.context.object
    eye.name = 'BearEye'
    eye.scale = (.62, .85, 1)
    eye.data.materials.append(palette[6])
    eyes.append(eye)
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
for eye in eyes:
    eye.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.join()
mesh.data.validate(clean_customdata=True)
mesh.data.update()
data = bpy.data.armatures.new('BearSkeleton')
rig = bpy.data.objects.new('BearRig', data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
mesh.select_set(False)
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
specs = {
    'Root': ((0, 0, 1.10), (0, 0, 1.40), None),
    'Pelvis': ((0, -.85, 1.32), (0, -.25, 1.47), 'Root'),
    'Spine': ((0, -.25, 1.47), (0, .52, 1.65), 'Pelvis'),
    'Chest': ((0, .52, 1.65), (0, 1.04, 1.49), 'Spine'),
    'Neck': ((0, 1.04, 1.49), (0, 1.57, 1.31), 'Chest'),
    'Head': ((0, 1.57, 1.31), (0, 2.15, 1.17), 'Neck'),
    'Jaw': ((0, 1.78, 1.15), (0, 2.26, 1.03), 'Head'),
    'Tail': ((0, -1.30, 1.34), (0, -1.53, 1.40), 'Pelvis'),
    'Ear.L': ((.31, 1.56, 1.58), (.37, 1.62, 1.78), 'Head'),
    'Ear.R': ((-.31, 1.56, 1.58), (-.37, 1.62, 1.78), 'Head'),
}
legs = {}
for side, x in [('L', .46), ('R', -.46)]:
    for name, parent, hip, knee, ankle, toe in [
        ('Front', 'Chest', (x, .95, 1.42), (x, .79, .74), (x, 1.10, .20), (x, 1.38, .10)),
        ('Rear', 'Pelvis', (x, -.91, 1.40), (x, -.55, .77), (x, -.97, .20), (x, -.71, .10)),
    ]:
        upper, lower, paw, tip = [f'{name}{part}.{side}' for part in ['Upper', 'Lower', 'Paw', 'Toe']]
        specs[upper] = (hip, knee, parent)
        specs[lower] = (knee, ankle, upper)
        specs[paw] = (ankle, toe, lower)
        specs[tip] = (toe, (x, toe[1] + .12, .08), paw)
        legs[f'{name}.{side}'] = dict(upper=upper, lower=lower, paw=paw, toe=tip, hip=Vector(hip), ankle=Vector(ankle), parent=parent, bend=-1 if name == 'Front' else 1)
for name, (head, tail, parent) in specs.items():
    bone = data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    bone.use_deform = name != 'Root'
    if parent:
        bone.parent = data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')

def clamp(value, low=0., high=1.):
    return max(low, min(high, value))

def smooth(low, high, value):
    t = clamp((value - low) / (high - low))
    return t * t * (3 - 2 * t)

def segment_distance(point, a, b):
    delta = b - a
    return (point - (a + delta * clamp((point - a).dot(delta) / delta.length_squared))).length

def normalized(weights):
    total = sum(weights.values())
    return {name: weight / total for name, weight in weights.items() if weight / total > .012}

groups = {name: mesh.vertex_groups.new(name=name) for name in specs if name != 'Root'}
for vertex in mesh.data.vertices:
    p = vertex.co
    x, y, z = p
    centers = {'Pelvis': -.94, 'Spine': -.13, 'Chest': .60, 'Neck': 1.22, 'Head': 1.92}
    weights = normalized({name: math.exp(-((y - center) / (.43 if name in ['Head', 'Neck'] else .65)) ** 2 * 2) for name, center in centers.items()})
    head_weight = smooth(1.28, 1.65, y) * smooth(.67, .95, z)
    if head_weight > .01:
        weights = {name: w * (1 - head_weight) for name, w in weights.items()}
        weights['Head'] = weights.get('Head', 0) + head_weight
    if y > 1.73 and .76 < z < 1.20:
        jaw = smooth(1.75, 2.08, y) * (1 - smooth(1.07, 1.21, z)) * .74
        weights = {name: w * (1 - jaw) for name, w in weights.items()}
        weights['Jaw'] = jaw
    if 1.35 < y < 1.86 and z > 1.61 and abs(x) > .23:
        ear = smooth(1.61, 1.75, z) * .84
        weights = {name: w * (1 - ear) for name, w in weights.items()}
        weights['Ear.L' if x > 0 else 'Ear.R'] = ear
    leg_name = 'Front' if y > .31 else 'Rear'
    leg = legs[f'{leg_name}.{"L" if x >= 0 else "R"}']
    mask = (1 - smooth(.87, 1.42, z)) * smooth(.16, .35, abs(x))
    mask *= 1 - smooth(1.45, 1.67, y) if leg_name == 'Front' else 1 - smooth(-.18, .19, y)
    if mask > .01:
        limb = {}
        for name in [leg['upper'], leg['lower'], leg['paw']]:
            a, b, _ = specs[name]
            limb[name] = 1 / (segment_distance(p, Vector(a), Vector(b)) + .095) ** 4
        limb = normalized(limb)
        if z < .22:
            paw = 1 - smooth(.10, .23, z)
            limb = {name: w * (1 - paw) for name, w in limb.items()}
            limb[leg['paw']] = limb.get(leg['paw'], 0) + paw
        weights = {name: w * (1 - mask) for name, w in weights.items()}
        for name, weight in limb.items():
            weights[name] = weights.get(name, 0) + weight * mask
    weights = normalized(dict(sorted(weights.items(), key=lambda item: item[1], reverse=True)[:4]))
    for name, weight in weights.items():
        groups[name].add([vertex.index], weight, 'REPLACE')
modifier = mesh.modifiers.new('ArticulatedBearSkin', 'ARMATURE')
modifier.object = rig
mesh.parent = rig
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
scene = bpy.context.scene
scene.render.fps = 30

def rotate(name, axis, angle):
    rig.pose.bones[name].rotation_quaternion = Quaternion(axis, angle)

def reset_pose():
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)

def segment(name, head, tail):
    rest = data.bones[name]
    rotation = (rest.tail_local - rest.head_local).rotation_difference(tail - head).to_matrix()
    transform = (rotation @ rest.matrix_local.to_3x3()).to_4x4()
    transform.translation = head
    rig.pose.bones[name].matrix = transform
    bpy.context.view_layer.update()

def leg_pose(info, target, paw_pitch=0):
    parent = rig.pose.bones[info['parent']]
    hip = parent.matrix @ parent.bone.matrix_local.inverted() @ info['hip']
    a, b = data.bones[info['upper']].length, data.bones[info['lower']].length
    delta = target - hip
    distance = clamp(delta.length, abs(a - b) + .005, a + b - .006)
    direction = delta.normalized()
    target = hip + direction * distance
    projection = (a * a - b * b + distance * distance) / (2 * distance)
    height = math.sqrt(max(.0001, a * a - projection * projection))
    normal = Vector((0, -direction.z, direction.y)).normalized() * info['bend']
    knee = hip + direction * projection + normal * height
    segment(info['upper'], hip, knee)
    segment(info['lower'], knee, target)
    transform = data.bones[info['paw']].matrix_local.copy()
    if paw_pitch:
        transform = Matrix.Rotation(paw_pitch, 4, 'X') @ transform
    transform.translation = target
    rig.pose.bones[info['paw']].matrix = transform
    bpy.context.view_layer.update()

def root_pose(offset=Vector((0, 0, 0)), roll=0, pitch=0):
    rest = data.bones['Root'].matrix_local
    transform = Matrix.Rotation(roll, 4, 'Y') @ Matrix.Rotation(pitch, 4, 'X') @ rest
    transform.translation = rest.translation + offset
    rig.pose.bones['Root'].matrix = transform
    bpy.context.view_layer.update()

actions = {}
settings = [('Idle', 3.0, True), ('Walk', 1.20, True), ('Run', .80, True), ('Attack', 1.20, False), ('Die', 1.50, False)]
for clip, duration, loop in settings:
    action = bpy.data.actions.new(clip)
    rig.animation_data_create()
    rig.animation_data.action = action
    frames = round(duration * 30)
    for frame in range(frames + 1):
        scene.frame_set(frame)
        t = frame / frames
        reset_pose()
        if clip == 'Idle':
            breath = math.sin(t * math.tau)
            root_pose(Vector((0, 0, breath * .006)))
            rig.pose.bones['Chest'].scale = (1 + breath * .009, 1, 1 + breath * .008)
            rotate('Neck', (1, 0, 0), breath * .016)
            rotate('Head', (0, 1, 0), breath * .017)
            for info in legs.values():
                leg_pose(info, info['ankle'].copy())
        elif clip in ['Walk', 'Run']:
            running = clip == 'Run'
            root_pose(Vector((0, 0, math.cos(t * math.tau * 2) * (.042 if running else .018))), math.sin(t * math.tau) * (.018 if running else .012), math.sin(t * math.tau * 2) * (.040 if running else .013))
            rotate('Pelvis', (0, 1, 0), math.sin(t * math.tau) * .022)
            rotate('Spine', (0, 1, 0), -math.sin(t * math.tau) * .020)
            rotate('Neck', (1, 0, 0), math.sin(t * math.tau * 2) * (.05 if running else .018))
            rotate('Head', (1, 0, 0), -math.sin(t * math.tau * 2) * .018)
            bpy.context.view_layer.update()
            phases = {'Rear.L': .0, 'Front.L': .25, 'Rear.R': .5, 'Front.R': .75} if not running else {'Rear.L': .0, 'Rear.R': .08, 'Front.L': .52, 'Front.R': .60}
            stance, stride = (.64, .38) if not running else (.46, .68)
            for key, info in legs.items():
                phase = (t + phases[key]) % 1
                if phase < stance:
                    travel, lift, pitch = stride * (.5 - phase / stance), 0, 0
                else:
                    swing = (phase - stance) / (1 - stance)
                    ease = swing * swing * (3 - 2 * swing)
                    travel = stride * (-.5 + ease)
                    lift = math.sin(swing * math.pi) * (.12 if not running else .22)
                    pitch = math.sin(swing * math.tau) * (.12 if not running else .24)
                leg_pose(info, info['ankle'] + Vector((0, travel, lift)), pitch)
        elif clip == 'Attack':
            anticipation = math.sin(math.pi * clamp(t / .32)) if t < .32 else 0
            strike = math.sin(math.pi * clamp((t - .24) / .55)) if .24 < t < .79 else 0
            root_pose(Vector((0, -.07 * anticipation + .22 * strike, -.025 * anticipation - .045 * strike)), 0, .018 * anticipation - .065 * strike)
            rotate('Neck', (1, 0, 0), .10 * anticipation - .18 * strike)
            rotate('Head', (1, 0, 0), -.10 * strike)
            rotate('Jaw', (1, 0, 0), -.26 * strike)
            bpy.context.view_layer.update()
            for key, info in legs.items():
                target = info['ankle'].copy()
                if key == 'Front.L':
                    lift = math.sin(math.pi * clamp((t - .10) / .72)) if .10 < t < .82 else 0
                    target += Vector((.035 * lift, .45 * strike, .62 * lift))
                leg_pose(info, target, .12 * strike if key == 'Front.L' else 0)
        else:
            fall = smooth(.12, .80, t)
            root_pose(Vector((.44 * fall, -.06 * fall, -.29 * fall)), 1.37 * fall, -.11 * fall)
            rotate('Neck', (1, 0, 0), .16 * fall)
            rotate('Head', (0, 1, 0), -.13 * fall)
            for key, info in legs.items():
                rotate(info['upper'], (1, 0, 0), (.24 if key.startswith('Front') else -.30) * fall)
                rotate(info['lower'], (1, 0, 0), -.34 * fall)
                rotate(info['paw'], (1, 0, 0), .15 * fall)
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='location', frame=frame, group=bone.name)
            bone.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=bone.name)
            bone.keyframe_insert(data_path='scale', frame=frame, group=bone.name)
    action.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = clip
    strip = track.strips.new(clip, 0, action)
    strip.action_frame_start, strip.action_frame_end = 0, frames
    strip.frame_start, strip.frame_end = 0, frames
    actions[clip] = action
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
reset_pose()
scene.frame_set(0)
bpy.context.view_layer.update()
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_frame_range=False, export_anim_slide_to_zero=True, export_skins=True, export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK / 'bear_articulated.blend'))
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = 'BOTH'
scene.display.shading.background_type = 'WORLD'
scene.world.color = (.16, .21, .24)
scene.render.resolution_x, scene.render.resolution_y = 960, 720
scene.render.resolution_percentage = 100
camera_data = bpy.data.cameras.new('QACamera')
camera = bpy.data.objects.new('QACamera', camera_data)
scene.collection.objects.link(camera)
camera.location = Vector((6, .25, 2.9))
camera.rotation_euler = (Vector((0, .4, 1.05)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type, camera_data.ortho_scale = 'ORTHO', 5.5
scene.camera = camera
for track in rig.animation_data.nla_tracks:
    track.mute = True
for clip, frame in [('Idle', 0), ('Walk', 9), ('Run', 5), ('Attack', 14), ('Die', 43)]:
    rig.animation_data.action = actions[clip]
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    scene.render.filepath = str(WORK / f'bear_qa_{clip.lower()}.png')
    bpy.ops.render.render(write_still=True)
summary = {'source': 'assets/animals/forest/bear.glb', 'output': 'assets/animals/stylized/bear.glb', 'vertices': len(mesh.data.vertices), 'bones': len(data.bones), 'clips': [{'name': name, 'duration_seconds': duration, 'loop': loop} for name, duration, loop in settings], 'authorship': 'Source mesh by STKRudy85 (CC0). Articulated rig, skin weights and all five in-place clips authored for this game.'}
(WORK / 'bear_rig_manifest.json').write_text(json.dumps(summary, indent=2))
print('BEAR_BUILD_OK', json.dumps(summary))
