@tool
extends PanelContainer

const Util := preload("../util.gd")
const DebugGraphEdit := preload("debugger_graph_edit.gd")

const INVALID: int = -1

signal tree_selected(id: int)

var window: Window

var main_container: HSplitContainer
var item_list: ItemList
var graph_container: HSplitContainer
var graph: DebugGraphEdit
var blackboard_vbox: VBoxContainer

var window_container: MarginContainer

## Displays a message when nothing else is visible in main container.
var label: Label

var panel_collapse_button: Button
var floating_button: Button

var icon_data: Dictionary[StringName, Texture2D]

var window_open: bool

## Reference from debug plugin. 
var tree_data: Dictionary[int, Dictionary] = {}

var active_tree_id: int = INVALID: set = set_active_tree_id

var tree_pending_activation: int = INVALID


func _init() -> void:
	name = "🧠 Rational"
	build_ui()
	

func _ready() -> void:
	stop()

func build_ui() -> void:
	label = Label.new()
	label.text = "Rational debugger is detached currently."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)
	
	# Main HSplit
	main_container = HSplitContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(300, 0)
	item_list.item_selected.connect(_on_item_selected)
	main_container.add_child(item_list)
	
	graph_container = HSplitContainer.new()
	graph_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(graph_container)
	
	blackboard_vbox = VBoxContainer.new()
	blackboard_vbox.custom_minimum_size = Vector2(500, 0)
	blackboard_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blackboard_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blackboard_vbox.hide()
	
	graph = DebugGraphEdit.new()
	graph.node_selected.connect(_on_graph_node_selected)
	graph.node_deselected.connect(_on_graph_node_deselected)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	graph_container.add_child(graph)
	graph_container.add_child(blackboard_vbox)
	
	floating_button = graph.get_menu_hbox().get_child(-1).duplicate(0) as Button
	floating_button.tooltip_text = "Make the Rational debugger floating"
	floating_button.icon = Util.get_icon(&"MakeFloating")
	floating_button.pressed.connect(_on_floating_pressed)
	graph.get_menu_hbox().add_child(floating_button)
	
	panel_collapse_button = floating_button.duplicate(0) as Button
	panel_collapse_button.tooltip_text = "Toggle Panel"
	panel_collapse_button.icon = Util.get_icon(&"Back")
	panel_collapse_button.pressed.connect(toggle_panel)
	graph.get_menu_hbox().add_child(panel_collapse_button)
	graph.get_menu_hbox().move_child(panel_collapse_button, 0)
	
	window = Window.new()
	window.visible = false
	window.title = "Rational Debugger"
	window.wrap_controls = true
	window.min_size = Vector2i(600, 350)
	window.transient = true
	window.close_requested.connect(close_window)
	
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override(&"panel", EditorInterface.get_editor_theme().get_stylebox(&"PanelForeground", &"EditorStyles"))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	window_container = MarginContainer.new()
	window_container.theme_type_variation = &"MarginContainer4px"
	window_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(window_container,)
	
	window.add_child(panel)
	add_child(window)


func start() -> void:
	main_container.visible = true

func stop() -> void:
	main_container.visible = false
	item_list.clear()


func clear_blackboard() -> void:
	pass

func register_tree(data: Dictionary) -> void:
	var id: int = data.id
	
	if not tree_data.has(id):
		var idx = item_list.add_item(data.name, )
		item_list.set_item_tooltip(idx, data.path)
		item_list.set_item_metadata(idx, data.id)
	tree_data[id] = data
	
	if item_list.get_selected_items().is_empty():
		select_id(id)


func unregister_tree(id: int) -> void:
	remove_tree(id)
	return	
	blackboard_vbox.hide()

## Does not emit signal.
func select_id(id: int) -> void:
	var index: int = id_get_index(id)
	if index != INVALID:
		item_list.select(index)

func id_get_index(id: int) -> int:
	for index: int in item_list.item_count:
		if item_list.get_item_metadata(index) == id:
			return index
	return INVALID

func add_tree(id: int, data: Dictionary) -> void:
	if id_get_index(id) != INVALID: return
	var index: int = item_list.add_item(data.name, )
	item_list.set_item_tooltip(index, data.path)
	item_list.set_item_metadata(index, id)

func remove_tree(id: int) -> void:
	var index: int = id_get_index(id)
	if index == INVALID: return
	item_list.remove_item(index)

func set_active_tree_id(id: int) -> void:
	active_tree_id = id
	

func set_icon_data(_icon_data: Dictionary[StringName, Texture2D]) -> void:
	icon_data = _icon_data

func _on_item_selected(index: int) -> void:
	tree_selected.emit(item_list.get_item_metadata(index))


func _on_graph_node_selected(node: GraphNode) -> void:
	return
	for child in blackboard_vbox.get_children():
		child.free()
	blackboard_vbox.show()
	#blackboard_vbox.add_child(Blackboard.new(Utils.get_frames(), node))


func _on_graph_node_deselected(node: GraphNode) -> void:
	return
	for child in blackboard_vbox.get_children():
		if child.name == node.name:
			child.free()
	if blackboard_vbox.get_child_count() == 0:
		blackboard_vbox.hide()

func open_window() -> void:
	if not floating_button.visible: return
	floating_button.visible = false
	remove_child(main_container)
	window_container.add_child(main_container)
	window.show()

func close_window() -> void:
	if floating_button.visible: return
	window.hide()
	window_container.remove_child(main_container)
	add_child(main_container)
	floating_button.visible = true

func toggle_panel() -> void:
	item_list.visible = not item_list.visible
	panel_collapse_button.icon = Util.get_icon(&"Back" if item_list.visible else &"Forward")

func _on_floating_pressed() -> void:
	open_window()
