@tool
@icon("../icons/Blackboard.svg")
class_name Blackboard extends Resource

const DEFAULT: String = "default"
const SHARED: String = "shared"

## Use [method set_value], and [method get_value] to access.
@export var board_data: Dictionary = {}: set = set_board_data

## [Blackboard] for use between multiple blackboards.
@export var global_data: Blackboard: set = set_global_data

var _data: Dictionary



func GET(key: Variant) -> Variant:
	return get_value(key)

func get_value(key: Variant, default: Variant = null, section: Variant = DEFAULT) -> Variant:
	return _data.get(section, {}).get(key, default)

func set_value(key: Variant, value: Variant, section: Variant = DEFAULT) -> void:
	_data.get_or_add(section, {})[key] = value

func has(key: Variant, section: Variant = DEFAULT) -> bool:
	return _data.get(section, {}).has(key)

func erase(key: String, section: Variant = DEFAULT) -> bool:
	if has(key, section):
		return _data.get(section, {}).erase(key)
	return false

func get_global(key: Variant, default: Variant = null) -> Variant:
	return get_value(key, default, SHARED)

func set_global(key: Variant, value: Variant = null) -> void:
	set_value(key, value, SHARED)

func get_local(key: Variant, default: Variant = null) -> Variant:
	return get_value(key, default)

func set_local(key: Variant, value: Variant = null) -> void:
	set_value(key, value)

func set_board_data(val: Dictionary) -> void:
	board_data = val
	_data[DEFAULT] = board_data

func set_global_data(val: Blackboard) -> void:
	global_data = val
	_data[SHARED] = global_data.board_data if board_data else {}
	if global_data and not Engine.is_editor_hint():
		global_data.add_board_data(self)

func set_actor(object: Node) -> void:
	assert(object != null, "Cannot set NULL actor!")
	set_local("actor", object)

func get_actor() -> Node:
	return get_local("actor") if get_local("actor") is Node else null

func add_board_data(board: Blackboard) -> void:
	if not board or board.get_instance_id() in _data: return
	_data[board.get_instance_id()] = board.board_data

func get_board_list() -> Array[Blackboard]:
	var result: Array[Blackboard]
	for key in _data:
		if not key is int or not instance_from_id(key) is Blackboard: continue
		result.push_back(instance_from_id(key))
	return result

func actor_get_value(actor: Node, key: Variant, default: Variant = null) -> Variant:
	return actor_get_board(actor).get(key, default)

func actor_get_board(actor: Node) -> Dictionary:
	for board: Blackboard in get_board_list():
		if board.get_actor() == actor:
			return board.board_data
	return {}

func get_data() -> Dictionary:
	return _data
