extends Node

enum State {
	MENU,
	PAUSED,
	TILE_PACK_CHOOSING,
	TILES_PLACING,
}

signal state_changed(old_state: State, new_state: State)

# change to MENU once we start in the main menu
var current_state: State = State.TILE_PACK_CHOOSING
var previous_state: State = State.MENU


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # otherwise doesnt work when game is paused
	_enter_state(current_state)


func change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	_exit_state(current_state)
	previous_state = current_state
	current_state = new_state
	_enter_state(current_state)
	state_changed.emit(previous_state, current_state)


# remember previous state for when the game is paused
func toggle_pause() -> void:
	if current_state == State.PAUSED:
		change_state(previous_state)
	else:
		change_state(State.PAUSED)

# space for sending signals to other scripts or change specific behaviour
func _enter_state(state: State) -> void:
	match state:
		State.MENU:
			pass
		State.PAUSED:
			# we could move get_tree().paused = true from pause_menu to here if needed (and to _exit_state)
			pass
		State.TILE_PACK_CHOOSING:
			pass 
		State.TILES_PLACING:
			pass


func _exit_state(state: State) -> void:
	match state:
		_:
			pass
