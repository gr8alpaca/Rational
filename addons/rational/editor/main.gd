@tool
extends PanelContainer

const Util := preload("../util.gd")
const Cache := preload("../data/cache.gd")

const GraphEditor := preload("graph_edit.gd")
const FileList := preload("root_file_list.gd")


@export var root_file_tree: FileList
@export var tree_display: Tree
@export var make_floating_button: Button
@export var add_root_button: Button
@export var collapse_panel_container: PanelContainer
@export var panel_collapse_button: Button
@export var tree_panel: VSplitContainer
@export var graph_edit: GraphEditor

var file_dialog: EditorFileDialog

var floating_window: Window

var toggle_panel_shortcut: Shortcut

var shortcuts: Dictionary[Shortcut, Callable]

var cache: Cache = Util.get_cache()

func _init() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.title = "Save Rational Component"
	file_dialog.add_filter("*.tres", "RationalComponent")
	file_dialog.add_filter("*.res", "RationalComponent")
	file_dialog.filters = PackedStringArray(["*.res,*.tres;Rational Files;resource/res,resource/tres"])
	add_child(file_dialog)
	
	file_dialog.canceled.connect(_on_file_dialog_canceled, CONNECT_DEFERRED)
	
	theme_changed.connect(apply_theme)

func _ready() -> void:
	cache.request_save_as.connect(save_as)
	panel_collapse_button.pressed.connect(toggle_file_panel)
	root_file_tree.request_toggle_files_panel.connect(toggle_file_panel)
	init_shortcuts()
	
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()
	
	cache.load()

func save_as(data: RootData) -> void:
	if not data: return
	
	file_dialog.current_file = data.name.to_snake_case() + ".tres"
	
	if not data.is_builtin() and data.path:
		if DirAccess.dir_exists_absolute(data.path.get_base_dir()):
			file_dialog.current_dir = data.path.get_base_dir()
			file_dialog.current_file = data.path.get_file().get_slice(".", 0) + "_copy.tres"
	
	file_dialog.file_selected.connect(_on_file_selected.bind(data), CONNECT_ONE_SHOT)
	
	file_dialog.popup_file_dialog()


func _on_file_selected(path: String, data: RootData) -> void:
	if not path:
		print("No Path Selected: %s" % path)
		return
	
	if not data: return
	
	match data.save_as(path):
		OK:
			cache.add_path(path)
			print_rich("[color=green]Saved data at path '%s'." % path)
		var err:
			printerr("Could not save data at path '%s': %s" % [path, error_string(err)])


func _on_file_dialog_canceled() -> void:
	if file_dialog.file_selected.is_connected(_on_file_selected):
		file_dialog.file_selected.disconnect(_on_file_selected)


func edit(rational_object: Object) -> void:
	if rational_object is RationalTree:
		edit_tree(rational_object)
	elif rational_object is RationalComponent:
		edit_root(rational_object)

func edit_tree(tree: RationalTree) -> void:
	cache.edit_rational_tree(tree)

func edit_root(root: RationalComponent) -> void:
	cache.edit_root(root)
	EditorInterface.set_main_screen_editor("Rational")


func init_shortcuts() -> void:
	var file_panel_shortcut: Shortcut = Util.get_shortcut(&"toggle_files_panel")
	panel_collapse_button.tooltip_text = "Toggle panel" + (" (%s)" % file_panel_shortcut.get_as_text() if file_panel_shortcut else "")
	shortcuts[file_panel_shortcut] = toggle_file_panel
	
	var float_shortcut: Shortcut = Util.get_shortcut(&"make_floating")
	shortcuts[float_shortcut] = make_floating_button.set_pressed.bind(true)
	make_floating_button.tooltip_text = "Make the Rational tree editor floating. " + (" (%s)" % float_shortcut.get_as_text() if float_shortcut else "")
	
	# GraphEditor
	shortcuts[Util.get_shortcut(&"toggle_grid")] = graph_edit.toggle_grid
	shortcuts[Util.get_shortcut(&"use_grid_snap")] = graph_edit.toggle_snap
	shortcuts[Util.get_shortcut(&"frame_selection")] = graph_edit.frame_selection
	shortcuts[Util.get_shortcut(&"center_selection")] = graph_edit.center_selection
	shortcuts[Util.get_shortcut(&"zoom_minus")] = graph_edit.zoom_out
	shortcuts[Util.get_shortcut(&"zoom_plus")] = graph_edit.zoom_in
	shortcuts[Util.get_shortcut(&"cancel_transform")] = graph_edit.cancel_drag
	
	for percent_str: String in ["3.125", "6.25", "12.5", "25", "50", "100", "200", "400"]:
		shortcuts[Util.get_shortcut("zoom_%s_percent" % percent_str)] = graph_edit.set_zoom.bind(float(percent_str.to_float())/100.0)
	
	shortcuts[Util.get_shortcut(&"rename")] = graph_edit.rename
	shortcuts[Util.get_shortcut(&"change_type")] = graph_edit.change_type
	shortcuts[Util.get_shortcut(&"save_as_root")] = graph_edit.save_as_root
	
	# File List
	shortcuts[Util.get_shortcut(&"save")] = root_file_tree.save_selected
	shortcuts[Util.get_shortcut(&"save_as")] = root_file_tree.save_selected_as
	shortcuts[Util.get_shortcut(&"rename")] = root_file_tree.edit_selected.bind(true)
	shortcuts[Util.get_shortcut(&"close")] = root_file_tree.close_selected
	shortcuts[Util.get_shortcut(&"close_others")] = root_file_tree.close_unselected
	shortcuts[Util.get_shortcut(&"close_below")] = root_file_tree.close_below_selected
	shortcuts[Util.get_shortcut(&"close_all")] = root_file_tree.close_all
	shortcuts[Util.get_shortcut(&"copy_path")] = root_file_tree.copy_path
	shortcuts[Util.get_shortcut(&"copy_uid")] = root_file_tree.copy_uid
	shortcuts[Util.get_shortcut(&"move_file_up")] = root_file_tree.move_up
	shortcuts[Util.get_shortcut(&"move_file_down")] = root_file_tree.move_down
	shortcuts[Util.get_shortcut(&"sort")] = root_file_tree.sort_files
	
	# Erase any null objects
	shortcuts.erase(null)


func _shortcut_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	for sc: Shortcut in shortcuts:
		if not sc.matches_event(event): continue
		if OS.is_stdout_verbose():
			print("Rational shortcut: %s" % sc.get_as_text())
		accept_event()
		shortcuts[sc].call()
		return


func toggle_file_panel() -> void:
	tree_panel.visible = !tree_panel.visible
	panel_collapse_button.icon = get_theme_icon(&"Back" if tree_panel.visible else &"Forward", &"EditorIcons") 


func apply_theme() -> void:
	panel_collapse_button.icon = get_theme_icon(&"Back" if tree_panel.visible else &"Forward", &"EditorIcons")
	
	if has_theme_stylebox(&"panel", &"PanelForeground"):
		var style_box: StyleBox = get_theme_stylebox(&"panel", &"PanelForeground").duplicate()
		style_box.set(&"corner_radius_bottom_left", 0)
		style_box.set(&"corner_radius_top_left", 0)
		style_box.set_content_margin_all(0)
		collapse_panel_container.add_theme_stylebox_override(&"panel", style_box)
	
	make_floating_button.icon = get_theme_icon(&"MakeFloating", &"EditorIcons")
	
	var icon_width: int = make_floating_button.icon.get_width()
	root_file_tree.add_theme_constant_override(&"icon_max_width", icon_width)
	tree_display.add_theme_constant_override(&"icon_max_width", icon_width)

func _on_visibility_changed() -> void:
	set_process_shortcut_input(is_visible_in_tree())
	
