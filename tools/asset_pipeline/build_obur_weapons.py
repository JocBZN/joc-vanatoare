"""Extract OBUR Games' individual meshes, without the pack's display transforms.

The original user-supplied GLB and CC BY attribution are retained alongside the
derived assets. Only referenced accessors, buffer views and the embedded palette
are copied; the exported meshes/materials themselves remain unchanged.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/weapons/obur"
SOURCE = ASSETS / "source/weapon_pack_of_10100_part_1.glb"
GROUPS = {
    "Baretta_93_R": "baretta_93r",
    "FN_SCAR_L": "fn_scar_l",
    "G36_K": "g36_k",
    "Gerber_LMF": "gerber_lmf",
    "M24_Stick_Grenade": "m24_grenade",
    "Cylinder.016": "rocket",
    "M_72_LAW": "m72_law",
    "MG42": "mg42",
    "Maverick_88": "maverick_88",
    "Tarran_Tactical": "tarran_tactical",
    "UZI": "uzi",
}


def positions(document: dict, binary: bytes, group_name: str) -> list[tuple]:
    group = next(n for n in document["nodes"] if n.get("name") == group_name)
    result = []
    for node_index in group["children"]:
        mesh = document["meshes"][document["nodes"][node_index]["mesh"]]
        for primitive in mesh["primitives"]:
            accessor = document["accessors"][primitive["attributes"]["POSITION"]]
            if accessor["componentType"] != 5126 or accessor["type"] != "VEC3":
                raise ValueError("Expected float positions")
            view = document["bufferViews"][accessor["bufferView"]]
            offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", 12)
            result.extend(struct.unpack_from("<3f", binary, offset + stride * i)
                          for i in range(accessor["count"]))
    return result


def scene_bytes(document: dict, binary: bytes, weapon_id: str, weapon: dict, model: dict) -> bytes:
    group = next(name for name, stem in GROUPS.items() if stem == weapon["model"])
    angle = math.radians(model.get("level_degrees", 0))
    cosine, sine = math.cos(angle), math.sin(angle)

    def canonical(point: list | tuple) -> tuple:
        x, y, z = point
        return -y, -sine * x + cosine * z, -cosine * x - sine * z

    points = [canonical(p) for p in positions(document, binary, group)]
    size = max(p[2] for p in points) - min(p[2] for p in points)
    factor = weapon["length"] / size
    muzzle = canonical(model["muzzle"])
    grip = canonical(model["grip"])
    origin = (0, .05 - muzzle[1] * factor, -grip[2] * factor)

    def fitted(point: list | tuple) -> tuple:
        return tuple(p * factor + o for p, o in zip(canonical(point), origin))

    def numbers(values: list | tuple) -> str:
        return ", ".join(f"{v:.7f}" for v in values)

    root_name = "".join(word.capitalize() for word in weapon_id.split("_"))
    # Positive-determinant change of axes: raw +X barrel, +Z up -> Godot -Z barrel, +Y up.
    # Transform3D's textual constructor takes Basis rows, unlike the three-Vector3 constructor.
    basis = (0, -factor, 0,
             -sine * factor, 0, cosine * factor,
             -cosine * factor, 0, -sine * factor)
    text = ('[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="PackedScene" path="res://assets/weapons/obur/{weapon["model"]}.glb" id="1_model"]\n\n'
            f'[node name="{root_name}" type="Node3D"]\n'
            'metadata/source_author = "OBUR Games"\n'
            f'metadata/source_model = "{group}"\n')
    if "tint" in weapon:
        text += f'metadata/weapon_tint = Color({numbers(weapon["tint"])})\n'
    if "sight" in model:
        text += f'metadata/sight_spacing = {max(.002, min(.01, model.get("sight_spacing", .4) * factor)):.7f}\n'
    text += ('\n[node name="Source" parent="." instance=ExtResource("1_model")]\n'
             f'transform = Transform3D({numbers(basis + origin)})\n')
    for name, point in [("Muzzle", model["muzzle"]), ("Grip", model["grip"]), ("SupportGrip", model["support"])]:
        position = fitted(point)
        if name == "Muzzle":
            position = (position[0], position[1], position[2] - .002)
        text += (f'\n[node name="{name}" type="Marker3D" parent="."]\n'
                 f'position = Vector3({numbers(position)})\n')
    if "sight" in model:
        # The iron heights are measured in the leveled source profile, not the full-model AABB.
        for name, height, x in [("FrontSight", model["sight"], model["front_sight_x"]),
                                ("RearSight", model.get("rear_sight", model["sight"]), model["rear_sight_x"])]:
            point = (0, height * factor + origin[1] + .0015, -x * factor + origin[2])
            text += (f'\n[node name="{name}" type="Marker3D" parent="."]\n'
                     f'position = Vector3({numbers(point)})\n')
    return text.encode()


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("Expected a complete glTF 2.0 GLB")
    document, binary = None, b""
    offset = 12
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8:offset + 8 + size]
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + size
    if document is None:
        raise ValueError("Missing glTF JSON")
    return document, binary


def encode_glb(document: dict, binary: bytes) -> bytes:
    encoded = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary += b"\0" * (-len(binary) % 4)
    length = 12 + 8 + len(encoded) + 8 + len(binary)
    return (struct.pack("<4sII", b"glTF", 2, length)
            + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def extract(document: dict, binary: bytes, group_name: str) -> bytes:
    group = next(n for n in document["nodes"] if n.get("name") == group_name)
    children = [document["nodes"][i] for i in group["children"]]
    if any("children" in n or "mesh" not in n for n in children):
        raise ValueError("Unexpected nested group: " + group_name)
    meshes = [copy.deepcopy(document["meshes"][n["mesh"]]) for n in children]
    used_accessors = set()
    for mesh in meshes:
        for primitive in mesh["primitives"]:
            used_accessors.update(primitive["attributes"].values())
            if "indices" in primitive:
                used_accessors.add(primitive["indices"])
            for target in primitive.get("targets", []):
                used_accessors.update(target.values())
    accessor_ids = sorted(used_accessors)
    accessor_map = {old: new for new, old in enumerate(accessor_ids)}
    accessors = [copy.deepcopy(document["accessors"][i]) for i in accessor_ids]
    if any("sparse" in accessor for accessor in accessors):
        raise ValueError("Sparse accessors need explicit extraction support")
    images = copy.deepcopy(document.get("images", []))
    view_ids = sorted({a["bufferView"] for a in accessors}
                      | {i["bufferView"] for i in images})
    view_map = {old: new for new, old in enumerate(view_ids)}
    views, output_binary = [], bytearray()
    for index in view_ids:
        view = copy.deepcopy(document["bufferViews"][index])
        if view.get("buffer", 0) != 0:
            raise ValueError("External buffers are not supported")
        output_binary.extend(b"\0" * (-len(output_binary) % 4))
        source_offset = view.get("byteOffset", 0)
        view["byteOffset"] = len(output_binary)
        view["buffer"] = 0
        output_binary.extend(binary[source_offset:source_offset + view["byteLength"]])
        views.append(view)
    for accessor in accessors:
        accessor["bufferView"] = view_map[accessor["bufferView"]]
    for image in images:
        image["bufferView"] = view_map[image["bufferView"]]
    for mesh in meshes:
        for primitive in mesh["primitives"]:
            primitive["attributes"] = {k: accessor_map[v] for k, v in primitive["attributes"].items()}
            if "indices" in primitive:
                primitive["indices"] = accessor_map[primitive["indices"]]
            for target in primitive.get("targets", []):
                for key, value in target.items():
                    target[key] = accessor_map[value]
    asset = copy.deepcopy(document["asset"])
    asset["generator"] = "joc-vanatoare build_obur_weapons.py"
    asset.setdefault("extras", {})["modifications"] = (
        "Individual item extracted; display layout/rotation/scale removed. "
        "Source mesh data and palette preserved. Game scene supplies grip, scale and muzzle."
    )
    result = {
        "asset": asset,
        "scene": 0,
        "scenes": [{"name": group_name, "nodes": [0]}],
        "nodes": [{"name": group_name, "children": list(range(1, len(children) + 1))}]
                 + [{"name": n["name"], "mesh": i} for i, n in enumerate(children)],
        "meshes": meshes,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(output_binary)}],
        "images": images,
    }
    for key in ["materials", "textures", "samplers", "extensionsUsed", "extensionsRequired"]:
        if key in document:
            result[key] = copy.deepcopy(document[key])
    return encode_glb(result, bytes(output_binary))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify without writing")
    args = parser.parse_args()
    document, binary = read_glb(SOURCE)
    outputs = {}
    for group, stem in GROUPS.items():
        outputs[ASSETS / (stem + ".glb")] = extract(document, binary, group)
    fit = json.loads(Path(__file__).with_name("obur_weapon_fit.json").read_text())
    for weapon_id, weapon in fit["weapons"].items():
        outputs[ROOT / f"actors/equipment/{weapon_id}.tscn"] = scene_bytes(
            document, binary, weapon_id, weapon, fit["models"][weapon["model"]]
        )
    receipt = {
        "source": "source/" + SOURCE.name,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "attribution": document["asset"].get("extras", {}),
        "modifications": "Individual groups extracted; presentation transforms removed; meshes and palette unchanged.",
        "outputs": {str(path.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(data).hexdigest()
                    for path, data in outputs.items()},
    }
    outputs[ASSETS / "source_receipt.json"] = (json.dumps(receipt, ensure_ascii=False, indent=2) + "\n").encode()
    for path, data in outputs.items():
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                raise SystemExit("Mismatch: " + str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        print(("VERIFIED " if args.check else "BUILT ") + str(path.relative_to(ROOT)))


if __name__ == "__main__":
    main()
