"""Inspect binary glTF skin/clip data and preserve precise source receipts."""
import hashlib, json, struct
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT / 'work/animal_sources'
ASSETS = PROJECT / 'assets/animals/stylized'
SOURCES = {
    'frog': {'author': 'methodical pixel', 'page': 'https://opengameart.org/content/frog-low-poly-animated-3d-model', 'download': 'https://opengameart.org/sites/default/files/frog.tar_0.gz', 'package': ROOT / 'frog.tar.gz', 'blend': ROOT / 'frog/frog/frog.blend'},
    'snake': {'author': 'methodical pixel', 'page': 'https://opengameart.org/content/snake-low-poly-animated-3d-model', 'download': 'https://opengameart.org/sites/default/files/snake.tar.gz', 'package': ROOT / 'snake.tar.gz', 'blend': ROOT / 'snake/snake/snake.blend'},
    'turtle': {'author': 'Heathal', 'page': 'https://opengameart.org/content/turtle-0', 'download': 'https://opengameart.org/sites/default/files/Turtle.blend', 'package': ROOT / 'Turtle.blend', 'blend': ROOT / 'Turtle.blend', 'texture_download': 'https://opengameart.org/sites/default/files/turtle%20texture.png'},
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

receipts, inspection = {}, {}
for species, source in SOURCES.items():
    path = ASSETS / (species + '.glb')
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    size, kind = struct.unpack_from('<II', raw, 12)
    doc = json.loads(raw[20:20 + size])
    binary_size, binary_kind = struct.unpack_from('<II', raw, 20 + size)
    binary = raw[28 + size:28 + size + binary_size]
    joints = {index for skin in doc.get('skins', []) for index in skin['joints']}
    assert joints, species + ' must have a skin'
    skinned_meshes = [node for node in doc['nodes'] if 'mesh' in node and 'skin' in node]
    assert skinned_meshes, species + ' must have a skinned mesh'
    clips = {}
    for animation in doc.get('animations', []):
        changing = []
        for channel in animation['channels']:
            if channel['target']['node'] not in joints:
                continue
            sampler = animation['samplers'][channel['sampler']]
            accessor = doc['accessors'][sampler['output']]
            components = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
            view = doc['bufferViews'][accessor['bufferView']]
            offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            stride = view.get('byteStride', components * 4)
            values = [struct.unpack_from('<' + 'f' * components, binary, offset + i * stride) for i in range(accessor['count'])]
            variation = max(max(v[c] for v in values) - min(v[c] for v in values) for c in range(components))
            if variation > .00001:
                changing.append({'bone': doc['nodes'][channel['target']['node']].get('name', ''), 'path': channel['target']['path'], 'variation': round(variation, 5)})
        clips[animation['name']] = changing
    assert all(name in clips for name in ['Idle', 'Walk', 'Die']), (species, list(clips))
    assert len(clips['Walk']) >= 3, species + ' needs multiple articulated locomotion channels'
    if species == 'snake':
        assert len(clips.get('Attack', [])) >= 3, 'snake requires articulated attack'
    inspection[species] = {'bytes': len(raw), 'skin_joint_count': len(joints), 'skinned_meshes': len(skinned_meshes), 'clips': {name: {'changing_joint_channels': len(channels), 'details': channels} for name, channels in clips.items()}}
    receipts[species] = {k: v for k, v in source.items() if k not in ('package', 'blend')}
    receipts[species].update({'license': 'CC0 1.0', 'license_url': 'https://creativecommons.org/publicdomain/zero/1.0/', 'retrieved_date': '2026-10-05', 'package_sha256': sha(source['package']), 'blend_sha256': sha(source['blend']), 'glb_sha256': sha(path), 'local_asset': str(path.relative_to(PROJECT)).replace('\\', '/')})
(ROOT / 'swamp_sources_receipt.json').write_text(json.dumps(receipts, indent=2), encoding='utf8')
(ROOT / 'swamp_glb_validation.json').write_text(json.dumps(inspection, indent=2), encoding='utf8')
for species, value in inspection.items():
    print('GLB_OK', species, 'joints=', value['skin_joint_count'], 'clips=', {name: clip['changing_joint_channels'] for name, clip in value['clips'].items()})
print('SWAMP_GLB_VALIDATION_COMPLETE')
