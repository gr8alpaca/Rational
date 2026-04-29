@tool
extends GraphEdit

const Util := preload("../util.gd")

const RationalGraphNode := preload("graph_node.gd")
const CreatePopup = preload("component_dialog.gd") 
const Menu := preload("popup_menu.gd")

const TreeDisplay := preload("tree_display.gd")
const Selection:= preload("selection.gd")
const TreePositionComponent := preload("tree_positioner.gd")

const DRAG_MIN_DISTANCE_SQUARED: float = 10.0 ** 2
const PROGRESS_SHIFT: int = 50
const PORT_RANGE: float = 20
const CONNECTING_SNAP_MOD_INCREASE: float = 2.5
const DUPLICATE_OFFSET: Vector2 = Vector2(25.0, 25.0)
const SIBLING_DISTANCE_MIN: float = 32.0
const PARENT_DISTANCE_MIN: float = 240.0

@export var popup: CreatePopup
@export var tree_display: TreeDisplay

var layout_button: Button

var menu: Menu

var updating_graph: bool = false
var arranging_nodes: bool = false
var restoring_state: bool = false

var horizontal_layout: bool = false:
	set(value):
		if updating_graph or arranging_nodes or restoring_state:
			return
		if horizontal_layout == value:
			return
		horizontal_layout = value
		update_layout_button()
		save_current_orphans()
		arrange_graph_nodes()
		queue_redraw.call_deferred()

var active_root: RootData: set = set_active_root

var graph_states: Dictionary[RootData, Dictionary]

var is_dragging_connection: bool = false
var connection_start_position: Vector2
var connecting_node: RationalGraphNode
var connecting_output: bool = false

var create_popup_start_position: Vector2

var is_moving_node: bool = false

var is_restoring_state: bool = false

var reset_dragged_nodes: bool = false

var shortcuts: Dictionary[Shortcut, Callable]

var cache: RefCounted = Util.get_cache()
var selection: Selection = Util.get_selection()
var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()


## Node selected with right click when creating a menu.
var selected_node: RationalGraphNode

## [member menu] is being shown for [member tree_display].
var is_tree_display_menu_active: bool = false



var clipboard: Array[RationalComponent]

func _ready() -> void:
	selection.selected_component.connect(_on_selected_component)
	cache.edited_tree_changed.connect(set_active_root)
	
	custom_minimum_size = Vector2(200, 200) * EditorInterface.get_editor_scale()
	
	layout_button = get_menu_hbox().get_child(-1).duplicate(0)
	layout_button.show()
	layout_button.toggle_mode = false
	update_layout_button()
	get_menu_hbox().add_child(layout_button)
	layout_button.pressed.connect(toggle_layout)
	
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	
	connection_drag_started.connect(_on_connection_drag_started)
	connection_request.connect(_on_connection_request)
	connection_drag_ended.connect(_on_connection_drag_ended)
	
	cut_nodes_request.connect(cut)
	
	copy_nodes_request.connect(copy)
	paste_nodes_request.connect(paste)
	duplicate_nodes_request.connect(duplicate_components)
	delete_nodes_request.connect(_on_delete_nodes_request)
	
	node_selected.connect(_on_node_selected)
	node_deselected.connect(_on_node_deselected)
	
	begin_node_move.connect(_on_begin_node_move)
	end_node_move.connect(_on_end_node_move)
	
	popup_request.connect(_on_popup_request)
	
	menu = Menu.new()
	add_child(menu, false, Node.INTERNAL_MODE_FRONT)
	menu.id_pressed.connect(_on_menu_id_pressed)
	menu.popup_hide.connect(clear_selected_node, CONNECT_DEFERRED)
	
	tree_display.menu_item_selected.connect(_on_tree_display_menu_selected)
	tree_display.item_edited.connect(_on_tree_display_item_edited)
	tree_display.request_reparent.connect(comp_reparent)
	tree_display.item_mouse_selected.connect(_on_tree_display_mouse_selected)
	

func _on_child_entered_tree(node: Node) -> void:
	if node is RationalGraphNode: 
		node.component_child_added.connect(_on_component_child_added, CONNECT_APPEND_SOURCE_OBJECT)
		node.component_child_removed.connect(_on_component_child_removed, CONNECT_APPEND_SOURCE_OBJECT)
		node.component_children_changed.connect(_on_component_children_changed, CONNECT_APPEND_SOURCE_OBJECT)
		node.dragged.connect(_on_node_dragged, CONNECT_APPEND_SOURCE_OBJECT)
		node.transform_changed.connect(queue_redraw, CONNECT_DEFERRED)
		node.request_rename.connect(rename_comp)

func _on_child_exiting_tree(node: Node) -> void:
	if node is RationalGraphNode:
		node.component_child_added.disconnect(_on_component_child_added)
		node.component_child_removed.disconnect(_on_component_child_removed)
		node.component_children_changed.disconnect(_on_component_children_changed)
		node.dragged.disconnect(_on_node_dragged)
		node.transform_changed.disconnect(queue_redraw)
		node.request_rename.disconnect(rename_comp)
		selection.remove_component(node.component)

func node_connect(from: String, to: String) -> Error:
	if not has_node(from) or not has_node(to):
		return ERR_DOES_NOT_EXIST
	if is_node_connected(from, 0, to, 0):
		return OK
	return connect_node(from, 0, to, 0, false)

func node_disconnect(from: StringName, to: StringName) -> void:
	if not is_node_connected(from, 0, to, 0): return
	disconnect_node(from, 0, to, 0)

#region Menu

func _on_popup_request(at_position: Vector2) -> void:
	if not active_root:
		return
	
	if is_moving_node:
		cancel_drag()
		return
	
	if disconnect_hovered_port():
		return
	
	selected_node = get_node_at_position(at_position)
	
	if selected_node:
		selected_node.selected = true
		
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			set_selected(selected_node)
	
	if selected_node or Input.is_key_pressed(KEY_SHIFT):
		menu.popup_at(get_menu_options(selected_node), get_screen_position() + at_position)
		return
	
	show_quick_create_popup(get_screen_position() + at_position)

func _on_tree_display_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT: return
	selected_node = comp_get_graph_node(tree_display.item_get_comp(tree_display.get_item_at_position(mouse_position)))
	is_tree_display_menu_active = true
	menu.popup_at(get_menu_options(selected_node), tree_display.get_screen_position() + mouse_position)

func get_menu_options(node: RationalGraphNode = null) -> int:
	var selected_nodes:= get_selected_nodes()
	
	if not node:
		return (Menu.ITEMS_HERE ^ (Menu.ITEM_PASTE_HERE * int(not can_paste()))) \
				^ (Menu.ITEM_MOVE_NODE_HERE * int(selected_nodes.is_empty()))
	
	var options: int = Menu.ITEMS_DEFAULT | ( Menu.ITEM_PASTE * int(can_paste()))
	var parent: RationalComponent = comp_get_parent(node.component)
	
	options |= int(node.component is Composite) * (Menu.ITEM_ADD_CHILD | Menu.ITEM_INSTANTIATE_CHILD)
	options |= Menu.ITEM_PASTE_AS_SIBLING  * int(parent and not parent is Decorator and can_paste())
	options |= Menu.ITEM_ARRANGE_SUBTREE * mini(node_get_children(node).size(), 1)
	# Tree Display options
	options |= (Menu.ITEM_SHOW_IN_EDITOR | Menu.ITEM_MOVE_DOWN | Menu.ITEM_MOVE_UP) * int(is_tree_display_menu_active)
	
	return options

func _on_menu_id_pressed(id: int) -> void:
	match id:
		Menu.ITEM_SHOW_IN_EDITOR:
			select_and_center(get_selected_comp())
		Menu.ITEM_MOVE_UP:
			shift_selected(true)
		Menu.ITEM_MOVE_DOWN:
			shift_selected(false)
		Menu.ITEM_ADD_CHILD:
			add_child_component()
		Menu.ITEM_INSTANTIATE_CHILD:
			instantiate_child()
		Menu.ITEM_INSTANTIATE_HERE:
			instantiate_here()
		Menu.ITEM_CUT:
			cut()
		Menu.ITEM_COPY:
			copy()
		Menu.ITEM_PASTE:
			paste()
		Menu.ITEM_PASTE_AS_SIBLING:
			paste_as_sibling()
		Menu.ITEM_PASTE_HERE:
			paste_here()
		Menu.ITEM_DUPLICATE:
			duplicate_components()
		Menu.ITEM_RENAME when is_tree_display_menu_active:
			tree_display.rename()
		Menu.ITEM_RENAME:
			rename()
		Menu.ITEM_CHANGE_TYPE:
			change_type()
		Menu.ITEM_SAVE_AS_ROOT:
			save_as_root()
		Menu.ITEM_ARRANGE_SUBTREE:
			arrange_subtree()
		Menu.ITEM_DOCUMENTATION:
			open_documentation()
		Menu.ITEM_DELETE:
			delete()
		Menu.ITEM_ADD_NODE_HERE:
			add_node_here()
		Menu.ITEM_MOVE_NODE_HERE:
			move_nodes_here(get_selected_nodes())

#region TreeDisplay Menu


func _on_tree_display_menu_selected(id: int, comp: RationalComponent) -> void:
	selected_node = comp_get_graph_node(comp)
	_on_menu_id_pressed(id)
	clear_selected_node.call_deferred()

func _on_tree_display_item_edited() -> void:
	rename_comp(tree_display.item_get_comp(tree_display.get_edited()), tree_display.item_get_name(tree_display.get_edited()))

#endregion TreeDisplay Menu

#endregion Menu


#region shortcuts

func move_nodes_here(nodes: Array[RationalGraphNode]) -> void:
	if not nodes: return
	var offset_delta: Vector2 = local_to_offset(Vector2(menu.position) - get_screen_position()) - nodes_get_rect(nodes).get_center()
	
	# Move all nodes first to prevent parent index issues based on the order of nodes moved.
	for node: RationalGraphNode in nodes:
		node.position_offset += offset_delta
	
	for node: RationalGraphNode in nodes:
		move_component_undo_redo(node.position_offset - offset_delta, node.position_offset, node, "Move Component(s) to Position" )


func select_and_center(comp: RationalComponent) -> void:
	if not comp or not comp_has_node(comp): return
	set_selected(comp_get_graph_node(comp))
	center_selection()

## Creates new [RationalComponent] from script at [param script_path].
func script_path_instance_comp(script_path: String) -> RationalComponent:
	if not script_path: return null
	var script: GDScript = ResourceLoader.load(script_path, "GDScript")
	var comp: RationalComponent = script.new()
	comp.set_name(script.get_global_name())
	return comp

func add_child_from_path(path: String, parent: RationalComponent = null, offset: Vector2 = Vector2.ZERO) -> void:
	var comp: RationalComponent = script_path_instance_comp(path)
	if not comp: return
	if not create_action("Create Component", UndoRedo.MERGE_DISABLE, comp_in_tree(parent)):
		return
	if parent:
		undo_redo.add_undo_method(parent, &"remove_child", comp)
		undo_redo_add_node_positions(parent)
		undo_redo.add_do_method(parent, &"add_child", comp)
	else:
		undo_redo.add_do_method(self, &"add_comp", comp)
		
	undo_redo.add_undo_method(self, &"comp_remove_node", comp)
	if offset:
		undo_redo.add_do_method(self, &"comp_set_offset", comp, offset)
	
	commit(true)

func instantiate_child() -> void:
	pass

func instantiate_here() -> void:
	pass

func add_child_component() -> void:
	var selected: RationalComponent = get_selected_comp()
	if not selected: return
	EditorInterface.popup_create_dialog(add_child_from_path.bind(selected), &"RationalComponent", "", "Add Child Component", [])

func cut() -> void:
	if is_dragging_connection: return
	copy()
	delete("Cut Component(s)")

func delete(action_name: String = "Remove Component(s)") -> void:
	if is_dragging_connection: return
	var components: Array[RationalComponent] = get_selected_components()
	components.sort_custom(func(a: RationalComponent, b: RationalComponent) -> bool: return comp_get_index(a) < comp_get_index(b))
	var root_changed: bool = components.any(comp_in_tree)
	
	if not create_action(action_name, UndoRedo.MERGE_ALL, root_changed):
		return
	for comp: RationalComponent in components:
		delete_comp_undo_redo(comp, action_name)
	commit()

func comp_get_position_offset(comp: RationalComponent) -> Vector2:
	return comp_get_graph_node(comp).position_offset if comp_has_node(comp) else Vector2.ZERO

## Creates UndoRedo action to completely remove [param comp] from parent and free node.
func delete_comp_undo_redo(comp: RationalComponent, action_name: String = "Remove Component(s)" ) -> void:
	if not comp: return
	var parent: RationalComponent = comp_get_parent(comp)
	var children: Array[RationalComponent] = comp.get_children()
	
	undo_redo.add_undo_method(self, &"add_comp", comp, parent, parent.get_child_index(comp) if parent else -1)
	
	if parent:
		undo_redo.add_do_method(parent, &"remove_child", comp)
	
	undo_redo.add_do_method(self, &"comp_remove_node", comp)
	if comp_has_node(comp):
		undo_redo.add_undo_method(self, &"comp_set_offset", comp, comp_get_graph_node(comp).position_offset)
	
	if selection.is_selected(comp):
		undo_redo.add_undo_method(selection, &"add_component", comp)
		undo_redo.add_do_method(selection, &"remove_component", comp)


func copy() -> void:
	if is_dragging_connection: return
	clipboard_copy(get_selected_components())

func paste_to_parent(parent: RationalComponent, action_name: String = "") -> void:
	if not parent is Composite: return
	
	if not action_name:
		action_name = "Paste Component(s) as Child of %s" % parent.resource_name
	
	if not create_action(action_name):
		return
	
	undo_redo_add_node_positions(parent)
	for comp: RationalComponent in get_top_clipboard_components().duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL):
		undo_redo.add_undo_method(parent, &"remove_child", comp)
		undo_redo.add_undo_method(self, &"comp_remove_tree", comp)
		undo_redo.add_do_method(parent, &"add_child", comp)
	
	undo_redo.add_do_method(self, &"comp_arrange_tree", parent)
	
	commit()

func paste() -> void:
	if is_dragging_connection or not can_paste(): 
		return
	
	if not has_selected_node():
		paste_here(true)
		return
	
	paste_to_parent(get_selected_comp())

func paste_as_sibling() -> void:
	var sibling: RationalComponent = get_selected_comp()
	if not sibling: return
	paste_to_parent(comp_get_parent(sibling), "Paste Component(s) as Sibling of %s" % sibling.resource_name)

func paste_here(ignore_menu: bool = false) -> void:
	if is_dragging_connection or not can_paste(): 
		return
	
	var top_nodes: Array[RationalGraphNode]
	for comp in get_top_clipboard_components():
		if not comp_has_node(comp): 
			print("Comp doesn't have node: %s" % comp)
			continue
		top_nodes.push_back(comp_get_graph_node(comp))
	
	var target_center: Vector2 = local_to_offset((size/2.0) if ignore_menu else (Vector2(menu.position) - get_screen_position()))
	var offset_delta: Vector2 = target_center - nodes_get_rect(top_nodes).get_center()
	
	for node: RationalGraphNode in top_nodes:
		var comp: RationalComponent = node.component.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
		create_action("Paste Component(s) at Position")
		undo_redo.add_undo_method(self, &"comp_remove_tree", comp)
		undo_redo.add_undo_method(selection, &"remove_component", comp)
		undo_redo.add_do_method(self, &"add_comp", comp)
		undo_redo.add_do_method(self, &"comp_arrange", comp)
		undo_redo.add_do_method(self, &"comp_set_tree_offset", comp, node.position_offset + offset_delta)
		undo_redo.add_do_method(selection, &"add_component", comp)
		commit()

func duplicate_components() -> void:
	if is_dragging_connection or not has_selected_node():
		return
	
	var selected_components: Array[RationalComponent] = selection.get_top_selected_components()
	var root_change: bool = not selected_components.all(comp_is_orphan)
	
	if not create_action("Duplicate Component(s)", UndoRedo.MERGE_ALL, root_change):
		return
	
	for selected_comp: RationalComponent in selected_components:
		var parent: RationalComponent = comp_get_parent(selected_comp)
		if parent is Decorator:
			continue
		
		var comp: RationalComponent = selected_comp.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
		if parent:
			undo_redo.add_undo_method(parent, &"remove_child", comp)
			undo_redo.add_do_method(parent, &"add_child", comp, parent.get_child_index(selected_comp))
		
		undo_redo.add_undo_method(self, &"comp_remove_tree", comp)
		undo_redo.add_undo_method(selection, &"remove_component", comp)
		
		if not parent:
			undo_redo.add_do_method(self, &"add_comp", comp)
			undo_redo.add_do_method(self, &"comp_arrange", comp)
			undo_redo.add_do_method(self, &"comp_set_tree_offset", comp, comp_get_position_offset(selected_comp) + DUPLICATE_OFFSET)
		
		undo_redo.add_do_method(selection, &"add_component", comp)
	
	if root_change:
		undo_redo_add_node_positions()
		undo_redo.add_do_method(self, &"call_deferred", &"arrange_graph_nodes",)
	
	commit()


func add_node_here() -> void:
	var offset: Vector2 = local_to_offset(Vector2(menu.position) - get_screen_position())
	EditorInterface.popup_create_dialog(add_child_from_path.bind(null, offset), &"RationalComponent", "", "Add Component", [])


## Adds all nodes positions to current UndoRedo action.
func undo_redo_add_node_positions(parent: RationalComponent = null, as_undo: bool = true) -> void:
	for comp: RationalComponent in (get_components() if not parent else parent.get_children(true)):
		if as_undo:
			undo_redo.add_undo_method(self, &"comp_set_offset", comp, comp_get_offset(comp))
		else:
			undo_redo.add_do_method(self, &"comp_set_offset", comp, comp_get_offset(comp))

## Prompts to change type.
func change_type() -> void:
	if is_dragging_connection or not has_selected_node(): return
	EditorInterface.popup_create_dialog(comp_change_script.bind(get_selected_comp()), &"RationalComponent", "", "Change Component Type", [])

func save_as_root() -> void:
	if is_dragging_connection: return
	pass

func rename() -> void:
	if is_dragging_connection or not has_selected_node(): return
	get_selected().rename()


## Creates UndoRedo action if name is not already.
func rename_comp(comp: RationalComponent, new_name: String) -> void:
	if not comp or comp.resource_name == new_name: return
	create_action("Rename Component", UndoRedo.MERGE_DISABLE, comp_in_tree(comp))
	undo_redo.add_undo_property(comp, &"resource_name", comp.resource_name)
	undo_redo.add_do_property(comp, &"resource_name", new_name)
	commit(true)

func zoom_in() -> void:
	zoom *= zoom_step

func zoom_out() -> void:
	zoom /= zoom_step

func center_selection() -> void:
	if has_selected_node():
		center_offset(nodes_get_rect(get_selected_nodes()).get_center() * zoom)
	elif active_root:
		center_offset(comp_get_graph_node(get_root_component()).get_rect().get_center() * zoom)

func frame_selection() -> void:
	if not has_selected_node(): return
	frame_rect(nodes_get_rect(get_selected_nodes()))

func frame_rect(rect: Rect2) -> void:
	zoom = minf(size.x/rect.size.x, size.y/rect.size.y)/ zoom_step
	scroll_offset = rect.get_center() * zoom - size / 2.0

func toggle_grid() -> void:
	show_grid = !show_grid

func toggle_snap() -> void:
	snapping_enabled = !snapping_enabled

func arrange_subtree() -> void:
	if is_dragging_connection or not has_selected_node(): return
	node_arrange_children(get_selected())

func open_documentation() -> void:
	if is_dragging_connection or not has_selected_node(): return
	EditorInterface.get_script_editor().goto_help("class_name:%s" % get_selected().get_component_class())


#endregion shortcuts

func get_node_at_position(at_position: Vector2) -> RationalGraphNode:
	for node: RationalGraphNode in get_graph_nodes():
		if node.get_rect().has_point(at_position):
			return node
	return null

## Returns the index based on [param node]'s [code]position_offset[/code].
func node_get_index(node: RationalGraphNode) -> int:
	if not node: return -1
	return node_get_children_sorted(node_get_parent(node.name)).find(node) if node_is_parented(node.name) else -1

func comp_get_index(comp: RationalComponent) -> int:
	var parent:= comp_get_parent(comp)
	return parent.get_child_index(comp) if parent else 0


func node_get_children_sorted(parent: RationalGraphNode) -> Array[RationalGraphNode]:
	var children : Array[RationalGraphNode] = node_get_children(parent)
	children.sort_custom(sort_position)
	return children

func sort_position(node_a: RationalGraphNode, node_b: RationalGraphNode) -> bool:
	return node_a.position_offset[int(horizontal_layout)] < node_b.position_offset[int(horizontal_layout)]



func show_quick_create_popup(at_position: Vector2) -> void:
	popup.open(at_position, add_child_from_path.bind(null, local_to_offset(at_position - global_position)))

func place_node_at(node: RationalGraphNode, offset: Vector2) -> void:
	# TODO: Add check for collision and adjust
	node.position_offset = offset

func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	connecting_node = get_node(String(from_node))
	connecting_output = is_output
	connection_start_position = get_node_port_position(connecting_node, is_output) * zoom
	is_dragging_connection = true
	accept_event()
	queue_redraw()

func _on_connection_drag_ended() -> void:
	connecting_node = null
	is_dragging_connection = false
	queue_redraw()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not from_port == to_port and from_port == 0:
		printerr("Attempting to connect graph node port != 0.")
		return
	
	var current_parent: RationalGraphNode = node_get_parent(to_node)
	var current_parent_comp: RationalComponent = current_parent.component if current_parent else null
	var from: RationalGraphNode = get_node(String(from_node))
	var to: RationalGraphNode = get_node(String(to_node))
	var index: int = -1
	
	if not from.component is Decorator:
		var from_children:= node_get_children(from)
		from_children.push_back(to)
		from_children.sort_custom(sort_position)
		index = from_children.find(to)
	
	comp_reparent(to.component, current_parent_comp, from.component, index)


func comp_reparent(comp: RationalComponent,  current_parent: RationalComponent, target_parent: RationalComponent, index: int = -1) -> void:
	if not comp or (not current_parent and not target_parent): return
	var is_changed: bool = comp_in_tree(current_parent) or comp_in_tree(target_parent)
	
	if not create_action("Reparent Component(s)", UndoRedo.MERGE_ALL, is_changed):
		return
	
	if target_parent is Decorator and 0 < target_parent.get_child_count():
		undo_redo.add_undo_method(target_parent, &"add_child", target_parent.get_child(0))
	elif target_parent:
		undo_redo.add_undo_method(target_parent, &"remove_child", comp)
	
	if current_parent:
		undo_redo.add_undo_method(current_parent, &"add_child", comp, current_parent.get_child_index(comp))
		undo_redo.add_do_method(current_parent, &"remove_child", comp)
	
	if target_parent:
		undo_redo.add_do_method(target_parent, &"add_child", comp, index)
	
	commit()


func comp_reparent_undo_redo(comp: RationalComponent,  current_parent: RationalComponent, target_parent: RationalComponent, index: int = -1) -> void:
	if not comp or (not current_parent and not target_parent): return
	
	var is_changed: bool = comp_in_tree(current_parent) or comp_in_tree(target_parent)
	if not create_action("Reparent Component(s)", UndoRedo.MERGE_ALL, is_changed):
		return
	
	if target_parent is Decorator and 0 < target_parent.get_child_count():
		undo_redo.add_undo_method(target_parent, &"add_child", target_parent.get_child(0))
	undo_redo.add_undo_method(self, &"comp_reparent", target_parent, current_parent, current_parent.get_child_index(comp) if current_parent else -1)
	undo_redo.add_do_method(self, &"comp_reparent", current_parent, target_parent, index)
	
	commit()

func comp_can_change_script(script_path: String, comp: RationalComponent) -> bool:
	return script_path and comp and comp.get_script().get_path() != script_path and ResourceLoader.exists(script_path, "Script")

func comp_change_script(script_path: String, comp: RationalComponent) -> void:
	if not comp_can_change_script(script_path, comp) or not create_action("Change Type of Component(s)", UndoRedo.MERGE_DISABLE, comp_in_tree(comp)): 
		return
	
	var comp_properties: Dictionary[StringName, Variant] = comp_get_properties(comp)
	undo_redo.add_undo_method(comp, &"set_script", comp.get_script())
	undo_redo.add_undo_method(self, &"comp_set_properties", comp, comp_properties)
	
	undo_redo.add_do_method(comp, &"set_script", ResourceLoader.load(script_path, "Script"))
	undo_redo.add_do_method(self, &"comp_set_properties", comp, comp_properties)
	
	commit()

## Returns all properties and current values from [param comp]'s script.
func comp_get_properties(comp: RationalComponent) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for property: Dictionary in (comp.get_property_list() if comp else []):
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: 
			result[property.name] = comp.get(property.name)
	return result

## Returns sets any property specified in [param properties] if different to current value.
func comp_set_properties(comp: RationalComponent, properties: Dictionary[StringName, Variant]) -> void:
	for prop: StringName in properties:
		if comp.get(prop) == properties[prop]: continue
		comp.set(prop, properties[prop])


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if is_dragging_connection: return
	delete()

func node_get_comp(node_name: String) -> RationalComponent:
	return get_node(node_name).component if has_node(node_name) else null

func node_is_parented(node: String) -> bool:
	return node_get_parent(node) != null

func node_get_parent(node: String) -> RationalGraphNode:
	if not has_node(node): return null
	for con: Dictionary in get_connection_list_from_node(node):
		if con.to_node == node:
			return get_node(String(con.from_node))
	return null


func update_graph() -> void:
	if active_root and not active_root.is_loaded():
		active_root.loaded.connect(update_graph, CONNECT_ONE_SHOT)
		return
	
	if updating_graph:
		return
	
	updating_graph = true
	
	clear()
	
	if get_root_component():
	
		populate_tree()
		
		if can_restore_state():
			restore_graph_state(graph_states.get(active_root, {}))
		else:
			arrange_graph_nodes()
		
		queue_redraw.call_deferred()
	
	updating_graph = false


func populate_tree() -> void:
	add_node(get_root_component())
	
	for comp: RationalComponent in get_active_root_orphans():
		add_node(comp)
	

## Recursively adds all children.
func add_node(comp: RationalComponent, add_child_immediately: bool = true, recursive: bool = true) -> RationalGraphNode:
	if not comp: return
	
	if comp_has_node(comp):
		var node:= comp_get_graph_node(comp)
		node.selected = selection.is_selected(comp)
		return node
	
	var node: RationalGraphNode = RationalGraphNode.new(horizontal_layout)
	node.root = comp == get_root_component()
	node.set_component(comp)
	
	if add_child_immediately:
		add_child(node)
	
	node.selected = selection.is_selected(comp)
	
	if recursive and not node.is_inherited():
		for child: RationalComponent in comp.get_children():
			var child_node:= add_node(child)
			node_connect(node.name, child_node.name)
	
	return node

func comp_get_parent(comp: RationalComponent) -> RationalComponent:
	if not comp: return null
	for graph_comp: RationalComponent in get_components():
		if graph_comp and graph_comp.has_child(comp):
			return graph_comp
	return null

func delete_node(node_name: String) -> void:
	if not has_node(node_name): return
	var node: RationalGraphNode = get_node(node_name)
	
	if node.component == get_root_component():
		return
	
	for con: Dictionary in get_connection_list_from_node(node_name):
		node_disconnect(con.from_node, con.to_node)
		if con.to_node == node_name:
			var parent: RationalComponent = node_get_comp(con.from_node)
			parent.remove_child(node.component)
	
	remove_child(node)
	node.free()

## Adds a new/existing component.
func add_comp(comp: RationalComponent, parent: RationalComponent = null, index: int = -1) -> void:
	if not comp: return
	var node: RationalGraphNode = add_node(comp)
	if parent:
		parent.add_child(comp, index)

## Removes component from the graph entirely. Looks for parent component to remove.
func remove_component(comp: RationalComponent) -> void:
	if comp == get_root_component(): return
	
	var node:= comp_get_graph_node(comp)
	if node:
		remove_child(node)
		node.queue_free()


func comp_remove_node(comp: RationalComponent) -> void:
	if not comp or not comp_has_node(comp): return
	var node: RationalGraphNode = comp_get_graph_node(comp)
	for child: RationalComponent in comp.get_children():
		node_disconnect(comp_name(comp), comp_name(child))
	remove_child(node)
	node.free()

func comp_remove_tree(comp: RationalComponent) -> void:
	if not comp: return
	comp_remove_node(comp)
	for child: RationalComponent in comp.get_children():
		comp_remove_tree(child)

## Arranges all children of [param node].
func node_arrange(node: RationalGraphNode) -> void:
	if not node: return
	node_update_positioner(node)
	node.positioner.calculate_relative()
	node.arrange()



## Only updates [param node]'s positioner and all children of [param node].
func node_update_positioner(node: RationalGraphNode) -> void:
	var children: Array[RationalGraphNode] = []
	children.assign(node.component.get_children().filter(comp_has_node).map(comp_get_graph_node))
	node.positioner.children.resize(children.size())
	for i: int in children.size():
		children[i].positioner.parent = node.positioner
		node.positioner.children[i] = children[i].positioner
		node_update_positioner(children[i])

func comp_arrange(comp: RationalComponent) -> void:
	node_arrange(comp_get_graph_node(comp))

## Arranges all ancestors of [param comp].
func comp_arrange_tree(comp: RationalComponent) -> void:
	if not comp or not comp_has_node(comp): return
	var start_offset: Vector2 = comp_get_offset(comp)
	comp_arrange(comp)
	comp_set_tree_offset(comp, start_offset)

func node_get_children(node: RationalGraphNode) -> Array[RationalGraphNode]:
	if not node or not get_connection_count(node.name, 0): return []
	var result: Array[RationalGraphNode] = []
	for con: Dictionary in get_connection_list_from_node(node.name):
		if con.from_node == node.name and has_node(String(con.to_node)):
			result.push_back(get_node(String(con.to_node)))
	return result

func center_offset(offset: Vector2) -> void:
	scroll_offset = offset - size / 2.0


func _on_component_child_added(comp: RationalComponent, node: RationalGraphNode) -> void:
	var node_exists: bool = comp_has_node(comp)
	var child: RationalGraphNode = comp_get_graph_node(comp) if node_exists else add_node(comp)
	node_connect(node.name, child.name)
	if not node_exists:
		node_place_child(node, child)


func _on_component_child_removed(comp: RationalComponent, node: RationalGraphNode) -> void:
	node_disconnect(node.name, comp_name(comp))

func _on_component_children_changed(node: RationalGraphNode) -> void:
	pass
	#node_verify_children_position(node)

## Only time this comes up is when Component order is changed outside of editor. => Is this even needed?
func node_verify_children_position(node: RationalGraphNode) -> void:
	var comp_nodes: Array[RationalGraphNode]
	for n: RationalGraphNode in node.component.get_children().map(comp_get_graph_node).filter(func(x: RationalGraphNode) -> bool: return x != null):
		if not n: continue
		comp_nodes.push_back(n)
	
	var axis: int = int(horizontal_layout)
	for i: int in maxi(0, comp_nodes.size() - 1):
		if comp_nodes[i + 1].position_offset[axis] < comp_nodes[i].position_offset[axis] + comp_nodes[i].size[axis] + SIBLING_DISTANCE_MIN:
			comp_nodes[i + 1].position_offset[axis] = comp_nodes[i].position_offset[axis] + comp_nodes[i].size[axis] + SIBLING_DISTANCE_MIN


func node_arrange_children(node: RationalGraphNode) -> void:
	var original_offset: Vector2 = node.position_offset
	node_arrange(node)
	node.shift_tree(original_offset - node.position_offset)


func node_place_child(parent: RationalGraphNode, child: RationalGraphNode) -> void:
	if not parent or not child: return
	comp_arrange_tree(parent.component)
	

func create_tree_node(comp: RationalComponent, parent: TreePositionComponent = null) -> TreePositionComponent:
	var tree_node: TreePositionComponent = TreePositionComponent.new(comp_get_graph_node(comp), parent)
	for child: RationalComponent in comp.get_children():
		var child_tree_node := create_tree_node(child, tree_node)
		tree_node.children.push_back(child_tree_node)
	return tree_node

func arrange_graph_nodes() -> void:
	if arranging_nodes or not active_root: return
	
	arranging_nodes = true
	
	propagate_call(&"set_horizontal", [horizontal_layout])
	
	comp_arrange(get_root_component())
	
	set_deferred(&"arranging_nodes", false)


func place_nodes(node: TreePositionComponent) -> void:
	node.item.position_offset = node.get_position()
	for child: TreePositionComponent in node.children:
		place_nodes(child)

#func get_tree_rect(node: TreePositionComponent) -> Rect2:
	#var rect: Rect2 = Rect2(node.item.position_offset, node.item.size)
	#for child in node.children:
		#rect = rect.merge(get_tree_rect(child))
	#return rect

#func get_tree_end(tree_node: TreePositionComponent) -> float:
	#var result: float = tree_node.x + tree_node.item.layout_size
	#for child in tree_node.children:
		#result = maxf(result, get_tree_end(child))
	#return result

func comp_name(comp: RationalComponent) -> String:
	return str(comp.get_instance_id()) if comp else "INVALID_COMP"

func comp_has_node(comp: RationalComponent) -> bool:
	return has_node(comp_name(comp))

func comp_get_graph_node(comp: RationalComponent) -> RationalGraphNode:
	return get_node_or_null(comp_name(comp))

func clear() -> void:
	clear_connections()
	for child: RationalGraphNode in get_graph_nodes():
		remove_child(child)
		child.free()


func set_active_root(val: RootData) -> void:
		if active_root == val: return
		
		if active_root:
			active_root.closed.disconnect(close_active_root)
			graph_states[active_root] = get_graph_state()
		
		active_root = val
		
		if active_root:
			active_root.closed.connect(close_active_root)
		
		tree_display.set_active_root(active_root)
		update_graph()

func close_active_root() -> void:
	graph_states.erase(active_root)

	active_root = null


func get_graph_state() -> Dictionary:
	var node_data: Dictionary
	for node: RationalGraphNode in get_graph_nodes():
		node_data[node.component] = {
			position_offset = node.position_offset,
			comp = node.component,
			}
	
	return {
		zoom = zoom,
		scroll_offset = scroll_offset,
		horizontal = horizontal_layout,
		orphans = get_orphan_components(),
		nodes = node_data,
	}


func restore_graph_state(state: Dictionary) -> void:
	if state.is_empty() or restoring_state: return
	
	restoring_state = true
	
	var is_different_layout: bool = state.get("horizontal", !horizontal_layout) != horizontal_layout
	
	zoom = state.get("zoom", 1.0)
	scroll_offset = state.get("scroll_offset", Vector2.ZERO)
	
	for node: RationalGraphNode in get_graph_nodes():
		node.position_offset = state.get("nodes", {}).get(node.component, {}).get("position_offset", node.position_offset)
	
	restoring_state = false


func can_restore_state() -> bool:
	return active_root and graph_states.has(active_root) and is_node_ready()

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

## Returns all RationalGraphNode children shown on graph.
func get_graph_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for child in get_children():
		if child is RationalGraphNode:
			result.push_back(child)
	return result

## Returns all RationalGraphNode children not connected to the root.
func get_orphan_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for node: RationalGraphNode in get_graph_nodes():
		if node.component == get_root_component() or node_is_parented(node.name): continue
		result.push_back(node)
	return result

## Returns all components shown on graph.
func get_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for node in get_graph_nodes():
		result.push_back(node.component)
	return result

func comp_in_tree(comp: RationalComponent) -> bool:
	return comp and get_root_component() and get_root_component().has_child(comp, true)

func comp_is_orphan(comp: RationalComponent) -> bool:
	return not comp_in_tree(comp)

func comp_is_valid(comp: RationalComponent) -> bool:
	return is_instance_valid(comp)

func get_orphan_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for node: RationalGraphNode in get_orphan_nodes():
		if get_root_component().has_child(node.component, true): continue
		result.push_back(node.component)
	return result

func get_active_root_orphans() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for orphan: RationalComponent in graph_states.get(active_root, {}).get("orphans", []):
		result.push_back(orphan)
	return result

func save_current_orphans() -> void:
	if not active_root: return
	graph_states.get_or_add(active_root, {})["orphans"] = get_orphan_components()

func get_port_range_squared(mod: float = 1.0) -> float:
	return (mod * PORT_RANGE)  ** 2

func _is_in_input_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	in_node.is_left_port_hovered = (not is_dragging_connection or (connecting_output and is_connection_valid(connecting_node, in_node))) and 	\
		(mouse_position).distance_squared_to(get_node_port_position(in_node, false)) < 		\
		get_port_range_squared(1.0 + CONNECTING_SNAP_MOD_INCREASE * float(is_dragging_connection))
	return in_node.is_left_port_hovered

func _is_in_output_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	in_node.is_right_port_hovered = (not is_dragging_connection or (not connecting_output and is_connection_valid(in_node, connecting_node))) and 	\
		mouse_position.distance_squared_to(get_node_port_position(in_node, true) ) < 			\
		get_port_range_squared(1.0 + CONNECTING_SNAP_MOD_INCREASE * float(is_dragging_connection))
	return in_node.is_right_port_hovered

func get_node_port_position(node: GraphNode, is_output: bool) -> Vector2:
	if is_output:
		if horizontal_layout:
			return node.position_offset + Vector2(node.size.x, node.size.y / 2.0) - scroll_offset / zoom
		else:
			return node.position_offset + Vector2(node.size.x / 2.0, node.size.y) - scroll_offset / zoom
	elif horizontal_layout:
		return node.position_offset + Vector2(0, node.size.y / 2.0) - scroll_offset / zoom
	
	return node.position_offset + Vector2(node.size.x / 2.0, 0) - scroll_offset / zoom


func comp_get_offset(comp: RationalComponent) -> Vector2:
	return Vector2() if not comp or not comp_has_node(comp) else comp_get_graph_node(comp).position_offset

## Moves [param comp] node to [param position_offset]. Children/Parent are unaffected.
func comp_set_offset(comp: RationalComponent, position_offset: Vector2) -> void:
	if not comp_has_node(comp): return
	comp_get_graph_node(comp).position_offset = position_offset

## Moves [param comp] node to [param position_offset] and shifts all children by the same amount.
func comp_set_tree_offset(comp: RationalComponent, position_offset: Vector2) -> void:
	if not comp or not comp_has_node(comp): return
	comp_move_tree(comp, position_offset - comp_get_graph_node(comp).position_offset)

## Shifts [param comp] node position offset by [param position_offset] and all ancestors to [param comp].
func comp_move_tree(comp: RationalComponent, offset_delta: Vector2) -> void:
	if not comp or not offset_delta: return
	var node: RationalGraphNode = comp_get_graph_node(comp)
	if comp_has_node(comp):
		comp_get_graph_node(comp).position_offset += offset_delta
	for child in comp.get_children():
		comp_move_tree(child, offset_delta)

func show_dialog(title: String, message: String, buttons:PackedStringArray = PackedStringArray(["OK"]), callable: Callable = Callable().unbind(1)) -> void:
	DisplayServer.dialog_show(title, message, buttons, callable)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_dragging_connection:
			queue_redraw()
	
	if not event.is_pressed() or event.is_echo():
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			var node: RationalGraphNode = get_selected()
			if node and node.get_titlebar_rect().has_point(event.position):
				accept_event()
				node.rename()
	
	
	elif event is InputEventKey:
		match event.keycode:
			
			KEY_R:
				printt(Rect2(scroll_offset/zoom, size/zoom))
			
			KEY_T:
				active_root.root.print_tree_pretty()
			
			KEY_L:
				var focus_owner: Control = get_viewport().gui_get_focus_owner()
				print(focus_owner.component if focus_owner is RationalGraphNode else focus_owner)
			
			KEY_B:
				printt("Selected \t(%d)" % get_selected_components().size() , get_selected_components())
			
			KEY_C when not event.ctrl_pressed:
				printt("Clipboard \t(%d)" % get_clipboard().size(), get_clipboard())
			
			KEY_B when event.shift_pressed:
					for child in get_children():
						if not child is GraphFrame: continue
						remove_child(child)
						child.free()
			
			KEY_Y:
				var tops:= get_top_clipboard_components()
				printt("CLipboard Tops (%d)" % tops.size(), tops)
			
			KEY_P:
				graph_states.clear()


func _draw() -> void:
	if not active_root: return
	const LINE_COLOR := Color.WHITE
	var line_width: float = connection_lines_thickness * zoom
	for c: Dictionary in get_connection_list():
		var output_port_position: Vector2 = node_get_port_positon(get_node(String(c.from_node)), true)
		var input_port_position: Vector2 = node_get_port_positon(get_node(String(c.to_node)), false)
		var line := get_elbow_connection_line(output_port_position, input_port_position)
		draw_polyline(line, LINE_COLOR, line_width, connection_lines_antialiased)
	
	if is_dragging_connection:
		var end_position: Vector2 = get_local_mouse_position()
		var port: Dictionary = get_closest_port_to_position(end_position)
		
		# Check if ports are of opposite type.
		if (port.left != !connecting_output) and \
				is_connection_valid(connecting_node if connecting_output else port.node, port.node if connecting_output else connecting_node) and \
				get_port_distance_squared(port.node, end_position) < get_port_range_squared(CONNECTING_SNAP_MOD_INCREASE):
			end_position = node_get_port_positon(port.node, not port.left)
		
		draw_polyline(get_elbow_connection_line(connection_start_position, end_position), LINE_COLOR, line_width, connection_lines_antialiased)
	
	if is_moving_node:
		update_dragged_nodes()

func is_connection_valid(from_node: RationalGraphNode, to_node: RationalGraphNode) -> bool:
	return from_node.component.can_parent(to_node.component)

func _is_node_hover_valid(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> bool:
	return node_get_comp(from_node).can_parent(node_get_comp(to_node))

func update_dragged_nodes() -> void:
	for node: RationalGraphNode in get_selected_nodes():
		var children: Array[RationalGraphNode] = node_get_children(node_get_parent(node.name))
		
		if children.size() < 2:
			continue
		
		for child: RationalGraphNode in children:
			child.is_drawing_index = true
			child.current_index = node_get_index(child)

func cancel_drag() -> void:
	if not is_moving_node: return
	reset_dragged_nodes = true
	var release_event:= InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(release_event)

func _on_begin_node_move() -> void:
	is_moving_node = true

func _on_end_node_move() -> void:
	is_moving_node = false
	for node: RationalGraphNode in get_graph_nodes():
		node.is_drawing_index = false
	queue_redraw.call_deferred()
	reset_dragged_nodes = false

func _on_node_dragged(from: Vector2, to: Vector2, node: RationalGraphNode) -> void:
	# Prevent little drags creating an action.
	if from.distance_squared_to(to) < DRAG_MIN_DISTANCE_SQUARED / zoom:
		node.position_offset = from
		return
	
	if reset_dragged_nodes:
		node.position_offset = from
		return
	
	move_component_undo_redo(from, to , node)

## Should be called after move in order to get parent/child index correctly.
func move_component_undo_redo(from: Vector2, to: Vector2, node: RationalGraphNode, action_name: String = "Move Component(s)") -> void:
	if not node: return
	var parent: RationalGraphNode = node_get_parent(node.name)
	var from_index: int = parent.component.get_child_index(node.component) if parent else -1
	var to_index: int = node_get_index(node)
	var root_changed: bool = parent and to_index != from_index
	
	if not create_action("Move Component(s)", UndoRedo.MERGE_ALL, root_changed):
		return
	undo_redo.add_undo_method(self, &"comp_set_offset", node.component, from)
	undo_redo.add_do_method(self, &"comp_set_offset", node.component, to)
	if root_changed:
		undo_redo.add_undo_method(parent.component, &"move_child", node.component, from_index)
		undo_redo.add_do_method(parent.component, &"move_child", node.component, to_index)
		parent.component.move_child(node.component, to_index)
	
	commit(false)

## Shift selected nodes up/down. Used for Menu.ITEM_MOVE_UP/Menu.ITEM_MOVE_DOWN
func shift_selected(upward: bool) -> void:
	var parents: Array[RationalComponent]
	for comp: RationalComponent in get_selected_components():
		var p: RationalComponent = comp_get_parent(comp)
		if p and not p in parents:
			parents.push_back(p)
	
	var idx_shift: int = (1 + -2 * int(upward))
	
	for parent: RationalComponent in parents:
		if selection.is_selected(parent.get_child((parent.get_child_count() - 1) * int(not upward))):
			continue
		
		for i: int in parent.get_child_count():
			var idx: int = i if upward else parent.get_child_count() - 1 - i
			if selection.is_selected(parent.get_child(idx)):
				comp_move_child(parent, idx, idx + idx_shift)

func comp_move_child(parent: RationalComponent, from_idx: int, to_idx: int) -> void:
	if not parent or from_idx == to_idx: return
	create_action("Move Component(s) in Parent")
	undo_redo.add_undo_method(parent, &"move_child", parent.get_child(from_idx), from_idx)
	undo_redo.add_do_method(parent, &"move_child", parent.get_child(from_idx), to_idx)
	commit()

#region UndoRedo

## Returns [code]true[/code] if action was created and returns [code]false[/code] otherwise.
func create_action(action_name: String, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, root_changed: bool  = true) -> bool:
	if not active_root: 
		return false
	
	if not active_root.closed.is_connected(undo_redo.clear_history) and active_root.is_builtin():
		active_root.closed.connect(undo_redo.clear_history.bind(EditorUndoRedoManager.GLOBAL_HISTORY))
	
	undo_redo.create_action(action_name, merge_mode, cache, false, root_changed)
	undo_redo.add_undo_method(cache, &"set_edited_tree", active_root)
	undo_redo.add_do_method(cache, &"set_edited_tree", active_root)
	
	if root_changed:
		var version: int = undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY).get_version()
		active_root.change_version(version, version + 1)
		undo_redo.add_undo_method(active_root, &"change_version", version + 1, version)
		undo_redo.add_do_method(active_root, &"change_version", version, version + 1)
	
	return true

func commit(execute: bool = true) -> void:
	undo_redo.commit_action(execute)

func clear_undo_redo_history() -> void:
	undo_redo.clear_history(EditorUndoRedoManager.GLOBAL_HISTORY)

func _on_version_changed() -> void:
	if not active_root: return

#endregion UndoRedo

#region Selection

func clear_selected_node() -> void:
	selected_node = null
	is_tree_display_menu_active = false

func comp_set_selected(comp: RationalComponent, selected: bool) -> void:
	if not comp_has_node(comp): return
	comp_get_graph_node(comp).selected = selected

## NOTE: Deselects all other components.
func select_comp(comp: RationalComponent) -> void:
	set_selected(comp_get_graph_node(comp))

func _on_node_selected(node: Node) -> void:
	selection.add_component(node.component)

func _on_node_deselected(node: Node) -> void:
	selection.remove_component(node.component)

func _on_selected_component(comp: RationalComponent, selected: bool) -> void:
	comp_set_selected(comp, selected)

func has_selected_node() -> bool:
	return 0 < selection.get_selection_count()

func get_selected_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	result.assign(get_selected_components().map(comp_get_graph_node).filter(is_instance_valid))
	return result
	#for comp: RationalComponent in get_selected_components():
		#if not comp_has_node(comp): continue
		#result.push_back(comp_get_graph_node(comp))
	#return result

## If multiple nodes are selected, the one selected by the menu is chosen.
## If no node was selected by the menu, then it gets the closest to mouse.
func get_selected() -> RationalGraphNode:
	if selected_node:
		return selected_node
	
	var selected_nodes: Array[RationalGraphNode] = get_selected_nodes()
	if selected_nodes.is_empty(): 
		return null
	
	if selected_nodes.size() > 1:
		selected_nodes.sort_custom(sort_center_distance.bind(get_local_mouse_position()))
	
	return selected_nodes[0]

## Returns component of node returned from [method get_selected] if it exists. 
func get_selected_comp() -> RationalComponent:
	var node:= get_selected()
	return node.component if node else null

func get_selected_components() -> Array[RationalComponent]:
	return selection.get_selected_components().duplicate()

#endregion Selection

#region Clipboard

func get_clipboard() -> Array[RationalComponent]:
	return clipboard.duplicate()

func get_top_clipboard_components() -> Array[RationalComponent]:
	var components: Array[RationalComponent] = get_clipboard()
	var result: Array[RationalComponent]
	result.assign(components.filter(
		func(comp: RationalComponent) -> bool: 
			return not components.any(func(c: RationalComponent) -> bool: return c.has_child(comp, true))))
	return result

func clipboard_copy(components: Array[RationalComponent]) -> void:
	clipboard.assign(components.filter(comp_is_valid))

func clipboard_clear() -> void:
	clipboard.clear()

func can_paste() -> bool:
	return not get_clipboard().is_empty()

#endregion Clipboard

func sort_center_distance(a: Control, b: Control, point: Vector2) -> bool:
	return a.get_rect().get_center().distance_squared_to(point) < b.get_rect().get_center().distance_squared_to(point)

func nodes_get_rect(nodes: Array[RationalGraphNode]) -> Rect2:
	if nodes.is_empty(): 
		return Rect2()
	
	var rect: Rect2 = Rect2(nodes.front().position_offset, nodes.front().size)
	for nod: GraphNode in nodes:
		rect = rect.merge(Rect2(nod.position_offset, nod.size))
	return rect

func get_graph_rect() -> Rect2:
	return nodes_get_rect(get_graph_nodes())

func node_get_port_positon(node: RationalGraphNode, output: bool) -> Vector2:
	if not node: return Vector2.ZERO
	return node.position + (node.get_output_position() if output else node.get_input_position()) * zoom


func is_input_closer(node: RationalGraphNode, point: Vector2) -> bool:
	return 	node_get_port_positon(node, false).distance_squared_to(point) <= \
			node_get_port_positon(node, true).distance_squared_to(point)

func get_port_distance_squared(node: RationalGraphNode, point: Vector2) -> float:
	return minf(node_get_port_positon(node, false).distance_squared_to(point),
				node_get_port_positon(node, true).distance_squared_to(point))

func sort_port_distance(a: RationalGraphNode, b: RationalGraphNode, point: Vector2) -> bool:
	return 	get_port_distance_squared(a, point) < get_port_distance_squared(b, point)

func get_closest_port_to_position(to_position: Vector2) -> Dictionary:
	var nodes:= get_graph_nodes()
	nodes.sort_custom(sort_port_distance.bind(to_position))
	return {node = nodes[0], left = is_input_closer(nodes[0], to_position)}

func get_hovered_port_node() -> RationalGraphNode:
	for node: RationalGraphNode in get_graph_nodes():
		if node.is_left_port_hovered or node.is_right_port_hovered:
			return node
	return null

func is_hovering_port() -> bool:
	for node in get_graph_nodes():
		if node.is_left_port_hovered or node.is_right_port_hovered:
			return true
	return false

## Returns true if hovering port.
func disconnect_hovered_port() -> bool:
	var node: RationalGraphNode = get_hovered_port_node()
	
	if not node:
		return false
	
	for con: Dictionary in get_connection_list_from_node(node.name):
		if node.is_left_port_hovered and con.to_node == node.name:
			comp_reparent(node.component, node_get_comp(con.from_node), null)
		
		if node.is_right_port_hovered and con.from_node == node.name:
			comp_reparent(node_get_comp(con.from_node), node.component, null)
	
	return true

func local_to_offset(local: Vector2) -> Vector2:
	return (local + scroll_offset)  / zoom

func get_root_component() -> RationalComponent:
	return active_root.root if active_root else null

func toggle_layout() -> void:
	if not active_root:
		horizontal_layout = !horizontal_layout
		return
	
	create_action("Toggled Layout", UndoRedo.MERGE_ALL, false)
	undo_redo.add_undo_property(self, &"horizontal_layout", horizontal_layout)
	undo_redo_add_node_positions()
	undo_redo.add_do_property(self, &"horizontal_layout", !horizontal_layout)
	commit()

func update_layout_button() -> void:
	layout_button.icon = EditorInterface.get_editor_theme().get_icon(&"MoveRight" if horizontal_layout else &"MoveDown", &"EditorIcons")
	layout_button.tooltip_text = "Switch to Vertical layout" if horizontal_layout else "Switch to Horizontal layout"

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	const VECS: PackedVector2Array = [Vector2(-9999999, -9999999), Vector2(-9999999, -9999999)]
	return VECS
