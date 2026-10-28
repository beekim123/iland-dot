#!/usr/bin/env python3
"""Area-weighted fox palette preservation, not material/mesh-count assertions.

Compare a frozen original-GLB area histogram with rigged PBR faces.
The baseline records original source hashes and was captured before removing
obsolete unskinned exports; it must never be refreshed from the current rig.
The deliberately rebuilt weapon and translucent glass are excluded from both.
"""
import argparse
import json
import math
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from skin_assets import GLB, ROOT, require

IDENTITY = ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1))


def multiply(a, b):
    return tuple(tuple(sum(a[row][k] * b[k][col] for k in range(4)) for col in range(4)) for row in range(4))


def transform(node):
    if "matrix" in node:
        matrix = node["matrix"]
        return tuple(tuple(matrix[col * 4 + row] for col in range(4)) for row in range(4))
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    scale = node.get("scale", (1, 1, 1))
    rotation = ((1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w),
                (2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w),
                (2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y))
    translation = node.get("translation", (0, 0, 0))
    return tuple(tuple(rotation[row][col] * scale[col] for col in range(3)) + (translation[row],) for row in range(3)) + ((0, 0, 0, 1),)


def point(matrix, vertex):
    return tuple(sum(matrix[row][k] * vertex[k] for k in range(3)) + matrix[row][3] for row in range(3))


def area(a, b, c):
    u, v = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
    cross = (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0])
    return math.sqrt(sum(value * value for value in cross)) * .5


def histogram(path):
    glb = GLB(path)
    doc = glb.doc
    nodes = doc["nodes"]
    parents = {child: parent for parent, node in enumerate(nodes) for child in node.get("children", [])}
    world = {}
    def matrix(index):
        if index not in world:
            world[index] = multiply(matrix(parents[index]) if index in parents else IDENTITY, transform(nodes[index]))
        return world[index]
    def is_weapon(index):
        while True:
            if nodes[index].get("name", "").lower() == "weapon":
                return True
            if index not in parents:
                return False
            index = parents[index]
    result = {}
    faces = 0
    for index, node in enumerate(nodes):
        if "mesh" not in node or is_weapon(index):
            continue
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            require(primitive.get("mode", 4) == 4, "Palette probe requires actual triangle faces")
            attrs = primitive["attributes"]
            positions = [point(matrix(index), v) for v in glb.accessor(attrs["POSITION"])]
            colors = glb.accessor(attrs["COLOR_0"]) if "COLOR_0" in attrs else None
            material = doc.get("materials", [])[primitive["material"]] if "material" in primitive else {}
            base = material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
            if base[3] < .5:
                continue
            indices = [value[0] for value in glb.accessor(primitive["indices"])] if "indices" in primitive else list(range(len(positions)))
            require(len(indices) % 3 == 0, "Incomplete triangle list")
            for offset in range(0, len(indices), 3):
                triangle = indices[offset:offset+3]
                weight = area(*(positions[i] for i in triangle))
                color = tuple(base[channel] * (sum(colors[i][channel] for i in triangle) / 3 if colors is not None else 1) for channel in range(3))
                # 8-bit LINEAR bins absorb exporter float roundoff, not gamma or
                # palette changes. Original linear vertex colors stay linear.
                bucket = tuple(round(max(0, min(1, value)) * 255) for value in color)
                result[bucket] = result.get(bucket, 0) + weight
                faces += 1
    total = sum(result.values())
    require(total > 0 and len(result) >= 4, "Actual multicolor animal face area is required")
    return {"total_area": total, "triangles": faces, "shares": {key: value / total for key, value in result.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--module", type=Path, default=ROOT / "godot/modules/bloom_skirmish")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    baseline_path = args.module / "art/source/animals/rigging/fox/original_palette_baseline.json"
    baseline = json.loads(baseline_path.read_text())
    require(baseline["schema"] == 1, "Unsupported original palette baseline")
    reports = []
    for team in ("blue", "orange"):
        frozen = baseline["assets"][team]
        original = {"total_area": frozen["total_area"], "triangles": frozen["triangles"],
                    "shares": {tuple(row["linear_rgb8"]): row["share"] for row in frozen["shares"]}}
        require(original["total_area"] > 0 and len(original["shares"]) >= 4, "Invalid original palette baseline")
        rigged = args.module / f"art/models/animals/rigged/fox/fox_{team}_rigged.glb"
        current = histogram(rigged)
        differences = {key: current["shares"].get(key, 0) - original["shares"].get(key, 0) for key in original["shares"].keys() | current["shares"].keys()}
        maximum = max(map(abs, differences.values()))
        total_variation = sum(map(abs, differences.values())) * .5
        area_ratio = current["total_area"] / original["total_area"]
        report = {"team": team, "source_triangles": original["triangles"], "rigged_triangles": current["triangles"], "area_ratio": area_ratio, "maximum_color_share_change": maximum, "total_variation": total_variation,
                  "histogram": [{"linear_rgb8": key, "source_share": original["shares"].get(key, 0), "rigged_share": current["shares"].get(key, 0)} for key in sorted(differences)]}
        reports.append(report)
        print(json.dumps(report))
        require(.98 <= area_ratio <= 1.02, f"{team}: unexplained non-weapon geometry area change")
        require(maximum < .01 and total_variation < .015, f"{team}: fox color area changed; material-slot counts alone conceal this regression")
    if args.json:
        args.json.write_text(json.dumps(reports, indent=2) + "\n")
    print("BLOOM FOX PALETTE AREA: two teams PASS; actual opaque non-weapon triangle-area distribution, not material-count equivalence")


if __name__ == "__main__":
    main()
