## Abstract class for behavior tree components. 
@abstract
@tool
@icon("../icons/RationalComponent.svg")
class_name RationalComponent extends Resource

const NAME_MAX_LENGTH: int = 64

enum {SUCCESS, FAILURE, RUNNING}

signal children_changed
signal tree_changed

var parent_id: int = 0

# May remove/reimplement in the futurej.
var node_id: int = 0

## Override this method to customize behavior when not receiving a tick...
@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

## Override this method to customize tree behavior.
@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

## Returns [code]true[/code] if [member parent_id] references a valid [RationalComponent].
func has_parent() -> bool:
	return instance_from_id(parent_id) != null 

## Internal Use Only. Sets [member parent_id] to the instance ID of [param comp].
func set_parent(comp: RationalComponent) -> void:
	assert(comp != self, "RationalComponent cannot parent itself.")
	parent_id = comp.get_instance_id() if comp else 0
	notify_property_list_changed()

## Returns this component's parent component, or [code]null[/code] if the component doesn't have a parent.
func get_parent() -> RationalComponent:
	return instance_from_id(parent_id)

## Returns the root component of the tree this component is in, or itself if the component doesn't have a parent.
func get_root() -> RationalComponent:
	return get_parent().get_root() if has_parent() else self

## Returns the instance ID of the root component returned by [method get_root].
func get_root_id() -> int:
	return get_root().get_instance_id()

## Returns [code]true[/code] if this component has no parent.
func is_root() -> bool:
	return not has_parent()


func set_node(node: Node) -> void:
	node_id = node.get_instance_id() if node else 0

## Should not contain [code]null[/code] components. [param recursive] will return all components that share this ancestor.
func get_children(recursive: bool = false) -> Array[RationalComponent]:
	var children: Array[RationalComponent]
	return children

## Emits [member tree_changed].
func notify_tree_changed() -> void:
	tree_changed.emit()
	emit_changed()

## Returns [code]true[/code] if [param comp] is in
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
	if not (-get_child_count() <= idx and idx < get_child_count()):
		printerr("The calculated index %s is out of bounds (the array has %s elements)." % [idx, get_child_count()])
		return null
	return get_children()[idx]

func get_child_count() -> int:
	return get_children().size()

func get_index() -> int:
	return get_parent().get_child_index(self) if has_parent() else -1

func move_child(child: RationalComponent, to_index: int) -> void:
	pass

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
	pass
	#match property.name:
		#&"children", &"resource_name":
			#property.usage |= PROPERTY_USAGE_READ_ONLY

## Do [b]not[/b] override this method, use [method _tick] instead.
func tick(delta: float, board: Blackboard, actor: Node) -> int:
	var result: int = _tick(delta, board, actor)
	RationalDebuggerMessages.process_tick(get_instance_id(),  result, board.get_data())
	return result

## Do [b]not[/b] override this method, use [method _no_tick] instead.
func no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	var result: int = _no_tick(delta, board, actor)
	#RationalDebuggerMessages.process_tick(get_instance_id(),  result, board.get_data())
	return _no_tick(delta, board, actor)

func _get_property_list() -> Array[Dictionary]:
	if not Engine.is_editor_hint(): return []
	return Array([{
	name = "parent",
	type = TYPE_INT,
	hint = PROPERTY_HINT_OBJECT_ID, 
	hint_string = (get_parent().get_script().get_global_name() if has_parent() else "RationalComponent"), 
	usage = (PROPERTY_USAGE_EDITOR * int(has_parent())) | PROPERTY_USAGE_READ_ONLY
	}
	], TYPE_DICTIONARY, "", null)

func _get(property: StringName) -> Variant:
	if not Engine.is_editor_hint(): return null
	if property == &"parent": return parent_id
	return null

#region Print

func _to_string() -> String:
	return "%s (%s)%s" % [resource_name, get_script().get_global_name(), " | %s" % resource_path if resource_path else ""]

func print_tree() -> void:
	_tree_print("", true)

func get_tree_string_pretty(prefix: String, is_last: bool) -> String:
	var tree_string: String = prefix + (" ┖╴" if is_last else " ┠╴") + resource_name + "\n"
	var prefix_extension: String = "   " if is_last else " ┃ "
	for i: int in get_child_count():
		tree_string += get_child(i).get_tree_string_pretty(prefix + prefix_extension, i == get_child_count() - 1)
	return tree_string

func _tree_print(prefix: String = "", is_last: bool = true) -> void:
	print(prefix + (" ┖╴" if is_last else " ┠╴") + resource_name)
	for i: int in get_child_count():
		get_child(i)._tree_print(prefix + ("   " if is_last else " ┃ "), i == get_child_count() - 1)

#endregion Print
