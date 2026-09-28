@tool
extends EditorScenePostImport

# Switches every material in an imported glb from double-sided to back-face culled.
#
# Blender exports "Backface Culling" off as glTF doubleSided, and a double-sided material
# goes dark under a negative scale: the renderer decides which side it is looking at from
# the triangle winding, a mirror reverses that winding, so the visible face gets its normal
# flipped away from the light. Landmarks with allow_mirror are spawned with scale.x = -1
# (see Grid.merge_landmark()), so anything that can end up inside one needs this. A
# culled material doesn't have the problem - the renderer already swaps the culled side
# for a mirrored instance.
#
# Only safe on closed meshes: an open one would show holes where its back faces were.
# Hook it up per glb with import_script/path in the .import file.

func _post_import(scene : Node) -> Object:
	_make_single_sided(scene)
	return scene

func _make_single_sided(node : Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface : int in range(mesh_instance.mesh.get_surface_count()):
				_cull_back(mesh_instance.mesh.surface_get_material(surface))
				_cull_back(mesh_instance.get_surface_override_material(surface))
	for child : Node in node.get_children():
		_make_single_sided(child)

func _cull_back(material : Material) -> void:
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
