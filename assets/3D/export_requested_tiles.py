"""
Export the "Requested Tiles V2" collection from blockout_v005.blend as Godot-ready
.glb modules, with each module's per-edge connection profile derived from its
geometry and baked directly into the exported name.

What it does
------------
- Collects every object *directly* in the "Requested Tiles V2" collection.
  The "Building Blocks.001" sub-collection is excluded (we read collection.objects,
  not all_objects, so nested collections are never touched).
- Classifies each object by its name prefix into the *cell type* it fills:
  Tri -> face, Quad -> edge, Hex -> corner (the mesh shape is an implementation
  detail; the cell type is what Godot's Layout.CELL_TYPE and the module scenes
  speak in).
- Rotates each object 90 deg clockwise in place, around its own origin (the
  Blender staging objects are authored 90 deg off the canonical "flat/long
  side on X" orientation). This does not move the origin -- only orientation
  changes, so the preserved pivot (see below) is unaffected.
- For each (now correctly oriented) object, derives its per-edge connection
  profile from the mesh geometry (see derive_tri_profile /
  derive_quad_or_hex_profile below) and validates every token against the
  profile vocabulary. Derivation can only report what a border physically looks
  like, so the modules whose borders carry authored meaning the mesh doesn't show
  (the raised-tile rims) are listed in AUTHORED_PROFILES and bypass it.
- Names each module "celltype_edge1_edge2_..." with edge tokens in fixed
  clockwise angle order (face: 90/210/330, edge: 0/90/180/270, corner:
  0/60/120/180/240/300), e.g. "face_water_water_water",
  "edge_surface_air-cliff_air_cliff-air". "_" separates borders, "-" joins the
  two halves of a split border -- so a token never contains "_".

  There is deliberately no id number in the name. Ids used to come from a global
  counter over name-sorted objects, which meant adding or removing a single
  object in the .blend silently renumbered everything downstream of it and
  repointed live .tscn files at the wrong geometry. The profile *is* the
  identity, so the name is now stable under edits to the collection. Each
  module's profile is unique across the set; main() asserts that before writing.
- Moves each tile to world origin by zeroing its location *after* profile
  derivation, without ever recentring the origin itself. The artist-set
  origin (the pivot the WFC algorithm places and rotates modules around) is
  preserved exactly as authored -- it's the same reference point the profile
  derivation relies on as the tile's true grid-cell center, including for
  fragment/air tiles where it deliberately does not sit at the mesh's
  bounding-box center. See memory v005-profile-derivation.
- Exports one .glb per object into assets/3D/modules/ (Blender-standard glTF
  binary, +Y up -> imports cleanly in Godot).
- Never writes to the .blend. Objects are renamed only in memory, for the
  duration of their own export (so the .glb's internal root node matches its
  filename), and restored immediately after. The file is not saved and no .bak
  is taken. Besides leaving the artist's file alone, this is what keeps
  AUTHORED_PROFILES below -- which is keyed on the *authoring* name, Tri.003 --
  valid across runs.

Run headless from the project root:
    blender --background assets/3D/blockout_v005.blend \
        --python assets/3D/export_requested_tiles.py
Or open the .blend and run this from the Scripting workspace.
"""

import bpy
import os
import re
import math
from mathutils import Vector

SOURCE_COLLECTION = "Requested Tiles V2"
EXCLUDE_CHILD = "Building Blocks.001"      # never exported (documented, not iterated)
OUTPUT_SUBDIR = "modules"                  # sibling of the .blend -> assets/3D/modules
TYPE_ORDER = ["face", "edge", "corner"]    # export order only; names carry no counter

# Authoring prefix -> the Layout.CELL_TYPE the module fills.
PREFIX_TO_TYPE = {
    "Tri": "face",
    "Quad": "edge",
    "Hex": "corner",
}

FACE_ANGLES = [90, 210, 330]
EDGE_ANGLES = [0, 90, 180, 270]
CORNER_ANGLES = [0, 60, 120, 180, 240, 300]
ANGLES_BY_TYPE = {"face": FACE_ANGLES, "edge": EDGE_ANGLES, "corner": CORNER_ANGLES}

# The Blender staging objects (all types) are authored rotated 90 deg off the
# canonical orientation (flat/long side on local Y instead of X). Rather than
# compensate in the angle math, we physically rotate each object 90 deg
# clockwise in place (around its own origin, so the preserved pivot doesn't
# move) before deriving its profile -- so the exported geometry and the
# profile's angle labels are genuinely consistent with each other.
ROTATION_DEG_CLOCKWISE = 90

# Blender material -> profile element. The material names are the artist's; the tokens
# are the game's vocabulary (Layout.PROFILE_TYPE), which is why they differ.
MAT_TOKEN = {"Lake": "water", "Grassland": "grass", "Forest": "forest", "Stone": "cliff"}

# Mirrors Layout.PROFILE_TYPE. "surface" is a wildcard, not an element, and "house" has
# no geometry yet -- neither is derivable from a material, so both can only ever reach a
# name through AUTHORED_PROFILES below. Composite direction matters: "grass-water" and
# "water-grass" are different borders (clockwise, read from outside the module).
VALID_TOKENS = {
    "forest", "grass", "water", "cliff", "air", "house", "surface",
    "grass-water", "water-grass",
    "forest-cliff", "cliff-forest",
    "forest-air", "air-forest",
    "cliff-air", "air-cliff",
}

# Profiles the geometry cannot tell us, keyed on the object's *authoring* name and given
# in the same clockwise angle order as ANGLES_BY_TYPE.
#
# derive_profile() reads the material of the top-facing polygons, so it can only ever
# report what a border physically looks like. On the raised-tile rim modules that is not
# what the border *means*: the rim is a solid stone (or forest) slab whose top face says
# nothing about the air on one side and the tile surface on the other. Two consequences
# the derivation gets wrong, both authored in the .tscn and reproduced here:
#   - the inward border of a rim is the surface of the tile it wraps (the SURFACE
#     wildcard, since one rim serves grass and water alike),
#     not the stone the mesh is made of;
#   - the outward border of a rim faces empty space (air), not stone.
# Without these, edge_forest_forest_forest_forest and the forest rim derive to the *same*
# name -- the number used to be the only thing separating them.
AUTHORED_PROFILES = {
    "Quad.012": ["surface", "forest-cliff", "forest", "cliff-forest"], # forest/cliff rim
    "Quad.014": ["air", "forest-air", "forest", "air-forest"],         # forest/air rim
    "Quad.018": ["surface", "air-cliff", "air", "cliff-air"],          # shared cliff rim
    "Tri.003":  ["surface", "forest-cliff", "cliff-forest"],           # forest/cliff rim
    "Tri.021":  ["surface", "air-cliff", "cliff-air"],                 # shared cliff rim
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


# Blender appends a ".001"-style suffix when a datablock name collides -- duplicating
# an object or appending from another file yields "Stone.001", which is the *same*
# material as "Stone", not a new one. Strip that suffix before the lookup, otherwise
# every duplicate silently breaks profile derivation (this is what made the exporter
# unrunnable against blockout_v005 once Tri.003/Tri.004 picked up Forest.001/Stone.001).
MAT_SUFFIX_RE = re.compile(r"\.\d{3}$")


def mat_token(mat_name):
    base = MAT_SUFFIX_RE.sub("", mat_name)
    if base not in MAT_TOKEN:
        raise SystemExit(f"Unrecognised material '{mat_name}' on a top-facing polygon "
                          f"-> no profile token mapping.")
    return MAT_TOKEN[base]


def derive_tri_profile(obj):
    """Tri meshes subdivide into 3 vertex-centered kites (centroid to each edge
    midpoint), each touching half of its two adjacent edges -- not one wedge per
    whole edge. Assumes the object has already been rotated to canonical
    orientation (see ROTATION_DEG_CLOCKWISE). See memory v005-profile-derivation
    for the full derivation."""
    polys = get_top_polys(obj)
    corner_claim = {}
    for a in FACE_ANGLES:
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
    for a in FACE_ANGLES:
        o1, o2 = [x for x in FACE_ANGLES if x != a]
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
    """Profile as a list of tokens in clockwise angle order. An entry in
    AUTHORED_PROFILES wins over the geometry -- see the table for why."""
    angles = ANGLES_BY_TYPE[kind]
    if obj.name in AUTHORED_PROFILES:
        tokens = AUTHORED_PROFILES[obj.name]
        if len(tokens) != len(angles):
            raise SystemExit(f"{obj.name}: authored profile has {len(tokens)} tokens, "
                              f"but a {kind} has {len(angles)} borders.")
    else:
        profile = derive_tri_profile(obj) if kind == "face" else derive_quad_or_hex_profile(obj, angles)
        tokens = [profile[a] for a in angles]
    for a, tok in zip(angles, tokens):
        if tok not in VALID_TOKENS:
            raise SystemExit(f"{obj.name}: token '{tok}' at angle {a} is not in the "
                              f"profile vocabulary.")
    return tokens


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
        source = "authored" if obj.name in AUTHORED_PROFILES else "derived "
        print(f"[{source}] {obj.name} ({t}) -> {'_'.join(profiles[obj.name])}")

    # --- Resolve names and prove they are unique before writing anything ---
    # The name is the identity now, so a duplicate would silently overwrite a sibling's
    # .glb instead of just producing an odd filename. Fail here, not halfway through.
    targets, claimed_by = {}, {}
    for t, obj in ordered:
        target = "_".join([t] + profiles[obj.name])
        if target in claimed_by:
            raise SystemExit(f'Name collision: "{obj.name}" and "{claimed_by[target]}" both '
                              f'resolve to "{target}". Two modules share a profile -- one '
                              f'of them needs an AUTHORED_PROFILES entry.')
        claimed_by[target] = obj.name
        targets[obj.name] = target

    # --- Zero location and export one .glb each ---
    exported = []
    for t, obj in ordered:
        original_name = obj.name
        target = targets[original_name]

        # Renamed only for the length of this export, so the .glb's internal root node
        # matches its filename; restored below. The .blend is never saved.
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
        #
        # Zero X/Y only, and keep the authored Z. The staging Z is not scratch
        # layout -- it is the artist's vertical alignment of the tile against
        # the grid plane. Tri origins are authored at the slab's *bottom* (local
        # verts span z 0..0.5) and the objects are staged at z=-0.25 to line them
        # up with the quads/hexes, whose origins sit at their vertical centre
        # (verts span -0.25..0.25) and which stage at z=0. Zeroing Z as well
        # discarded that compensation and exported every tri 0.25 too high, so
        # its geometry straddled the cell above instead of the cell it belongs
        # to. Keeping Z is a no-op for quads and hexes.
        obj.location = (0.0, 0.0, obj.location.z)
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
        print(f"[ok] {original_name}  ->  {os.path.relpath(filepath, blend_dir)}")
        obj.name = original_name

    print(f"[done] exported {len(exported)} .glb files to {out_dir}")
    print("[info] .blend NOT saved -- object names and stored transforms are untouched")


if __name__ == "__main__":
    main()
