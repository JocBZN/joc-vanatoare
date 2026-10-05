"""Reproduce the CC0 deer/wolf GLBs without changing their scene wrappers."""
import argparse
import hashlib
import json
import pathlib
import struct

import numpy as np

PROJECT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = {
    "deer": {
        "height": 1.3,
        "page": "https://poly.pizza/m/T6Cs7tmMHJ",
        "download": "https://static.poly.pizza/4b6c2a41-43c7-404c-ae37-e8c4645ff93b.glb",
        "sha256": "fabf360b22eaccccd056ee99d698a9562d15aa245821f96e4fbad6db3751604e",
        "aliases": {"Attack_Headbutt": "Attack", "Attack_Kick": "Kick", "Death": "Die", "Eating": "Graze", "Gallop": "Run", "Gallop_Jump": "RunJump", "Idle_HitReact_Left": "HitLeft", "Idle_HitReact_Right": "HitRight", "Jump_toIdle": "Jump", "Walk": "Walk", "Idle_Headlow": "HeadLow", "Idle_2": "Rest", "Idle": "Idle"},
    },
    "wolf": {
        "height": 1.0,
        "page": "https://poly.pizza/m/P1gU3Qkr9r",
        "download": "https://static.poly.pizza/f1d12388-e39b-4157-b32a-646a1d089fc4.glb",
        "sha256": "16ac96339d06f7def9af20d5d9b27622d61e53580dab43970c9edb1bffbe8f84",
        "aliases": {"Attack": "Attack", "Death": "Die", "Eating": "Graze", "Gallop": "Run", "Gallop_Jump": "RunJump", "Idle_HitReact_Left": "HitLeft", "Idle_HitReact_Right": "HitRight", "Jump_ToIdle": "Jump", "Walk": "Walk", "Idle_2_HeadLow": "HeadLow", "Idle_2": "Rest", "Idle": "Idle"},
    },
}


def local_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"]).reshape(4, 4).T
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    result = np.eye(4)
    result[:3, :3] = [
        [1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w],
        [2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w],
        [2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y],
    ]
    result[:3, :3] = result[:3, :3] @ np.diag(node.get("scale", [1, 1, 1]))
    result[:3, 3] = node.get("translation", [0, 0, 0])
    return result


def positions(gltf, binary, index):
    accessor = gltf["accessors"][index]
    if accessor["type"] != "VEC3" or accessor["componentType"] != 5126:
        raise ValueError("Expected FLOAT VEC3 source mesh positions")
    view = gltf["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    return np.array([struct.unpack_from("<fff", binary, start + stride*i) for i in range(accessor["count"])])


def bounds(gltf, binary):
    points = []

    def visit(index, parent):
        node = gltf["nodes"][index]
        world = parent @ local_matrix(node)
        if "mesh" in node:
            for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
                vertices = positions(gltf, binary, primitive["attributes"]["POSITION"])
                points.append((world @ np.column_stack([vertices, np.ones(len(vertices))]).T).T[:, :3])
        for child in node.get("children", []):
            visit(child, world)

    for index in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        visit(index, np.eye(4))
    joined = np.concatenate(points)
    return joined.min(axis=0), joined.max(axis=0)


def normalize(species, original):
    spec = SOURCES[species]
    source_hash = hashlib.sha256(original).hexdigest()
    if source_hash != spec["sha256"]:
        raise ValueError(f"{species}: source SHA-256 changed; verify provenance before updating the pipeline")
    magic, version, total_size = struct.unpack_from("<III", original)
    if (magic, version, total_size) != (0x46546c67, 2, len(original)):
        raise ValueError(f"{species}: invalid GLB 2 header")
    size, kind = struct.unpack_from("<II", original, 12)
    if kind != 0x4e4f534a:
        raise ValueError("Missing GLB JSON chunk")
    gltf = json.loads(original[20:20+size])
    binary_size, binary_kind = struct.unpack_from("<II", original, 20+size)
    if binary_kind != 0x004e4942:
        raise ValueError("Missing GLB binary chunk")
    binary = original[28+size:28+size+binary_size]
    low, high = bounds(gltf, binary)
    scale = spec["height"] / (high[1] - low[1])
    # Source +Z becomes Godot wildlife -Z. Original skin and keyframes stay intact.
    outer = {
        "name": f"Stylized{species.title()}",
        "children": gltf["scenes"][gltf.get("scene", 0)]["nodes"],
        "translation": [float(scale*(low[0]+high[0])/2), float(-scale*low[1]), float(scale*(low[2]+high[2])/2)],
        "rotation": [0, 1, 0, 0],
        "scale": [float(scale)]*3,
    }
    gltf["nodes"].append(outer)
    gltf["scenes"][gltf.get("scene", 0)]["nodes"] = [len(gltf["nodes"])-1]
    kept = []
    for animation in gltf["animations"]:
        if "|" in animation["name"]:
            continue
        original_name = animation["name"]
        animation["name"] = spec["aliases"][original_name]
        animation.setdefault("extras", {})["source_action"] = original_name
        kept.append(animation)
    kept.sort(key=lambda action: (action["name"] == "Idle", action["name"]))
    gltf["animations"] = kept
    for material in gltf.get("materials", []):
        material["pbrMetallicRoughness"]["metallicFactor"] = 0
        material["pbrMetallicRoughness"]["roughnessFactor"] = .88
    gltf["asset"].setdefault("extras", {}).update({
        "author": "Quaternius", "license": "CC0 1.0", "source": spec["page"],
        "adaptation": "In-game scale, feet at y=0, facing -Z, duplicate clips removed, canonical action names, matte materials. Original geometry, skin weights and animation keyframes preserved.",
    })
    encoded = json.dumps(gltf, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    output = struct.pack("<III", 0x46546c67, 2, 28+len(encoded)+len(binary))
    output += struct.pack("<II", len(encoded), 0x4e4f534a) + encoded
    output += struct.pack("<II", len(binary), 0x004e4942) + binary
    normalized_low, normalized_high = bounds(gltf, binary)
    receipt = {
        "species": species, "author": "Quaternius", "license": "CC0 1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "source_listing_date": "2021-09-07", "retrieved_on": "2026-10-05",
        "pipeline": "tools/asset_pipeline/normalize_deer_wolf.py",
        "page": spec["page"], "download": spec["download"],
        "source_sha256": source_hash, "runtime_sha256": hashlib.sha256(output).hexdigest(),
        "runtime": f"assets/animals/stylized/{species}.glb", "scale": float(scale),
        "bounds": [normalized_low.tolist(), normalized_high.tolist()],
        "clips": [action["name"] for action in kept],
    }
    return output, receipt


def project_path(value):
    path = pathlib.Path(value)
    return path if path.is_absolute() else PROJECT / path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", default="work/animal_sources", help="Original GLBs; relative paths are repository-relative")
    parser.add_argument("--output-dir", default="assets/animals/stylized", help="Normalized GLBs and provenance receipt")
    parser.add_argument("--check", action="store_true", help="Verify source and runtime hashes without writing any file")
    args = parser.parse_args()
    source_dir, output_dir = project_path(args.source_dir), project_path(args.output_dir)
    receipts = []
    for species in SOURCES:
        original = (source_dir / f"{species}_quaternius_cc0.glb").read_bytes()
        output, receipt = normalize(species, original)
        target = output_dir / f"{species}.glb"
        if args.check:
            if target.read_bytes() != output:
                raise ValueError(f"{species}: current runtime model differs from reproduced output")
            print(f"CHECK_OK {species} {receipt['runtime_sha256']}")
        else:
            output_dir.mkdir(parents=True, exist_ok=True)
            target.write_bytes(output)
            print(f"NORMALIZED {species} {receipt['runtime_sha256']}")
        receipts.append(receipt)
    if not args.check:
        (output_dir / "deer_wolf_sources.json").write_text(json.dumps(receipts, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
