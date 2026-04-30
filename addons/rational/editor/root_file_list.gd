@tool
extends Tree

const Util := preload("../util.gd")

const Cache := preload("../data/cache.gd")
const ID_MOVE_UP: int = 1001
const ID_MOVE_DOWN: int = 1002

signal request_toggle_files_panel

@export var filter_line_edit: LineEdit

@export var add_root_button: Button

@export var popup: PopupMenu

var cache: Cache = Util.get_cache()

func apply_theme() -> void:
	filter_line_edit.right_icon = get_theme_icon(&"Search", &"EditorIcons")

func _ready() -> void:
	theme_changed.connect(apply_theme)
	apply_theme()
	
	popup.index_pressed.connect(_on_popup_menu_index_pressed)
	init_popup()
	
	filter_line_edit.text_changed.connect(_on_filter_text_changed)
	
	add_root_button.pressed.connect(_on_add_root_button_pressed)
	
	item_selected.connect(_on_item_selected)
	item_edited.connect(_on_item_edited)
	item_mouse_selected.connect(_on_item_mouse_selected)
	
	cache.data_added.connect(add_data)
	cache.data_erased.connect(erase_data)
	cache.edited_tree_changed.connect(_on_edited_tree_changed)
	
	build_list()

func _on_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var item: TreeItem = get_item_at_position(mouse_position)
		popup.set_item_disabled(popup.get_item_index(ID_MOVE_UP), item.get_prev() == null)
		popup.set_item_disabled(popup.get_item_index(ID_MOVE_DOWN), item.get_next() == null)
		popup.popup(Rect2(get_screen_position() + mouse_position, Vector2.ZERO))

func build_list() -> void:
	clear()
	create_item()
	for data: RootData in cache.get_data_list():
		add_data(data)

func has_root(root: RationalComponent) -> bool:
	return root_get_item(root) != null

func has_path(path: String) -> bool:
	return path_get_item(path) != null

func item_get_data(item: TreeItem) -> RootData:
	return item.get_metadata(0)

func data_get_item(data: RootData) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item_get_data(item) == data:
			return item
	return null

func has_data(data: RootData) -> bool:
	return data_get_item(data) != null


func item_get_path(item: TreeItem) -> String:
	return item_get_data(item).path if item else ""

func item_get_root(item: TreeItem) -> RationalComponent:
	return item_get_data(item).root if item else null

func path_get_item(path: String) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item_get_path(item) == path:
			return item
	return null

func root_get_item(root: RationalComponent) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item_get_root(item) == root:
			return item
	return null


func close_item(item: TreeItem) -> void:
	if not item: return
	item_get_data(item).closed.emit()

func close_data(data: RootData) -> void:
	if not data: return
	data.closed.emit() 

func add_data(data: RootData) -> void:
	if has_data(data): return
	var item: TreeItem = create_item()
	item.set_metadata(0, data)
	update_item(item)
	
	data.changed.connect(_on_data_changed.bind(data))
	data.unsaved_changes_changed.connect(_on_unsaved_changes_changed.bind(data))
	data.closed.connect(_on_data_closed.bind(data))
	
	if data == cache.get_edited_tree():
		item.select(0)
		ensure_cursor_is_visible()
	
	sort_files()

func add_root(root: RationalComponent, force_path: String = "") -> void:
	if not root: return
	cache.add_root(root, force_path)


func update_item(item: TreeItem) -> void:
	if not item: return
	var data: RootData = item_get_data(item)
	item.set_text(0, data_get_name(data))
	item.set_icon(0, Util.comp_get_icon(data.root))
	item.set_tooltip_text(0, data_get_tooltip(data))

func data_get_name(data: RootData) -> String:
	return data.name + (" (*)" if data.has_unsaved_changes() else "") 

func data_get_tooltip(data: RootData) -> String:
	return "Type: %s\nPath: %s" % [Util.comp_get_class(data.root), data.path]

func erase_data(data: RootData) -> void:
	cache.erase_data(data)
	data.closed.emit()

func _on_data_closed(data: RootData) -> void:	
	if not data: return
	var item:= data_get_item(data)
	
	data.changed.disconnect(_on_data_changed)
	data.unsaved_changes_changed.disconnect(_on_unsaved_changes_changed)
	data.closed.disconnect(_on_data_closed)
	
	if item:
		item.free()

func _on_data_changed(data: RootData) -> void:
	update_item(data_get_item(data))

func _on_unsaved_changes_changed(data: RootData) -> void:
	var item: TreeItem = data_get_item(data)
	if item:
		item.set_text(0, data_get_name(data))

func filter_list(filter: String = "") -> void:
	for item: TreeItem in get_root().get_children():
		item.visible = item.get_text(0).containsn(filter) if filter else true

func _on_filter_text_changed(new_text: String) -> void:
	filter_list(new_text)

func edit_data(data: RootData) -> void:
	if not data: return
	cache.edit_tree(data)

func edit_tree(tree: RationalTree) -> void:
	if not tree: return
	if not tree.root:
		prompt_new_root(tree)
		return
	
	cache.edit_root(tree.root)

func select_data(data: RootData) -> void:
	if not data: return
	add_data(data)
	data_get_item(data).select(0)
	ensure_cursor_is_visible()
	

func _on_item_selected() -> void:
	var item: TreeItem = get_selected()
	if not item: return
	edit_data(item_get_data(item))

func _on_add_root_button_pressed() -> void:
	prompt_new_root()

func prompt_new_root(for_tree: RationalTree = null) -> void:
	EditorInterface.popup_create_dialog(create_new_root, &"RationalComponent", "", "Change Component Type", [])

## Creates a new root RationalComponent.
func create_new_root(script_path: String) -> void:
	if not Util.script_path_is_valid(script_path): return
	var new_root: RationalComponent = Util.instantiate_path(script_path)
	cache.add_root(new_root)
	var data: RootData = cache.get_data(new_root)
	select_data(data)

func _on_edited_tree_changed(data: RootData) -> void:
	select_data(data)

#region RightClickMenu

func save_selected() -> void:
	save_item(get_selected())

func save_selected_as() -> void:
	save_item_as(get_selected())

func close_selected() -> void:
	close_item(get_selected())

func close_unselected() -> void:
	close_items_except([get_selected()])

func close_below_selected() -> void:
	if not get_selected(): return
	close_items_except(get_root().get_chilren().slice(0, get_selected().get_index()))

func close_all() -> void:
	close_items_except()

func save_item(item: TreeItem) -> void:
	var data: RootData = item_get_data(item)
	if not data.can_save():
		cache.save_data_as(data)
	item_get_data(item).save()

func save_item_as(item: TreeItem) -> void:
	cache.save_data_as(item_get_data(item))

func _on_item_edited() -> void:
	var item: TreeItem = get_selected()
	if item:
		item_get_data(item).rename(item.get_text(0))

func rename() -> void:
	if not get_selected(): return
	edit_selected(true)

func init_popup() -> void:
	popup.clear()
	Util.add_menu_item(popup, "Save", &"", &"save", save_selected)
	Util.add_menu_item(popup, "Save As...", &"", &"save_as", save_selected_as)
	Util.add_menu_item(popup, "Rename", &"", &"rename", rename)
	Util.add_menu_item(popup, "Close", &"", &"close", close_selected)
	Util.add_menu_item(popup, "Close Others", &"", &"close_others", close_unselected) 
	Util.add_menu_item(popup, "Close Below", &"", &"close_below", close_below_selected) 
	Util.add_menu_item(popup, "Close All", &"", &"close_all", close_all)
	popup.add_separator("")
	Util.add_menu_item(popup, "Copy Path", &"", &"copy_path", copy_path)
	Util.add_menu_item(popup, "Copy UID", &"", &"copy_uid", copy_uid)
	Util.add_menu_item(popup, "Show in FileSystem", &"", &"show_in_file_system", show_in_file_system)
	popup.add_separator("")
	Util.add_menu_item(popup, "Move Up", &"", &"move_file_up", move_up, ID_MOVE_UP)
	Util.add_menu_item(popup, "Move Down", &"", &"move_file_down", move_down, ID_MOVE_DOWN)
	Util.add_menu_item(popup, "Sort", &"", &"sort", sort_files)
	Util.add_menu_item(popup, "Toggle Panel", &"", &"toggle_files_panel", toggle_files_panel)


func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		close_item(get_item_at_position(event.position))
		accept_event()

func _on_popup_menu_index_pressed(index: int) -> void:
	popup.get_item_metadata(index).call()

func show_in_file_system() -> void:
	var item_path:= item_get_path(get_selected())
	if not item_path: return
	item_path = item_path.get_slice("::", 0)
	if FileAccess.file_exists(item_path):
		EditorInterface.select_file(item_path)

func copy_path() -> void:
	var path: String = item_get_path(get_selected())
	if path:
		DisplayServer.clipboard_set(path)

func copy_uid() -> void:
	var path: String = item_get_path(get_selected())
	var uid: String = ResourceUID.path_to_uid(item_get_path(get_selected()))
	if uid != path:
		DisplayServer.clipboard_set(uid)

func close_items_except(items_staying: Array[TreeItem] = []) -> void:
	for item: TreeItem in get_root().get_children():
		if item in items_staying: continue
		close_item(item)

func move_up() -> void:
	if not get_selected() or not get_selected().get_prev(): return
	get_selected().move_before(get_selected().get_prev())

func move_down() -> void:
	if not get_selected() or not get_selected().get_next(): return
	get_selected().move_after(get_selected().get_next())

func toggle_files_panel() -> void:
	request_toggle_files_panel.emit()

func sort_files() -> void:
	var items: Array[TreeItem] = get_root().get_children()
	items.sort_custom(func (a: TreeItem, b: TreeItem) -> bool: return a.get_text(0) < b.get_text(0))
	for i: int in items.size():
		if get_root().get_child(i) == items[i]: continue
		items[i].move_before(get_root().get_child(i))

#endregion

#region Drag&Drop

func import_files(files: Array) -> void:
	files = files.filter(func(f: Variant) -> bool: return f is String)
	for file in files:
		if ResourceLoader.exists(file, "Resource") and ResourceLoader.load(file, "Resource") is RationalComponent:
			cache.add_path(file)
	
	for file in files:
		var item:= path_get_item(file)
		if not item: continue
		item.select(0)
		break

func move_item_to_position(to_position: Vector2, item: TreeItem) -> void:
	if not item: return
	if get_item_at_position(to_position):
		item.move_before(get_item_at_position(to_position))
	
	elif to_position.y < 16:
		item.move_before(get_root().get_first_child())
	
	elif to_position.y > get_item_area_rect(get_root().get_child(-1)).end.y:
		item.move_after(get_root().get_child(-1))

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		match data.get("type", ""):
			"files":
				return true
			"item" when data.get("source") == self:
				return true
	
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		match data.get("type", ""):
			"files":
				import_files(data.get("files", []))
			"item":
				move_item_to_position(at_position, data.item)

# File dock format: { "type": "files", "files": ["res://BitMap.tres"], "from": @Tree@5673:<Tree#495833867875> }
func _get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = get_item_at_position(at_position)
	if not item:
		return null
	var button: Button = Button.new()
	button.flat = true
	button.text = item.get_text(0)
	button.icon = item.get_icon(0)
	set_drag_preview(button)
	return {type = "item", item = item, source = self}

#endregion 
