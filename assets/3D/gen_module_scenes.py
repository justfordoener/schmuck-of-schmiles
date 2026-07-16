"""
Turn the profile-encoded .glb files exported by export_requested_tiles.py into
Godot Module scenes.

Reads every "type_ID_edge1_edge2_...glb" in assets/3D/modules/ (see that
script's docstring for the naming scheme), copies each .glb into
book_of_tiles_godot/assets/3D/models/blockouts/blockout/, and writes a
matching "type_ID.tscn" into book_of_tiles_godot/scenes/modules/blockout/
with `module_type`, `module_id` and the `profiles` dict populated from the
encoded name.

This fully replaces whatever is currently in the two target directories --
the V2 blockout set (21 modules) supersedes the old V1 set (36 modules), so
stale files from a previous run/version are removed first.

Run as a plain python3 script (no Blender/bpy dependency) from the project
root, *after* export_requested_tiles.py:
    python3 assets/3D/gen_module_scenes.py
"""

import os
import re
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
SOURCE_DIR = os.path.join(SCRIPT_DIR, "modules")
GODOT_ROOT = os.path.join(REPO_ROOT, "book_of_tiles_godot")
GLB_TARGET_DIR = os.path.join(GODOT_ROOT, "assets", "3D", "models", "blockouts", "blockout")
SCENE_TARGET_DIR = os.path.join(GODOT_ROOT, "scenes", "modules", "blockout")

CELL_TYPE = {"hex": 0, "quad": 1, "tri": 2}   # Layout.CELL_TYPE: CORNER, EDGE, FACE
ANGLES_BY_TYPE = {
    "tri": [90, 210, 330],
    "quad": [0, 90, 180, 270],
    "hex": [0, 60, 120, 180, 240, 300],
}

# Layout.PROFILE_TYPE ordinals (EMPTY=0 sentinel, then the 13-value vocabulary).
PROFILE_TOKEN_TO_INT = {
    "air": 1, "lake": 2, "grassland": 3, "cliff": 4, "forest": 5,
    "forest-air": 6, "air-forest": 7,
    "forest-cliff": 8, "cliff-forest": 9,
    "cliff-air": 10, "air-cliff": 11,
    "lake-grassland": 12, "grassland-lake": 13,
}

NAME_RE = re.compile(r"^(tri|quad|hex)_(\d+)_(.+)\.glb$")

MODULE_SCRIPT_PATH = "res://scripts/grid/modules/module.gd"


def parse_glb_names():
    modules = []
    for fname in sorted(os.listdir(SOURCE_DIR)):
        m = NAME_RE.match(fname)
        if not m:
            continue
        kind, module_id, profile_part = m.group(1), int(m.group(2)), m.group(3)
        tokens = profile_part.split("_")
        angles = ANGLES_BY_TYPE[kind]
        if len(tokens) != len(angles):
            raise SystemExit(f"{fname}: expected {len(angles)} profile tokens for '{kind}', "
                              f"got {len(tokens)} ({tokens}).")
        for tok in tokens:
            if tok not in PROFILE_TOKEN_TO_INT:
                raise SystemExit(f"{fname}: unknown profile token '{tok}'.")
        modules.append({"kind": kind, "id": module_id, "fname": fname, "tokens": tokens,
                         "angles": angles})
    return modules


def clean_target_dirs():
    for d in (GLB_TARGET_DIR, SCENE_TARGET_DIR):
        os.makedirs(d, exist_ok=True)
        for fname in os.listdir(d):
            os.remove(os.path.join(d, fname))


def write_scene(mod):
    kind, module_id = mod["kind"], mod["id"]
    node_name = f"{kind.capitalize()}{module_id}"
    glb_name = mod["fname"]
    profiles_lines = ",\n".join(
        f"{a}: {PROFILE_TOKEN_TO_INT[t]}" for a, t in zip(mod["angles"], mod["tokens"])
    )
    tscn = f"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="{MODULE_SCRIPT_PATH}" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/3D/models/blockouts/blockout/{glb_name}" id="2_glb"]

[node name="{node_name}" type="Node3D"]
script = ExtResource("1_script")
module_type = {CELL_TYPE[kind]}
module_id = {module_id}
profiles = Dictionary[int, int]({{
{profiles_lines}
}})

[node name="{os.path.splitext(glb_name)[0]}" parent="." instance=ExtResource("2_glb")]
"""
    scene_path = os.path.join(SCENE_TARGET_DIR, f"{kind}_{module_id}.tscn")
    with open(scene_path, "w") as f:
        f.write(tscn)
    return scene_path


def main():
    modules = parse_glb_names()
    if not modules:
        raise SystemExit(f"No encoded .glb files found in {SOURCE_DIR}.")
    print(f"[info] found {len(modules)} modules to wire up")

    clean_target_dirs()

    for mod in modules:
        src_glb = os.path.join(SOURCE_DIR, mod["fname"])
        dst_glb = os.path.join(GLB_TARGET_DIR, mod["fname"])
        shutil.copy2(src_glb, dst_glb)
        scene_path = write_scene(mod)
        print(f"[ok] {mod['fname']} -> {os.path.relpath(dst_glb, REPO_ROOT)}, "
              f"{os.path.relpath(scene_path, REPO_ROOT)}")

    print(f"[done] wrote {len(modules)} module scenes to "
          f"{os.path.relpath(SCENE_TARGET_DIR, REPO_ROOT)}")


if __name__ == "__main__":
    main()
