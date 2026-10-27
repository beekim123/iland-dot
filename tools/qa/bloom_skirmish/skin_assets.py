#!/usr/bin/env python3
"""Inspect actual animal GLB skin weights and joint animation, not node names.

Default is the complete eight-model cast. --pilot PATH ... is explicitly partial
and cannot produce a complete-cast pass. No third-party Python packages needed.
"""
import argparse
import base64
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
MODEL_ROOT = ROOT / "godot/modules/bloom_skirmish/art/models/animals/rigged"
SPECIES = ("rabbit", "fox", "otter", "raccoon")
TEAMS = ("blue", "orange")
REQUIRED_CLIPS = {"idle", "run", "spray", "dash", "hit", "pod", "respawn", "celebration", "defeat"}
COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def require(ok, message):
    if not ok:
        raise AssertionError(message)


class GLB:
    def __init__(self, path):
        self.path = Path(path)
        blob = self.path.read_bytes()
        require(len(blob) >= 20, "truncated GLB")
        magic, version, length = struct.unpack_from("<III", blob)
        require(magic == 0x46546C67 and version == 2 and length == len(blob), "invalid GLB 2 header")
        chunks = []
        cursor = 12
        while cursor < len(blob):
            require(cursor + 8 <= len(blob), "truncated chunk header")
            size, kind = struct.unpack_from("<II", blob, cursor)
            cursor += 8
            require(size % 4 == 0 and cursor + size <= len(blob), "invalid chunk length")
            chunks.append((kind, blob[cursor:cursor + size]))
            cursor += size
        require(chunks and chunks[0][0] == 0x4E4F534A, "missing JSON chunk")
        self.doc = json.loads(chunks[0][1])
        binary = next((data for kind, data in chunks if kind == 0x004E4942), b"")
        self.buffers = []
        for index, buffer in enumerate(self.doc.get("buffers", [])):
            uri = buffer.get("uri")
            if uri is None:
                require(index == 0, "only first GLB buffer may omit URI")
                data = binary
            elif uri.startswith("data:") and ";base64," in uri:
                data = base64.b64decode(uri.split(",", 1)[1], validate=True)
            else:
                # This cast is deliberately embedded; extraction never needs a
                # user-machine path or network lookup to obtain weighted data.
                raise AssertionError("animal skin buffer must be embedded")
            require(len(data) >= buffer["byteLength"], "buffer shorter than declaration")
            self.buffers.append(data)

    def _elements(self, view_id, offset, count, component, width, normalized=False):
        view = self.doc["bufferViews"][view_id]
        fmt, unit = COMPONENTS[component]
        stride = view.get("byteStride", unit * width)
        require(stride >= unit * width, "accessor stride too small")
        start = view.get("byteOffset", 0) + offset
        end = start + (count - 1) * stride + unit * width if count else start
        require(end <= view.get("byteOffset", 0) + view["byteLength"], "accessor exceeds bufferView")
        buffer = self.buffers[view.get("buffer", 0)]
        require(end <= len(buffer), "accessor exceeds actual buffer")
        rows = [struct.unpack_from("<" + fmt * width, buffer, start + i * stride) for i in range(count)]
        if normalized and component != 5126:
            maximum = {5120: 127, 5121: 255, 5122: 32767, 5123: 65535, 5125: 4294967295}[component]
            rows = [tuple(max(-1.0, value / maximum) for value in row) for row in rows]
        return rows

    def accessor(self, index):
        value = self.doc["accessors"][index]
        count, width = value["count"], WIDTHS[value["type"]]
        if "bufferView" in value:
            rows = self._elements(value["bufferView"], value.get("byteOffset", 0), count, value["componentType"], width, value.get("normalized", False))
        else:
            rows = [(0,) * width for _ in range(count)]
        if "sparse" in value:
            sparse = value["sparse"]
            ind, vals = sparse["indices"], sparse["values"]
            indices = self._elements(ind["bufferView"], ind.get("byteOffset", 0), sparse["count"], ind["componentType"], 1)
            replacements = self._elements(vals["bufferView"], vals.get("byteOffset", 0), sparse["count"], value["componentType"], width, value.get("normalized", False))
            for (i,), replacement in zip(indices, replacements):
                require(0 <= i < count, "sparse index outside accessor")
                rows[i] = replacement
        return rows


def inspect(path):
    glb = GLB(path)
    doc = glb.doc
    nodes, skins = doc.get("nodes", []), doc.get("skins", [])
    require(skins, "NO SKIN: rigid node assembly is not skeletal animation")
    all_joints = set()
    for skin in skins:
        joints = skin.get("joints", [])
        require(len(joints) >= 12 and len(joints) == len(set(joints)), "skin needs distinct articulated limb/body joints")
        require(all(0 <= joint < len(nodes) for joint in joints), "joint references a missing node")
        require("inverseBindMatrices" in skin, "missing actual inverse bind matrices")
        matrices = glb.accessor(skin["inverseBindMatrices"])
        require(len(matrices) == len(joints) and all(len(matrix) == 16 and all(map(math.isfinite, matrix)) for matrix in matrices), "invalid inverse bind matrices")
        all_joints.update(joints)
    vertices = 0
    blended = 0
    used_joints = set()
    skinned_nodes = 0
    for node in nodes:
        if "mesh" not in node or "skin" not in node:
            continue
        skinned_nodes += 1
        skin = skins[node["skin"]]
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            attrs = primitive["attributes"]
            require(all(key in attrs for key in ("POSITION", "JOINTS_0", "WEIGHTS_0")), "skinned primitive has no actual bone/weight arrays")
            positions = glb.accessor(attrs["POSITION"])
            joints = glb.accessor(attrs["JOINTS_0"])
            weights = glb.accessor(attrs["WEIGHTS_0"])
            require(len(positions) == len(joints) == len(weights) and len(positions) > 0, "skin array sizes do not match vertices")
            if "JOINTS_1" in attrs or "WEIGHTS_1" in attrs:
                require("JOINTS_1" in attrs and "WEIGHTS_1" in attrs, "incomplete second influence set")
                joints1, weights1 = glb.accessor(attrs["JOINTS_1"]), glb.accessor(attrs["WEIGHTS_1"])
                require(len(joints1) == len(joints) and len(weights1) == len(weights), "second influence array sizes")
                joints = [a + b for a, b in zip(joints, joints1)]
                weights = [a + b for a, b in zip(weights, weights1)]
            for position, indices, values in zip(positions, joints, weights):
                require(all(map(math.isfinite, position)), "nonfinite mesh vertex")
                require(all(math.isfinite(value) and 0 <= value <= 1.00001 for value in values), "invalid bone weight")
                require(abs(sum(values) - 1) <= .002, "weights are not normalized")
                require(all(isinstance(i, int) and 0 <= i < len(skin["joints"]) for i in indices), "weight references an invalid joint")
                active = {skin["joints"][i] for i, weight in zip(indices, values) if weight > .01}
                used_joints.update(active)
                blended += len(active) >= 2
            vertices += len(positions)
    require(skinned_nodes > 0 and vertices > 100, "no substantial weighted animal mesh")
    require(len(used_joints) >= 10, "limb/body joints do not actually influence mesh vertices")
    require(blended >= 16, "no meaningful multi-joint blend region; rigid per-part weights are insufficient")
    animations = doc.get("animations", [])
    require(animations, "NO ANIMATION: skin alone is not completed animated integration")
    animated_joints = set()
    clip_report = {}
    for animation in animations:
        name = animation.get("name", "")
        require(name and name not in clip_report, "animations require unique names")
        changed = set()
        duration = 0.0
        for channel in animation.get("channels", []):
            target = channel.get("target", {})
            if target.get("node") not in all_joints or target.get("path") not in ("translation", "rotation", "scale"):
                continue
            sampler = animation["samplers"][channel["sampler"]]
            times = [row[0] for row in glb.accessor(sampler["input"])]
            values = glb.accessor(sampler["output"])
            require(len(times) >= 2 and all(math.isfinite(t) and t >= 0 for t in times), "bone track has no finite time span")
            require(all(a < b for a, b in zip(times, times[1:])), "bone keyframe times must increase")
            if sampler.get("interpolation") == "CUBICSPLINE":
                require(len(values) == len(times) * 3, "invalid cubic animation output")
                values = values[1::3]
            require(len(values) == len(times) and all(all(map(math.isfinite, row)) for row in values), "invalid bone keyframe values")
            duration = max(duration, times[-1])
            if any(any(abs(a - b) > .00001 for a, b in zip(values[0], row)) for row in values[1:]):
                changed.add(target["node"])
        require(changed and duration > 0, f"{name}: no real nonconstant skeletal animation")
        animated_joints.update(changed)
        clip_report[name] = {"duration": round(duration, 4), "moving_joints": len(changed)}
    require(len(animated_joints) >= 8, "animation does not articulate a meaningful animal skeleton")
    return {"file": str(path), "skins": len(skins), "joints": len(all_joints), "weighted_vertices": vertices, "blended_vertices": blended, "weighted_joints": len(used_joints), "animated_joints": len(animated_joints), "clips": clip_report}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pilot", nargs="+", type=Path, help="Partial asset checks only; never a complete-cast pass.")
    parser.add_argument("--root", type=Path, default=MODEL_ROOT)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    if args.pilot:
        paths = args.pilot
    else:
        paths = []
        for species in SPECIES:
            for team in TEAMS:
                candidates = list(args.root.rglob(f"{species}_{team}_rigged.glb"))
                require(len(candidates) == 1, f"Expected exactly one rigged {species}/{team}, found {len(candidates)}")
                paths.extend(candidates)
    reports = []
    for path in paths:
        try:
            report = inspect(path)
        except (AssertionError, KeyError, ValueError, IndexError, OSError, struct.error) as error:
            raise SystemExit(f"FAIL ANIMAL SKIN {path}: {error}") from error
        reports.append(report)
        if not args.pilot:
            require(REQUIRED_CLIPS <= set(report["clips"]), f"{path.name}: missing gameplay clips {sorted(REQUIRED_CLIPS - set(report['clips']))}")
        print(json.dumps(report, ensure_ascii=False))
    if args.json:
        args.json.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + "\n")
    print(f"BLOOM ANIMAL SKIN {'PILOT' if args.pilot else 'FULL CAST'}: {len(reports)} assets PASS; actual weights and skeletal tracks, not aesthetic or runtime acceptance")


if __name__ == "__main__":
    main()
