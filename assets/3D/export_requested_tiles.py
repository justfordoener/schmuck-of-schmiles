"""
Export the "Requested Tiles V2" collection from blockout_v005.blend as Godot-ready
.glb modules, with each module's per-edge connection profile derived from its
geometry and baked directly into the exported name.

What it does
------------
- Collects every object *directly* in the "Requested Tiles V2" collection.
  The "Building Blocks.001" sub-collection is excluded (we read collection.objects,
  not all_objects, so nested collections are never touched).
- Classifies each object by its name prefix: Tri -> tri, Quad -> quad, Hex -> hex.
- Rotates each object 90 deg clockwise in place, around its own origin (the
  Blender staging objects are authored 90 deg off the canonical "flat/long
  side on X" orientation). This does not move the origin -- only orientation
  changes, so the preserved pivot (see below) is unaffected.
- For each (now correctly oriented) object, derives its per-edge connection
  profile from the mesh geometry (see derive_tri_profile /
  derive_quad_or_hex_profile below) and validates every token against the
  13-value profile vocabulary.
- Renames objects to "type_ID_edge1_edge2_..." using a single continuous
  counter grouped by type in the order tri, quad, hex, with edge tokens in
  fixed clockwise angle order (tri: 90/210/330, quad: 0/90/180/270,
  hex: 0/60/120/180/240/300), e.g. "tri_1_lake_lake_lake",
  "quad_16_lake_lake-grassland_grassland_grassland-lake".
  Within a type, objects are ordered by their original name (deterministic).
- Moves each tile to world origin by zeroing its location *after* profile
  derivation, without ever recentring the origin itself. The artist-set
  origin (the pivot the WFC algorithm places and rotates modules around) is
  preserved exactly as authored -- it's the same reference point the profile
  derivation relies on as the tile's true grid-cell center, including for
  fragment/air tiles where it deliberately does not sit at the mesh's
  bounding-box center. See memory v005-profile-derivation.
- Exports one .glb per object into assets/3D/modules/ (Blender-standard glTF
  binary, +Y up -> imports cleanly in Godot).
- Backs up the .blend (.bak) and then saves the renames + zeroed locations
  back into blockout_v005.blend.

Run headless from the project root:
    blender --background assets/3D/blockout_v005.blend \
        --python assets/3D/export_requested_tiles.py
Or open the .blend and run this from the Scripting workspace.
"""

import bpy
import os
import math
import shutil
from mathutils import Vector

SOURCE_COLLECTION = "Requested Tiles V2"
EXCLUDE_CHILD = "Building Blocks.001"      # never exported (documented, not iterated)
OUTPUT_SUBDIR = "modules"                  # sibling of the .blend -> assets/3D/modules
TYPE_ORDER = ["tri", "quad", "hex"]        # global counter walks types in this order

PREFIX_TO_TYPE = {
    "Tri": "tri",
    "Quad": "quad",
    "Hex": "hex",
}

TRI_ANGLES = [90, 210, 330]
QUAD_ANGLES = [0, 90, 180, 270]
HEX_ANGLES = [0, 60, 120, 180, 240, 300]
ANGLES_BY_TYPE = {"tri": TRI_ANGLES, "quad": QUAD_ANGLES, "hex": HEX_ANGLES}

# The Blender staging objects (all types) are authored rotated 90 deg off the
# canonical orientation (flat/long side on local Y instead of X). Rather than
# compensate in the angle math, we physically rotate each object 90 deg
# clockwise in place (around its own origin, so the preserved pivot doesn't
# move) before deriving its profile -- so the exported geometry and the
# profile's angle labels are genuinely consistent with each other.
ROTATION_DEG_CLOCKWISE = 90

MAT_TOKEN = {"Lake": "lake", "Grassland": "grassland", "Forest": "forest", "Stone": "cliff"}

VALID_TOKENS = {
    "forest", "grassland", "lake", "cliff", "air",
    "grassland-lake", "lake-grassland",
    "forest-cliff", "cliff-forest",
    "forest-air", "air-forest",
    "cliff-air", "air-cliff",
}


def classify(obj):
    """Return 'tri' | 'quad' | 'hex' for an object, or None if unrecognised."""
    for prefix in sorted(PREFIX_TO_TYPE, key=len, reverse=True):
        if obj.name.startswith(prefix):
            return PREFIX_TO_TYPE[prefix]
    return None


def outward_dir(theta_deg):
    t = math.radians(theta_deg)
    return Vector((math.cos(t), -math.sin(t)))


def tangent_dir(theta_deg):
    t = math.radians(theta_deg)
    return Vector((-math.sin(t), -math.cos(t)))


def get_top_polys(obj):
    """Top-facing (world +Z normal) polygons, with direction from the object's
    *current* origin (the true tile-center reference -- see module docstring)."""
    wm = obj.matrix_world
    mats = [s.material.name if s.material else None for s in obj.material_slots]
    origin = wm.translation
    polys = []
    for p in obj.data.polygons:
        n = wm.to_3x3() @ p.normal
        if n.z > 0.5:
            c = wm @ p.center
            m = mats[p.material_index] if p.material_index < len(mats) else None
            polys.append({"mat": m, "d": Vector((c.x - origin.x, c.y - origin.y)), "z": c.z})
    return polys


def mat_token(mat_name):
    if mat_name not in MAT_TOKEN:
        raise SystemExit(f"Unrecognised material '{mat_name}' on a top-facing polygon "
                          f"-> no profile token mapping.")
    return MAT_TOKEN[mat_name]


def derive_tri_profile(obj):
    """Tri meshes subdivide into 3 vertex-centered kites (centroid to each edge
    midpoint), each touching half of its two adjacent edges -- not one wedge per
    whole edge. Assumes the object has already been rotated to canonical
    orientation (see ROTATION_DEG_CLOCKWISE). See memory v005-profile-derivation
    for the full derivation."""
    polys = get_top_polys(obj)
    corner_claim = {}
    for a in TRI_ANGLES:
        corner_dir = -outward_dir(a)
        best, best_score = None, 0.5
        for p in polys:
            if p["d"].length < 1e-6:
                continue
            s = p["d"].normalized().dot(corner_dir)
            if s > best_score:
                best_score, best = s, p
        corner_claim[a] = best

    result = {}
    for a in TRI_ANGLES:
        o1, o2 = [x for x in TRI_ANGLES if x != a]
        t = tangent_dir(a)
        s1 = (-outward_dir(o1)).dot(t)
        s2 = (-outward_dir(o2)).dot(t)
        first_o, second_o = (o1, o2) if s1 > s2 else (o2, o1)

        def tok(o):
            p = corner_claim[o]
            return mat_token(p["mat"]) if p else "air"

        f, s = tok(first_o), tok(second_o)
        result[a] = f if f == s else f"{f}-{s}"
    return result


def derive_quad_or_hex_profile(obj, angles):
    """Quads (and, untested but structurally identical, hexes) are modeled as
    slab(s) split along at most one axis, not one wedge per edge. A single
    polygon -> uniform. Otherwise: argmax-assign each polygon to its best-
    matching edge; edges left unclaimed are resolved via a tangent-sign half
    split among the *claimed* polygons (positive tangent side = first token)."""
    polys = get_top_polys(obj)
    if not polys:
        return {a: "air" for a in angles}

    if len(polys) == 1:
        tok = mat_token(polys[0]["mat"])
        return {a: tok for a in angles}

    claim = {a: None for a in angles}
    for p in polys:
        d = p["d"]
        if d.length < 1e-6:
            continue
        scores = {a: d.dot(outward_dir(a)) for a in angles}
        best_a = max(scores, key=scores.get)
        if scores[best_a] > 1e-4 and (claim[best_a] is None or p["z"] > claim[best_a]["z"]):
            claim[best_a] = p

    result = {a: mat_token(claim[a]["mat"]) for a in angles if claim[a] is not None}
    orphans = [a for a in angles if claim[a] is None]
    if orphans:
        claimed_polys = [p for p in claim.values() if p is not None]
        for a in orphans:
            t = tangent_dir(a)
            half_pos, half_neg = None, None
            for p in claimed_polys:
                s = p["d"].dot(t)
                if s > 1e-4 and (half_pos is None or p["z"] > half_pos["z"]):
                    half_pos = p
                elif s < -1e-4 and (half_neg is None or p["z"] > half_neg["z"]):
                    half_neg = p
            tok_pos = mat_token(half_pos["mat"]) if half_pos else "air"
            tok_neg = mat_token(half_neg["mat"]) if half_neg else "air"
            result[a] = tok_pos if tok_pos == tok_neg else f"{tok_pos}-{tok_neg}"
    return result


def derive_profile(obj, kind):
    angles = ANGLES_BY_TYPE[kind]
    profile = derive_tri_profile(obj) if kind == "tri" else derive_quad_or_hex_profile(obj, angles)
    for a in angles:
        if profile[a] not in VALID_TOKENS:
            raise SystemExit(f"{obj.name}: derived token '{profile[a]}' at angle {a} "
                              f"is not in the 13-value profile vocabulary.")
    return [profile[a] for a in angles]


def main():
    if not bpy.data.filepath:
        raise SystemExit("This script must run on a saved .blend (open blockout_v005.blend).")

    coll = bpy.data.collections.get(SOURCE_COLLECTION)
    if coll is None:
        raise SystemExit(f'Collection "{SOURCE_COLLECTION}" not found.')

    blend_dir = os.path.dirname(bpy.data.filepath)
    out_dir = os.path.join(blend_dir, OUTPUT_SUBDIR)
    os.makedirs(out_dir, exist_ok=True)

    # --- Gather + classify (direct objects only -> excludes the sub-collection) ---
    buckets = {t: [] for t in TYPE_ORDER}
    skipped = []
    for obj in coll.objects:
        if obj.type != "MESH":
            skipped.append((obj.name, "not a mesh"))
            continue
        t = classify(obj)
        if t is None:
            skipped.append((obj.name, "unknown type prefix"))
            continue
        buckets[t].append(obj)

    for t in buckets:
        buckets[t].sort(key=lambda o: o.name)   # deterministic within-type order

    ordered = [(t, obj) for t in TYPE_ORDER for obj in buckets[t]]
    print(f"[info] found {len(ordered)} objects to export "
          f"({', '.join(f'{t}:{len(buckets[t])}' for t in TYPE_ORDER)})")
    for name, why in skipped:
        print(f"[skip] {name}: {why}")

    # --- Rotate each object 90 deg clockwise in place (around its own origin,
    # so the preserved pivot position is untouched), then derive its profile
    # from the now-canonically-oriented geometry. Rotating first (rather than
    # compensating in the angle math) keeps the exported mesh and its profile
    # labels genuinely consistent with each other. ---
    view_layer = bpy.context.view_layer
    profiles = {}
    for t, obj in ordered:
        # Verified empirically against the previously-validated Tri.009 result
        # (see memory v005-profile-derivation): += is the direction that lands
        # cleanly on the canonical corner directions; -= produces an ambiguous
        # exact 60 deg tie between two corners, which is a strong tell it's the
        # wrong direction.
        obj.rotation_euler.z += math.radians(ROTATION_DEG_CLOCKWISE)
        view_layer.update()
        profiles[obj.name] = derive_profile(obj, t)
        print(f"[profile] {obj.name} ({t}) -> {'_'.join(profiles[obj.name])}")

    # --- Backup the .blend before any destructive change ---
    backup = bpy.data.filepath + ".bak"
    shutil.copy2(bpy.data.filepath, backup)
    print(f"[info] backed up source blend -> {backup}")

    # --- Rename (type_ID_profile...) + zero location, exporting one .glb each ---
    counter = 0
    exported = []
    for t, obj in ordered:
        counter += 1
        original_name = obj.name
        target = "_".join([t, str(counter)] + profiles[original_name])

        obj.name = target
        if obj.name != target:                  # Blender silently appends .001 on clash
            raise SystemExit(f'Rename collision: wanted "{target}", got "{obj.name}".')

        # Isolate this object (needed for the export).
        bpy.ops.object.select_all(action="DESELECT")
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
        view_layer.objects.active = obj

        # Preserve the artist-set origin (the pivot the WFC algorithm places
        # and rotates around) exactly as authored -- move the whole object to
        # world origin by zeroing location only. Never recentre the origin to
        # the bounding box: that would overwrite the same pivot the profile
        # derivation above relies on as the true tile-center reference (see
        # memory v005-profile-derivation), and for fragment/air tiles the
        # bbox center is deliberately *not* where the artist put the origin.
        obj.location = (0.0, 0.0, 0.0)
        view_layer.update()   # refresh matrix_world before reading it back

        filepath = os.path.join(out_dir, f"{target}.glb")
        bpy.ops.export_scene.gltf(
            filepath=filepath,
            export_format="GLB",
            use_selection=True,
            export_yup=True,          # Godot / glTF convention
            export_apply=False,       # keep zeroed transform; don't bake modifiers away
        )
        exported.append(filepath)
        print(f"[ok] {obj.name}  ->  {os.path.relpath(filepath, blend_dir)}")

    # --- Persist renames + zeroed locations into the .blend ---
    bpy.ops.wm.save_mainfile()
    print(f"[info] saved renames + centred/zeroed transforms into {bpy.data.filepath}")
    print(f"[done] exported {len(exported)} .glb files to {out_dir}")


if __name__ == "__main__":
    main()
