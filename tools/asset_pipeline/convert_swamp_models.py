"""Preserve CC0 meshes/rigs/locomotion; add explicitly authored missing states.

Run with Blender 4.5 in background. Generated state provenance is written beside
the sources. The normalized GLBs use Godot's -Z forward and +Y up convention.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector, Quaternion

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / 'work/animal_sources'
OUTPUT = PROJECT / 'assets/animals/stylized'
OUTPUT.mkdir(parents=True, exist_ok=True)
SOURCES = {
    'frog': ROOT / 'frog/frog/frog.blend',
    'snake': ROOT / 'snake/snake/snake.blend',
    'turtle': ROOT / 'Turtle.blend',
}
TEXTURES = {
    'frog': ROOT / 'frog/frog/frog.png',
    'snake': ROOT / 'snake/snake/snake.png',
    'turtle': ROOT / 'turtle_texture.png',
}
# Width, length, height. The slightly exaggerated small-animal silhouette stays
# inside the existing gameplay collision dimensions without changing balance.
TARGET_SIZE = {'frog': (.50, .52, .35), 'snake': (.45, 2.0, .16), 'turtle': (.60, .85, .42)}
report = {}

def assign_action(armature, action):
    armature.animation_data_create()
    armature.animation_data.action = action

def clear_pose(armature):
    for bone in armature.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)

def pose_copy(armature):
    return {bone.name: bone.matrix_basis.copy() for bone in armature.pose.bones}

def restore_pose(armature, pose):
    for bone in armature.pose.bones:
        bone.matrix_basis = pose[bone.name]

def key_pose(armature, frame):
    for bone in armature.pose.bones:
        bone.keyframe_insert('location', frame=frame, group=bone.name)
        bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
        bone.keyframe_insert('scale', frame=frame, group=bone.name)

def authored_action(armature, name, pose, frames, transform):
    assign_action(armature, None)
    for frame in frames:
        restore_pose(armature, pose)
        transform(frame, (frame - frames[0]) / max(1, frames[-1] - frames[0]))
        key_pose(armature, frame)
    action = armature.animation_data.action
    action.name = name
    action.use_fake_user = True
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = 'LINEAR'
    return action

def mesh_bounds(objects):
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        if obj.type != 'MESH':
            continue
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    return Vector(tuple(min(p[i] for p in points) for i in range(3))), Vector(tuple(max(p[i] for p in points) for i in range(3)))

for species, source_path in SOURCES.items():
    bpy.ops.wm.open_mainfile(filepath=str(source_path))
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.render.fps_base = 1.0
    arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
    original = {action.name: action for action in bpy.data.actions}
    coverage = {}
    if species == 'frog':
        retained = {'idle': 'Idle', 'walk': 'Walk', 'jump': 'Jump', 'land': 'Land'}
    elif species == 'snake':
        retained = {'idle': 'Idle', 'walk': 'Walk'}
    else:
        retained = {'Walking-loop': 'Walk'}
    # The source files also attach armature actions to the mesh objects; those
    # redundant object channels must not create duplicate animations in glTF.
    for mesh in meshes:
        mesh.animation_data_clear()
    arm.animation_data_create()
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    source_modes = {bone.name: bone.rotation_mode for bone in arm.pose.bones}
    baked_source_poses = {}
    # Snake's original channels use Euler rotation. Sample before changing modes;
    # otherwise switching that rig to quaternion for supplemental actions would
    # silently disable its original slither. Bake every source action uniformly.
    for name, canonical in retained.items():
        for bone in arm.pose.bones:
            bone.rotation_mode = source_modes[bone.name]
            bone.location = (0, 0, 0)
            bone.rotation_euler = (0, 0, 0)
            bone.rotation_quaternion = (1, 0, 0, 0)
            bone.scale = (1, 1, 1)
        source_action = original[name]
        assign_action(arm, source_action)
        frames = range(int(source_action.frame_range[0]), int(source_action.frame_range[1]) + 1)
        poses = []
        for frame in frames:
            scene.frame_set(frame)
            poses.append((frame, pose_copy(arm)))
        baked_source_poses[canonical] = poses
        coverage[canonical] = {'origin': 'source', 'source_action': name, 'source_frames': list(source_action.frame_range)}
    assign_action(arm, None)
    for name, action in original.items():
        bpy.data.actions.remove(action)
    for canonical, poses in baked_source_poses.items():
        clear_pose(arm)
        assign_action(arm, None)
        for frame, pose in poses:
            restore_pose(arm, pose)
            key_pose(arm, frame)
        action = arm.animation_data.action
        action.name = canonical
        action.use_fake_user = True
    actions = {action.name: action for action in bpy.data.actions}
    base_action = actions.get('Idle', actions['Walk'])
    clear_pose(arm)
    assign_action(arm, base_action)
    scene.frame_set(int(base_action.frame_range[0]))
    base_pose = pose_copy(arm)
    if species == 'frog':
        # The author supplied take-off and landing separately. Run concatenates
        # both original poses so movement is a complete amphibian hop cycle.
        samples = []
        for source_action in (actions['Jump'], actions['Land']):
            assign_action(arm, source_action)
            for frame in range(int(source_action.frame_range[0]), int(source_action.frame_range[1]) + 1):
                scene.frame_set(frame)
                samples.append(pose_copy(arm))
        assign_action(arm, None)
        for frame, pose in enumerate(samples, 1):
            restore_pose(arm, pose)
            key_pose(arm, frame)
        run = arm.animation_data.action
        run.name = 'Run'
        run.use_fake_user = True
        coverage['Run'] = {'origin': 'source_concatenation', 'source_actions': ['jump', 'land']}
        def frog_die(frame, t):
            settle = min(1.0, t * 1.4)
            arm.pose.bones['body'].location.z -= .065 * settle
            for bone in arm.pose.bones:
                if bone.name.startswith('leg_top'):
                    bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion((1, 0, 0), .20 * settle)
                elif bone.name.startswith('leg_bottom'):
                    bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion((1, 0, 0), -.24 * settle)
                elif bone.name.startswith('eye'):
                    bone.scale.z *= 1 - .15 * settle
        authored_action(arm, 'Die', base_pose, list(range(1, 25)), frog_die)
        coverage['Die'] = {'origin': 'authored', 'description': 'Body settles, rear/front limbs relax, eyes narrow; source skin and rig.'}
    elif species == 'snake':
        def snake_attack(frame, t):
            pulse = max(0.0, math.sin(t * math.pi))
            head = arm.pose.bones['head']
            head.location.y += .12 * pulse
            head.location.z += .06 * pulse
            head.rotation_quaternion = head.rotation_quaternion @ Quaternion((1, 0, 0), -.20 * pulse)
            body = arm.pose.bones['body']
            body.location.z -= .04 * pulse
            body.rotation_quaternion = body.rotation_quaternion @ Quaternion((1, 0, 0), .20 * pulse)
            for i in range(1, 5):
                bone = arm.pose.bones['body' + str(i)]
                bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion((0, 0, 1), math.sin(t * math.pi * 2 + i * .7) * .05 * pulse)
        authored_action(arm, 'Attack', base_pose, list(range(1, 17)), snake_attack)
        coverage['Attack'] = {'origin': 'authored', 'description': 'Short head lift/lunge with counter-motion through anterior vertebrae.'}
        def snake_die(frame, t):
            settle = min(1.0, t * 1.5)
            for bone in arm.pose.bones:
                if bone.name.startswith('body'):
                    index = 0 if bone.name == 'body' else int(bone.name[4:])
                    bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion((0, 0, 1), math.sin(index * .5) * .06 * settle)
            arm.pose.bones['head'].rotation_quaternion = arm.pose.bones['head'].rotation_quaternion @ Quaternion((1, 0, 0), .08 * settle)
        authored_action(arm, 'Die', base_pose, list(range(1, 25)), snake_die)
        coverage['Die'] = {'origin': 'authored', 'description': 'Vertebral chain settles into a motionless shallow coil.'}
    else:
        def turtle_idle(frame, t):
            breath = math.sin(t * math.pi * 2)
            arm.pose.bones['Bone'].scale.z *= 1 + .009 * breath
            arm.pose.bones['Bone.016'].rotation_quaternion = arm.pose.bones['Bone.016'].rotation_quaternion @ Quaternion((1, 0, 0), .025 * breath)
            arm.pose.bones['Bone.018'].rotation_quaternion = arm.pose.bones['Bone.018'].rotation_quaternion @ Quaternion((0, 0, 1), .035 * breath)
        authored_action(arm, 'Idle', base_pose, list(range(1, 73, 3)) + [73], turtle_idle)
        coverage['Idle'] = {'origin': 'authored', 'description': 'Subtle breathing and small neck/head look motion, legs planted.'}
        def turtle_die(frame, t):
            settle = min(1.0, t * 1.3)
            # Connected turtle neck bones ignore pose translation in Blender.
            # Fold the cervical joints instead so the exported skin really moves.
            for name, angle in (('Bone.015', -.35), ('Bone.016', -.30), ('Bone.017', -.25), ('Bone.018', .50)):
                bone = arm.pose.bones[name]
                bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion((1, 0, 0), angle * settle)
            for name in ('Bone.001', 'Bone.002', 'Bone.003', 'Bone.004'):
                bone = arm.pose.bones[name]
                bone.rotation_quaternion = bone.rotation_quaternion @ Quaternion((0, 0, 1), .14 * settle)
        authored_action(arm, 'Die', base_pose, list(range(1, 31)), turtle_die)
        coverage['Die'] = {'origin': 'authored', 'description': 'Cervical joints fold the head toward shell; limbs tuck as motion stops.'}
    # Rebuild the pre-2.8 material as a normal glTF-compatible image material.
    image = bpy.data.images.load(str(TEXTURES[species]), check_existing=True)
    image.pack()
    for mesh in meshes:
        for material in mesh.data.materials:
            if material is None:
                continue
            material.use_nodes = True
            nodes = material.node_tree.nodes
            nodes.clear()
            output = nodes.new('ShaderNodeOutputMaterial')
            shader = nodes.new('ShaderNodeBsdfPrincipled')
            texture = nodes.new('ShaderNodeTexImage')
            texture.image = image
            texture.interpolation = 'Linear'
            shader.inputs['Roughness'].default_value = .86
            shader.inputs['Metallic'].default_value = 0.0
            material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
            material.node_tree.links.new(shader.outputs['BSDF'], output.inputs['Surface'])
        # Smoother normals retain the author's silhouette and vertex skin weights.
        for polygon in mesh.data.polygons:
            polygon.use_smooth = True
    idle = bpy.data.actions.get('Idle', bpy.data.actions['Walk'])
    assign_action(arm, idle)
    scene.frame_set(int(idle.frame_range[0]))
    low, high = mesh_bounds(meshes)
    dims = high - low
    target = TARGET_SIZE[species]
    scale = Vector((target[0] / dims.x, target[1] / dims.y, target[2] / dims.z))
    center = Vector(((low.x + high.x) * .5, (low.y + high.y) * .5, low.z))
    # All three source animals face Blender -Y. Flip around Z before glTF's
    # axis conversion, resulting in Godot -Z rather than +Z.
    normalization = Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Diagonal((*scale, 1)) @ Matrix.Translation(-center)
    root = bpy.data.objects.new(species.title(), None)
    scene.collection.objects.link(root)
    for obj in [arm] + [mesh for mesh in meshes if mesh.parent is None]:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
    root.matrix_world = normalization
    # The frog/snake authors hid their rigs in the viewport. A hidden object
    # cannot be selected, so selection export would otherwise strip the skin.
    for obj in [root, arm] + meshes:
        obj.hide_viewport = False
        obj.hide_render = False
        obj.hide_set(False)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    arm.select_set(True)
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (species + '.glb')), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
        export_bake_animation=True, export_anim_single_armature=True, export_materials='EXPORT',
        export_skins=True, export_yup=True, export_apply=False)
    report[species] = {
        'source': str(source_path.relative_to(PROJECT)), 'source_texture': str(TEXTURES[species].relative_to(PROJECT)),
        'license': 'CC0', 'bones': len(arm.data.bones),
        'mesh_vertices': sum(len(mesh.data.vertices) for mesh in meshes),
        'source_bounds': {'min': list(low), 'max': list(high)},
        'normalized_size': {'width': target[0], 'length': target[1], 'height': target[2]},
        'clips': coverage,
    }
    print('CONVERTED', species, len(arm.data.bones), [a.name for a in bpy.data.actions])
    if '--no-preview' in sys.argv:
        continue
    # Render a compact isolated species preview for visual inspection.
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = 720
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new('PreviewWorld')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.13, .18, .20, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .8
    camera_data = bpy.data.cameras.new('PreviewCamera')
    camera = bpy.data.objects.new('PreviewCamera', camera_data)
    scene.collection.objects.link(camera)
    distance = max(target[1], target[0]) * 1.65
    look = Vector((0, 0, target[2] * .4))
    camera.location = look + Vector((distance * .85, distance, distance * .65))
    camera.rotation_euler = (look - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = max(target) * 1.35
    scene.camera = camera
    light_data = bpy.data.lights.new('Key', 'AREA')
    light = bpy.data.objects.new('Key', light_data)
    scene.collection.objects.link(light)
    light.location = (1.5, 1.5, 3)
    light.rotation_euler = (look - light.location).to_track_quat('-Z', 'Y').to_euler()
    light_data.energy = 320
    light_data.size = 3
    scene.render.filepath = str(ROOT / (species + '_preview.png'))
    bpy.ops.render.render(write_still=True)
(ROOT / 'swamp_conversion_report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print('SWAMP_CONVERSION_COMPLETE')
