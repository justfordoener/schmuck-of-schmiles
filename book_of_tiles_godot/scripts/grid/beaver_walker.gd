class_name BeaverWalker extends Node3D

# A beaver patrolling the rim of the corner module it was parented to (see
# PlacementManager._try_spawn_beaver), so it circles the lodge sitting at that module's centre.
# Zoom the camera in on it and it stops, turns to face the player, waves, then picks its route
# back up where it left off.
#
# Everything here is in module-local space, which is what makes the path trivial: a corner
# module is a hexagon centred on its own origin, spanning +-CELL_HEIGHT/2 on Y with its walkable
# top surface at the upper end. Measured from the module mesh, it is pointy-top in local space -
# its six edge points sit at Layout.CELL_SIZE (~0.577) on +-Z and four diagonals, while its flat
# sides face +-X at the apothem, CELL_SIZE * sqrt(3)/2 (~0.5). Do not swap those two: a loop
# sized against the wrong one hangs the beaver off the rim. The hexagon is six-fold symmetric,
# so the loop rotating with its tile is invisible.

# WALKING is the only state that moves; the other three only turn on the spot.
enum State { WALKING, TURNING_TO_CAMERA, WAVING, TURNING_BACK }

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
@export var wave_clip_name : StringName = &"WAVE"

@export_group("Waving")
# World distance from the active camera below which the beaver notices the player. Chosen
# against the camera rig's real reach: the ShapeCast3D stops it short of the ground, so the
# camera sits ~2.0 away when fully zoomed in, ~3.3 at three-quarter zoom, ~6.2 at half and
# ~19.5 zoomed right out. 5.0 therefore means "past half zoom, and pointed at this tile" -
# distance is used rather than the zoom level alone so that zooming in across the map does
# not set every beaver on the board waving at nobody.
@export var wave_distance : float = 5.0
# The beaver only re-arms once the camera passes back out through wave_distance * this. The
# gap is what stops a camera sitting near the threshold from retriggering every frame, and it
# is what makes this one wave per approach rather than a loop.
@export var wave_release_factor : float = 1.3
# How closely it has to be aimed before it starts waving, or counts as back on course.
@export var aim_tolerance_degrees : float = 6.0
# Cross-fade between the walk cycle and the wave, in seconds. A hard cut between the two reads
# as a glitch; this is short enough not to eat the start of the wave.
@export var anim_blend : float = 0.18

var _waypoints : Array[Vector3] = []
var _target : int = 0
var _player : AnimationPlayer
var _walk_clip : String = ""
# Empty when the model has no wave clip distinct from the walk clip - the beaver then just
# patrols and never reacts to the camera.
var _wave_clip : String = ""
var _state : State = State.WALKING
# False from the moment a wave starts until the camera has withdrawn past the release radius.
var _armed : bool = true
var _wave_timeout : float = 0.0

func _ready() -> void:
	_build_path()
	# Each beaver enters its loop at a different corner and a different point in the walk
	# cycle, so two lodges side by side don't march in lockstep.
	_target = randi() % _waypoints.size()
	position = _waypoints[(_target + _waypoints.size() - 1) % _waypoints.size()]
	_face(_waypoints[_target] - position, TAU) # TAU always exceeds the largest possible turn, so this snaps
	_resolve_clips()
	if _walk_clip != "":
		_player.play(_walk_clip)
		_player.seek(randf() * _player.get_animation(_walk_clip).length, true)

func _build_path() -> void:
	_waypoints.clear()
	var walk_height : float = Layout.CELL_HEIGHT / 2.0
	for i in range(6):
		var angle : float = deg_to_rad(path_angle_offset + i * 60.0)
		_waypoints.append(Vector3(path_radius * cos(angle), walk_height, path_radius * sin(angle)))

# Finds the model's clips and fixes their loop modes. Both are set explicitly because the
# Animation resources are shared by every beaver on the board - only the AnimationPlayer node
# is per-instance - so one instance leaving a loop mode wrong strands all the others. The wave
# in particular must never loop: the state machine waits for it to end.
func _resolve_clips() -> void:
	# Resolved by search rather than by a fixed path: the AnimationPlayer is created by the
	# glTF importer inside the imported scene, so its position depends on the model, not on us.
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_warning("BeaverWalker: the beaver model has no AnimationPlayer - it will slide instead of walk.")
		return
	var available : PackedStringArray = _player.get_animation_list()
	if available.is_empty():
		push_warning("BeaverWalker: the beaver model carries no animations.")
		return

	_walk_clip = String(clip_name) if _player.has_animation(String(clip_name)) else available[0]
	_wave_clip = String(wave_clip_name) if _player.has_animation(String(wave_clip_name)) else ""
	# If the fallback above landed on the wave clip as the walk cycle, waving is off: the next
	# line would set that shared resource looping, and the wave would then never report itself
	# finished.
	if _wave_clip == _walk_clip:
		_wave_clip = ""

	# glTF clips import with looping off, so the walk cycle would play once and freeze.
	_player.get_animation(_walk_clip).loop_mode = Animation.LOOP_LINEAR
	if _wave_clip != "":
		_player.get_animation(_wave_clip).loop_mode = Animation.LOOP_NONE

func _process(delta : float) -> void:
	if _waypoints.is_empty():
		return
	var camera_distance : float = _distance_to_camera()
	# Checked in every state, so zooming back out during the approach re-arms it too.
	if camera_distance > wave_distance * wave_release_factor:
		_armed = true

	match _state:
		State.WALKING:
			_process_walking(delta, camera_distance)
		State.TURNING_TO_CAMERA:
			_process_turning_to_camera(delta, camera_distance)
		State.WAVING:
			_process_waving(delta)
		State.TURNING_BACK:
			_process_turning_back(delta)

func _process_walking(delta : float, camera_distance : float) -> void:
	if _armed and _wave_clip != "" and camera_distance <= wave_distance:
		_armed = false
		_state = State.TURNING_TO_CAMERA
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

func _process_turning_to_camera(delta : float, camera_distance : float) -> void:
	# Zoomed back out mid-turn: drop it and get going again rather than wave at nobody.
	if camera_distance > wave_distance * wave_release_factor:
		_state = State.TURNING_BACK
		return
	var to_camera : Vector3 = _direction_to_camera()
	if to_camera.is_zero_approx():
		_state = State.TURNING_BACK
		return
	_face(to_camera, turn_speed * delta)
	if _is_aimed_at(to_camera):
		_state = State.WAVING
		# Backstop for the clip-ended test in _process_waving, in case the shared Animation
		# resource has been left looping - without it the beaver would wave forever.
		_wave_timeout = _player.get_animation(_wave_clip).length + 0.25
		_player.play(_wave_clip, anim_blend)

func _process_waving(delta : float) -> void:
	_wave_timeout -= delta
	# current_animation empties out when a non-looping clip reaches its end.
	if _wave_timeout <= 0.0 or _player.current_animation != _wave_clip:
		_state = State.TURNING_BACK
		_player.play(_walk_clip, anim_blend)

func _process_turning_back(delta : float) -> void:
	var to_goal : Vector3 = _waypoints[_target] - position
	to_goal.y = 0.0
	if to_goal.is_zero_approx() or _is_aimed_at(to_goal):
		_state = State.WALKING
		return
	_face(to_goal, turn_speed * delta)

# INF when there is no camera, or when the beaver is behind it. The rig's min_zoom is negative,
# so the camera can travel through its own pivot and end up looking away - close by distance
# but with the beaver off behind the lens.
func _distance_to_camera() -> float:
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(global_position):
		return INF
	return camera.global_position.distance_to(global_position)

# Horizontal direction to the camera in the parent module's space, which is the space the
# waypoints and `position` live in - so it stays correct however the tile was rotated when placed.
func _direction_to_camera() -> Vector3:
	var camera : Camera3D = get_viewport().get_camera_3d()
	var parent := get_parent() as Node3D
	if camera == null or parent == null:
		return Vector3.ZERO
	var direction : Vector3 = parent.to_local(camera.global_position) - position
	direction.y = 0.0
	return direction

func _is_aimed_at(direction : Vector3) -> bool:
	if direction.is_zero_approx():
		return true
	var offset : float = angle_difference(rotation.y, atan2(direction.x, direction.z))
	return absf(offset) <= deg_to_rad(aim_tolerance_degrees)

# Aims the model's +Z at `direction`, turning at most `max_step` radians. The rig's rest pose
# faces +Z (tail at -Z, toes at +Z), which is the opposite of what look_at() assumes, so the
# angle is taken directly instead.
func _face(direction : Vector3, max_step : float) -> void:
	if direction.is_zero_approx():
		return
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), max_step)
