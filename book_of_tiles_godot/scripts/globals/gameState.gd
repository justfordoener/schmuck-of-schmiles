extends Node

enum State {
	MENU,
	PAUSED,
	TILE_PACK_CHOOSING,
	TILE_CHOOSING,
	TILES_PLACING,
}

signal state_changed(old_state: State, new_state: State)

# change to MENU once we start in the main menu scene
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


# pause the game (remembers previous state to go back to when resuming)
func toggle_pause() -> void:
	if current_state == State.PAUSED:
		change_state(previous_state)
	else:
		change_state(State.PAUSED)

# space for sending signals to other scripts or change specific behaviour
func _enter_state(state: State) -> void:
	match state:
		State.MENU:
			#print("menu")
			pass
		State.PAUSED:
			get_tree().paused = true
			#print("paused")
		State.TILE_PACK_CHOOSING:
			#print("Choosing Pack") 
			pass
		State.TILE_CHOOSING:
			#print("Choosing Tile")
			pass
		State.TILES_PLACING:
			#print("Placing")
			pass

# as above, but for exiting instead of entering a state
func _exit_state(state: State) -> void:
	match state:
		State.PAUSED:
			get_tree().paused = false
		_:
			pass
