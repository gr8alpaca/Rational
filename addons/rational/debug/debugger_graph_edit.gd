@tool
extends GraphEdit

const DebuggerGraphNode := preload("debugger_graph_node.gd")
const TreePositioner := preload("../editor/tree_positioner.gd")

const Util := preload("../util.gd")

const PROGRESS_SHIFT: int = 50

const INACTIVE_COLOR: Color = DebuggerGraphNode.Style.NORMAL_COLOR
const RUNNING_COLOR: Color = DebuggerGraphNode.Style.RUNNING_COLOR
const SUCCESS_COLOR: Color = DebuggerGraphNode.Style.SUCCESS_COLOR
const FAILURE_COLOR: Color = DebuggerGraphNode.Style.FAILURE_COLOR

var icon_data: Dictionary[StringName, Texture2D]

var layout_button: Button
var updating: bool

var horizontal_layout: bool = false:
	set(value):
		if horizontal_layout == value: return
		horizontal_layout = value

var active_tree: Dictionary: set = set_active_tree

var active_components: PackedInt64Array

func _init() -> void:
	custom_minimum_size = Vector2(100.0, 300.0)
	show_arrange_button = false
	minimap_enabled = false
	
	
	# Put in ready?
	layout_button = get_menu_hbox().get_child(-1).duplicate(0) as Button
	layout_button.show()
	update_layout_button()
	get_menu_hbox().add_child(layout_button)
	layout_button.pressed.connect(toggle_layout)


func has_id(id: int) -> bool:
	return has_node(str(id))

func get_id(id: int) -> DebuggerGraphNode:
	return get_node_or_null(str(id))

func add_graph_node(comp: Dictionary, parent_name: StringName = &"") -> void:
	if not comp_is_valid(comp) or has_id(comp.get("id", -1)): return
	var node: DebuggerGraphNode = DebuggerGraphNode.new()
	node.name = str(comp.get("id", "-1"))
	if parent_name == &"":
		node.set_meta(&"root", true)
	node.set_title_text(comp.get("name", "<NULL>"))
	node.set_icon(icon_data.get(comp.get("class", ""), null))
	node.set_slot(0, not node.has_meta(&"root"), -1, Color.WHITE, not comp.get("children", []).is_empty(), -1, Color.WHITE)
	add_child(node, true)
	connect_node(parent_name, 0, node.name, 0)
	
	for child: Dictionary in comp.get("children", []):
		add_graph_node(child, node.name)

func update() -> void:
	if updating: return
	updating = true
	
	clear()
	add_graph_node(active_tree.get("root", {}))
	arrange()
	
	updating = false

func arrange() -> void:
	var tree_positioner: TreePositioner = add_positioner(get_root_node())
	tree_positioner.calculate_tree()
	tree_positioner.apply_position()

func add_positioner(node: DebuggerGraphNode) -> TreePositioner:
	var positioner: TreePositioner = TreePositioner.new(node)
	for child: DebuggerGraphNode in node_get_children(node.name):
		positioner.children.push_back(add_positioner(child))
	return positioner

func set_active_tree(val: Dictionary) -> void:
	if active_tree == val: return
	active_tree = val

func clear() -> void:
	clear_connections()
	for child: DebuggerGraphNode in get_graph_nodes():
		remove_child(child)
		child.free()

func get_graph_nodes() -> Array[DebuggerGraphNode]:
	var result: Array[DebuggerGraphNode]
	result.assign(get_children().filter(func(node: Node) -> bool: return node is DebuggerGraphNode))
	return result

func get_active_id() -> int:
	return active_tree.get("id", 0)

func get_root_node() -> DebuggerGraphNode:
	return get_id(active_tree.get("root", {}).get("id", -1))

func node_get_children(node: StringName) -> Array[DebuggerGraphNode]:
	var result: Array[DebuggerGraphNode]
	for con: Dictionary in get_connection_list_from_node(node):
		if con.from_node != node or not has_node(con.to_node): continue
		result.push_back(get_node(con.to_node))
	return result

func node_get_port_positon(node: DebuggerGraphNode, output: bool) -> Vector2:
	if not node: return Vector2.ZERO
	return node.position + (node.get_output_position() if output else node.get_input_position()) * zoom

func set_icon_data(_icon_data: Dictionary[StringName, Texture2D]) -> void:
	icon_data = _icon_data

func update_layout_button() -> void:
	layout_button.icon = EditorInterface.get_editor_theme().get_icon(&"MoveRight" if horizontal_layout else &"MoveDown", &"EditorIcons")
	layout_button.tooltip_text = "Switch to Vertical layout" if horizontal_layout else "Switch to Horizontal layout"

func toggle_layout() -> void:
	horizontal_layout = not horizontal_layout

func comp_is_valid(comp: Dictionary) -> bool:
	return comp and comp.get("id", "") is int and comp.id != -1

func get_elbow_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array
	
	points.push_back(from_position)
	
	var mid_position := ((to_position + from_position) / 2).round()
	if horizontal_layout:
		points.push_back(Vector2(mid_position.x, from_position.y))
		points.push_back(Vector2(mid_position.x, to_position.y))
	else:
		points.push_back(Vector2(from_position.x, mid_position.y))
		points.push_back(Vector2(to_position.x, mid_position.y))
	
	points.push_back(to_position)
	
	return points

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	const VECS: PackedVector2Array = [Vector2(-9999999, -9999999), Vector2(-9999999, -9999999)]
	return VECS
