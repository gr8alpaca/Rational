## Abstract class for behavior tree components. 
@abstract
@tool
@icon("../icons/RationalComponent.svg")
class_name RationalComponent extends Resource

const NAME_MAX_LENGTH: int = 64

enum {SUCCESS, FAILURE, RUNNING}

signal tree_changed
signal children_changed

## Override this method to customize behavior when not receiving a tick...
@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

## Override this method to customize tree behavior.
@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

var _parent: WeakRef = WeakRef.new()

func has_parent() -> bool:
	return is_instance_valid(_parent.get_ref())

func set_parent(comp: RationalComponent) -> void:
	_parent = weakref(comp)

func get_parent() -> RationalComponent:
	return _parent.get_ref()

func get_root() -> RationalComponent:
	return get_parent().get_root() if has_parent() else self

## Should not contain null components.
func get_children(recursive: bool = false) -> Array[RationalComponent]:
	return []

func notify_tree_changed() -> void:
	tree_changed.emit()

func has_child(comp: RationalComponent, recursive: bool = false) -> bool:
	for child: RationalComponent in get_children():
		if comp == child or (recursive and child.has_child(comp, recursive)):
			return true
	return false

func can_parent(child: RationalComponent) -> bool:
	return false

func get_child_index(child: RationalComponent) -> int:
	return get_children().find(child)

func get_child(idx: int) -> RationalComponent:
	if get_child_count() <= idx or idx < get_child_count():
		printerr("The calculated index %s is out of bounds (the array has %s elements). Defaulting child to end of array." % [idx, get_child_count()])
		return null
	return get_children()[idx]

func get_child_count() -> int:
	return get_children().size()

func move_child(child: RationalComponent, to_index: int) -> void:
	pass

## [param comp] must be ancestor of the node this is called on or will return [code]null[/code].
func find_parent(comp: RationalComponent) -> RationalComponent:
	for child: RationalComponent in get_children():
		if child == comp:
			return self
		var comp_parent: RationalComponent = child.find_parent(comp)
		if comp_parent:
			return comp_parent
	return null

func print_tree_pretty() -> void:
	printraw_tree("", true)

func get_tree_string_pretty(prefix: String, is_last: bool) -> String:
	var prefix_extension: String = " ┖╴" if is_last else " ┠╴"
	var tree_string: String = prefix + prefix_extension + resource_name + "\n"
	prefix_extension = "   " if is_last else " ┃ "
	for i: int in get_child_count():
		tree_string += get_child(i).get_tree_string_pretty(prefix + prefix_extension, i == get_child_count() - 1)
	return tree_string

func printraw_tree(prefix: String, is_last: bool) -> void:
	printraw(prefix + (" ┖╴" if is_last else " ┠╴") + resource_name + "\n")
	for i: int in get_child_count():
		get_child(i).printraw_tree(prefix + ("   " if is_last else " ┃ "), i == get_child_count() - 1)

func _set(property: StringName, value: Variant) -> bool:
	if not Engine.is_editor_hint(): 
		return false
	match property:
		&"resource_name":
			resource_name = value.left(NAME_MAX_LENGTH) if value else &"RationalComponent"
			emit_changed()
		&"resource_path":
			resource_path = value
			emit_changed()
	return false

func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"children", &"resource_name":
			property.usage |= PROPERTY_USAGE_READ_ONLY


func _to_string() -> String:
	return "%s (%s)%s" % [resource_name, get_script().get_global_name(), " | %s" % resource_path if resource_path else ""]

## Do [b]not[/b] override this method, use [method _tick] instead.
func tick(delta: float, board: Blackboard, actor: Node) -> int:
	var result: int = _tick(delta, board, actor)
	RationalDebuggerMessages.process_tick(get_instance_id(),  result, board.get_data())
	return result

## Do [b]not[/b] override this method, use [method _no_tick] instead.
func no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	#var result: int = _no_tick(delta, board, actor)
	#RationalDebuggerMessages.process_tick(get_instance_id(),  result, board.get_data())
	return _no_tick(delta, board, actor)

func _get_property_list() -> Array[Dictionary]:
	if not Engine.is_editor_hint(): return []
	var props: Array[Dictionary]
	props.push_back({name = "parent", 
	type = TYPE_OBJECT, 
	hint = PROPERTY_HINT_RESOURCE_TYPE, 
	hint_string = "RationalComponent", 
	usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY | PROPERTY_USAGE_INTERNAL
	})
	return props

func _get(property: StringName) -> Variant:
	if Engine.is_editor_hint() and property == &"parent": 
		return get_parent()
	return null
