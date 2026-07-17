@tool
@icon("../icons/Blackboard.svg")
class_name Blackboard extends Resource

const MAX_DATA_DEPTH: int = 4

const DEFAULT: String = "default"
const SHARED: String = "shared"

## Use [method set_value], and [method get_value] to access.
@export var board_data: Dictionary: set = set_board_data

## [Blackboard] for use between multiple blackboards.
@export var global_data: Blackboard: set = set_global_data

var _data: Dictionary[Variant, Dictionary]

## If [code]true[/code] [RationalTree]s and [RationalComponent]s using 
## this board will send messages to [RationalDebugHandle].
var debug_active: bool

func _init() -> void:
	set_board_data({})

func get_section(section: Variant = DEFAULT) -> Dictionary:
	return _data.get(section, {})

func set_section(section: Variant, value: Dictionary = {}) -> bool:
	return _data.set(section, value)

func get_section_list() -> Array:
	return _data.keys()

func get_section_values() -> Array[Dictionary]:
	return Array(_data.values(), TYPE_DICTIONARY, &"", null)

func GET(key: Variant, default: Variant = null, section: Variant = DEFAULT) -> Variant:
	return get_value(key, default, section)

func SET(key: Variant, value: Variant, section: Variant = DEFAULT) -> void:
	set_value(key, value, section)

func get_value(key: Variant, default: Variant = null, section: Variant = DEFAULT) -> Variant:
	return _data.get(section, {}).get(key, default)

func set_value(key: Variant, value: Variant, section: Variant = DEFAULT) -> void:
	_data.get_or_add(section, {})[key] = value

func has(key: Variant, section: Variant = DEFAULT) -> bool:
	return _data.get(section, {}).has(key)

func erase(key: Variant, section: Variant = DEFAULT) -> bool:
	return has(key, section) and _data.get(section, {}).erase(key)

func keys(section: Variant = DEFAULT) -> Array:
	return _data.get(section, {}).keys()

func values(section: Variant = DEFAULT) -> Array:
	return _data.get(section, {}).values()

func get_global(key: Variant, default: Variant = null) -> Variant:
	return get_value(key, default, SHARED)

func set_global(key: Variant, value: Variant = null) -> void:
	set_value(key, value, SHARED)

func get_local(key: Variant, default: Variant = null) -> Variant:
	return board_data.get(key, default)

func set_local(key: Variant, value: Variant = null) -> void:
	board_data.set(key, value)

func set_board_data(val: Dictionary) -> void:
	board_data = val
	_data.set(get_instance_id(), board_data)

func set_global_data(val: Blackboard) -> void:
	global_data = val
	_data.set(SHARED, global_data.board_data if global_data else {})
	if global_data and not Engine.is_editor_hint():
		global_data.add_board(get_instance_id(), board_data)

func set_actor(object: Node) -> void:
	assert(object != null, "Cannot set NULL actor!")
	set_local("actor", object)

func get_actor() -> Node:
	return get_local("actor") if get_local("actor") is Node else null

func add_board(id: int, data: Dictionary) -> void:
	assert(is_instance_id_valid(id))
	_data.set(id, data)

func get_board_list() -> Array[Blackboard]:
	var result: Array[Blackboard]
	for key in _data:
		if not key is int or not instance_from_id(key) is Blackboard: continue
		result.push_back(instance_from_id(key))
	return result

func get_board_data(id: int) -> Dictionary:
	return _data.get(id, {})

func actor_get_value(actor: Node, key: Variant, default: Variant = null) -> Variant:
	return actor_get_board(actor).get(key, default)

func actor_get_board(actor: Node) -> Dictionary:
	for board: Blackboard in get_board_list():
		if board.get_actor() == actor:
			return board.board_data
	return {}

## Returns data [Dictionary] for Rational debugger use.
func get_debug_data() -> Dictionary:
	if not global_data:
		pass
	return {
		id = get_instance_id(),
		data = global_data.get_data() if global_data else format_debug_data(_data),
	}


func format_debug_data(value: Variant, depth: int = 0) -> Variant:
	if depth > MAX_DATA_DEPTH: return str(value)
	
	match typeof(value):
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in value.keys():
				result[format_debug_data(key, depth + 1)] = format_debug_data(value[key], depth + 1)
			return result
		
		TYPE_ARRAY:
			return value.map(format_debug_data.bind(depth + 1))
		
		TYPE_OBJECT when value != null:
			if value.has_method("get_debug_data"):
				return format_debug_data(value.get_debug_data(), depth + 1)
			
			var result: Dictionary = {
				"id" : value.get_instance_id(),
				"class" : value.get_class(),
				"type" : value.get_script().get_global_name() if value.get_script() else &"",
				}
			
			if value is Node:
				result.name = value.get_name()
				if value.is_inside_tree():
					result.path = String(value.get_path())
			elif value is Resource:
				result.name = value.get_name()
				result.path = value.get_path()
			
			return result
	
	return value
