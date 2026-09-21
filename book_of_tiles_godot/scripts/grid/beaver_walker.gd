class_name BeaverWalker extends Node3D

# A beaver patrolling the rim of the corner module it was parented to (see
# PlacementManager._try_spawn_beaver), so it circles the lodge sitting at that module's centre.
#
# Everything here is in module-local space, which is what makes the path trivial: a corner
# module is a hexagon centred on its own origin, spanning +-CELL_HEIGHT/2 on Y with its walkable
# top surface at the upper end. Measured from the module mesh, it is pointy-top in local space -
# its six edge points sit at Layout.CELL_SIZE (~0.577) on +-Z and four diagonals, while its flat
# sides face +-X at the apothem, CELL_SIZE * sqrt(3)/2 (~0.5). Do not swap those two: a loop
# sized against the wrong one hangs the beaver off the rim. The hexagon is six-fold symmetric,
# so the loop rotating with its tile is invisible.

# Distance from the module centre to each waypoint - so, with the default offset below, the
# circumradius of the beaver's own hexagon. Squeezed from both sides and there is not much room:
# the loop's apothem (path_radius * sqrt(3)/2) plus the beaver's half-width has to stay inside
# the module's 0.5 apothem, while the lodge reaches ~0.36 out along the diagonals, so a tighter
# loop walks the beaver through its own house.
@export var path_radius : float = 0.50
# 30 puts the waypoints on the hexagon's six edge points, 0 on the midpoints of its sides - the
# two readings of "roughly along the edge points". Anything else just phases the loop.
@export var path_angle_offset : float = 30.0
@export var speed : float = 0.1
# Radians per second the beaver may swing round by. Low enough that corners read as turns
# rather than snaps, high enough to finish one inside a hexagon edge.
@export var turn_speed : float = 5.0
@export var clip_name : StringName = &"WALKING"

var _waypoints : Array[Vector3] = []
var _target : int = 0
var _player : AnimationPlayer

func _ready() -> void:
	_build_path()
	# Each beaver enters its loop at a different corner and a different point in the walk
	# cycle, so two lodges side by side don't march in lockstep.
	_target = randi() % _waypoints.size()
	position = _waypoints[(_target + _waypoints.size() - 1) % _waypoints.size()]
	_face(_waypoints[_target] - position, TAU) # TAU always exceeds the largest possible turn, so this snaps
	_start_animation()

func _build_path() -> void:
	_waypoints.clear()
	var walk_height : float = Layout.CELL_HEIGHT / 2.0
	for i in range(6):
		var angle : float = deg_to_rad(path_angle_offset + i * 60.0)
		_waypoints.append(Vector3(path_radius * cos(angle), walk_height, path_radius * sin(angle)))

func _start_animation() -> void:
	# Resolved by search rather than by a fixed path: the AnimationPlayer is created by the
	# glTF importer inside the imported scene, so its position depends on the model, not on us.
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_warning("BeaverWalker: the beaver model has no AnimationPlayer - it will slide instead of walk.")
		return
	var clip : String = String(clip_name)
	if not _player.has_animation(clip):
		var available : PackedStringArray = _player.get_animation_list()
		if available.is_empty():
			push_warning("BeaverWalker: the beaver model carries no animations.")
			return
		clip = available[0]
	# glTF clips import with looping off, so the walk cycle would play once and freeze.
	_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_player.play(clip)
	_player.seek(randf() * _player.get_animation(clip).length, true)

func _process(delta : float) -> void:
	if _waypoints.is_empty():
		return
	var to_goal : Vector3 = _waypoints[_target] - position
	to_goal.y = 0.0
	var distance : float = to_goal.length()
	if distance <= speed * delta:
		position = _waypoints[_target]
		_target = (_target + 1) % _waypoints.size()
		return
	position += (to_goal / distance) * speed * delta
	_face(to_goal, turn_speed * delta)

# Aims the model's +Z at `direction`, turning at most `max_step` radians. The rig's rest pose
# faces +Z (tail at -Z, toes at +Z), which is the opposite of what look_at() assumes, so the
# angle is taken directly instead.
func _face(direction : Vector3, max_step : float) -> void:
	if direction.is_zero_approx():
		return
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), max_step)
