"""
Export the "Requested Tiles" collection from blockout_v003.blend as Godot-ready
.glb modules.

What it does
------------
- Collects every object *directly* in the "Requested Tiles" collection.
  The "Building blocks" sub-collection is excluded (we read collection.objects,
  not all_objects, so nested collections are never touched).
- Classifies each object by its name prefix: Req_Tri -> tri, Req_Quad -> quad,
  Req_Hex -> hex.
- Renames them to "type_ID" using a single continuous counter, grouped by type
  in the order tri, quad, hex:
      tri_1  .. tri_24
      quad_25 .. quad_33
      hex_34 .. hex_36
  Within a type, objects are ordered by their original name (deterministic).
- Centres each tile on the origin: the grid layout is baked into the mesh
  verts, so the object origin is moved to the geometry's bounding-box centre
  and the location zeroed, putting the mesh's bbox centre at world (0,0,0).
- Exports one .glb per object into assets/3D/modules/ (Blender-standard glTF
  binary, +Y up -> imports cleanly in Godot).
- Backs up the .blend (.bak) and then saves the renames + zeroed locations
  back into blockout_v003.blend.

Run headless from the project root:
    blender --background assets/3D/blockout_v003.blend \
        --python assets/3D/export_requested_tiles.py
Or open the .blend and run this from the Scripting workspace.
"""

import bpy
import os
import shutil
from mathutils import Vector

SOURCE_COLLECTION = "Requested Tiles"
EXCLUDE_CHILD = "Building blocks"          # never exported (documented, not iterated)
OUTPUT_SUBDIR = "modules"                  # sibling of the .blend -> assets/3D/modules
TYPE_ORDER = ["tri", "quad", "hex"]        # global counter walks types in this order

# Object-name prefix -> canonical type used in the exported name.
PREFIX_TO_TYPE = {
    "Req_Tri": "tri",
    "Req_Quad": "quad",
    "Req_Hex": "hex",
}


def classify(obj):
    """Return 'tri' | 'quad' | 'hex' for an object, or None if unrecognised."""
    # Longest prefix first so "Req_Tri" can't accidentally shadow anything.
    for prefix in sorted(PREFIX_TO_TYPE, key=len, reverse=True):
        if obj.name.startswith(prefix):
            return PREFIX_TO_TYPE[prefix]
    return None


def bound_center(obj):
    """World-space center of the object's bounding box (post-transform)."""
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return sum(corners, Vector((0.0, 0.0, 0.0))) / len(corners)


def main():
    if not bpy.data.filepath:
        raise SystemExit("This script must run on a saved .blend (open blockout_v003.blend).")

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

    # --- Backup the .blend before any destructive change (file is untracked) ---
    backup = bpy.data.filepath + ".bak"
    shutil.copy2(bpy.data.filepath, backup)
    print(f"[info] backed up source blend -> {backup}")

    # --- Rename + zero location, exporting one .glb each ---
    view_layer = bpy.context.view_layer
    counter = 0
    exported = []
    for t, obj in ordered:
        counter += 1
        target = f"{t}_{counter}"

        obj.name = target
        if obj.name != target:                  # Blender silently appends .001 on clash
            raise SystemExit(f'Rename collision: wanted "{target}", got "{obj.name}".')

        # Isolate this object (needed for the origin operator and the export).
        bpy.ops.object.select_all(action="DESELECT")
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
        view_layer.objects.active = obj

        # The grid layout is baked into the mesh verts, so location alone won't
        # centre a tile. Move the object origin to the geometry's bounding-box
        # centre, then zero the location -> the mesh's bbox centre lands at world
        # origin, which is what gets baked into the .glb.
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        obj.location = (0.0, 0.0, 0.0)
        view_layer.update()   # refresh matrix_world before reading it back

        # Confirm the geometry really is centred now.
        c = bound_center(obj)
        if max(abs(c.x), abs(c.y), abs(c.z)) > 1e-4:
            print(f"[warn] {target}: bbox center still {tuple(round(v, 4) for v in c)} "
                  f"after centring.")

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
