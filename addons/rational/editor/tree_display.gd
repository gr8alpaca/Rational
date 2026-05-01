@tool
extends Tree

const Util := preload("res://addons/rational/util.gd")
const Selection:= preload("selection.gd")

const ID_VISIBLE: int = 0
const ID_INSTANCE: int = 1

const META_VISIBLE: StringName = &"visible"
const META_INSTANCE: StringName = &"instance"

const COLOR_HIDDEN: Color = Color.DIM_GRAY
const COLOR_VISIBLE: Color = Color.WHITE

signal request_reparent(comp: RationalComponent,  current_parent: RationalComponent, target_parent: RationalComponent, index: int)

@export var tree_filter_line_edit: LineEdit

var selection: Selection = Util.get_selection()

var active_root: RootData: set = set_active_root

var deselect_queued: bool = false

func apply_theme() -> void:
	tree_filter_line_edit.right_icon = get_theme_icon(&"Search", &"EditorIcons")

func _ready() -> void:
	theme_changed.connect(apply_theme)
	apply_theme()
	
	selection.selected_component.connect(_on_selected_component)
	multi_selected.connect(_on_multi_selected)
	button_clicked.connect(_on_button_clicked)
	
	tree_filter_line_edit.text_changed.connect(_on_filter_text_changed)

func rename() -> void:
	edit_selected(false)

func set_active_root(data: RootData) -> void:
	active_root = data
	populate_tree()

func get_root_comp() -> RationalComponent:
	return active_root.root if active_root else null

func populate_tree() -> void:
	var selected_comp: RationalComponent = get_selected().get_metadata(0) if get_selected() else null
	
	clear()
	if not active_root: 
		return
	
	if not active_root.is_loaded():
		active_root.loaded.connect(populate_tree, CONNECT_ONE_SHOT)
		return
	
	add_component(get_root_comp())
	
	sync_selection()
	
	var item: TreeItem = comp_get_item(selected_comp)
	if item:
		set_selected(item, 0)
		ensure_cursor_is_visible()

func item_is_instanced(item: TreeItem) -> bool:
	return item and item.get_meta(META_INSTANCE, false)

func item_set_instanced(item: TreeItem, instanced: bool) -> void:
	item.set_meta(META_INSTANCE, instanced)
	item.set_editable(0, not instanced)
	if (instanced and item.get_button_by_id(0, ID_INSTANCE) == -1) or (not instanced and item.get_button_by_id(0, ID_INSTANCE) != -1):
		update_item_buttons(item)

func update_item_buttons(item: TreeItem) -> void:
	item.clear_buttons()
	if item_is_instanced(item):
		item.add_button(0, get_theme_icon(&"Instance", &"EditorIcons"), ID_INSTANCE, false, "Open Tree")
	
	item.add_button(0, get_visible_icon(item_is_visible(item)), ID_VISIBLE, false, "Toggle Visibility")
	item.set_button_color(0, item.get_button_by_id(0, ID_VISIBLE), COLOR_VISIBLE if item_visible_in_tree(item) else COLOR_HIDDEN)


func add_component(comp: RationalComponent, parent: TreeItem = null, index: int = -1) -> void:
	if not comp: return
	var item: TreeItem = create_item(parent, index)
	item.set_metadata(0, comp)
	item.set_icon(0, Util.comp_get_icon(comp))
	
	item.set_meta(META_INSTANCE, comp != get_root_comp() and not comp.is_built_in())
	item.set_editable(0, not item.get_meta(META_INSTANCE, false))
	
	item.set_meta(META_VISIBLE, true)
	item.set_text(0, comp.get_name())
	item.set_tooltip_text(0, "%s\nType: %s" % [comp.resource_name, Util.comp_get_class(comp)])
	
	update_item_buttons(item)
	
	if item_is_instanced(item):
		return
	
	item.add_user_signal("changed")
	comp.changed.connect(item.emit_signal.bind(&"changed"))
	item.connect(&"changed", _on_item_changed, CONNECT_APPEND_SOURCE_OBJECT)
	
	item.add_user_signal("comp_script_changed") 
	comp.script_changed.connect(item.emit_signal.bind(&"comp_script_changed"), CONNECT_DEFERRED)
	item.connect(&"comp_script_changed", _on_item_script_changed, CONNECT_APPEND_SOURCE_OBJECT)
	
	item.add_user_signal("children_changed")
	comp.children_changed.connect(item.emit_signal.bind(&"children_changed"))
	item.connect(&"children_changed", _on_item_children_changed, CONNECT_APPEND_SOURCE_OBJECT)
	
	
	
	for child: RationalComponent in comp.get_children():
		if not child: continue
		add_component(child, item)

func item_apply_filter(item: TreeItem, filter_text: String) -> bool:
	var any_child_visible: bool = false
	for child: TreeItem in item.get_children():
		any_child_visible = item_apply_filter(child, filter_text) or any_child_visible
	item.visible = any_child_visible or item.get_text(0).containsn(filter_text)
	if item.visible:
		item.uncollapse_tree()
	return item.visible

func filter_items(text: String) -> void:
	if not text:
		get_root().call_recursive("set_visible", true)
		return
	
	item_apply_filter(get_root(), text)


func item_get_comp(item: TreeItem) -> RationalComponent:
	return item.get_metadata(0) if item else null


func item_is_visible(item: TreeItem) -> bool:
	return item.get_meta(META_VISIBLE, false)


func item_set_visible(item: TreeItem, item_visible: bool) -> void:
	item.set_meta(META_VISIBLE, item_visible)
	item.set_button(0, 0, get_visible_icon(item_visible))
	item_set_visible_modulate(item)


func item_set_visible_modulate(item: TreeItem) -> void:
	var visible_in_tree: bool = item_visible_in_tree(item)
	var button_color: Color = COLOR_VISIBLE if visible_in_tree else COLOR_HIDDEN
	if button_color == item.get_button_color(0, 0): return
	item.set_button_color(0, 0, button_color)
	for child: TreeItem in item.get_children():
		item_set_visible_modulate(child)

func item_visible_in_tree(item: TreeItem) -> bool:
	while item:
		if not item_is_visible(item):
			return false
		item = item.get_parent()
	return true

func _on_filter_text_changed(new_text: String) -> void:
	filter_items(new_text)

func _on_item_changed(item: TreeItem) -> void:
	item.set_text(0, item.get_metadata(0).resource_name)

func _on_item_script_changed(item: TreeItem) -> void:
	item.set_icon(0, Util.comp_get_icon(item_get_comp(item)))

func _on_item_children_changed(item: TreeItem) -> void:
	var comp: RationalComponent = item_get_comp(item)
	for child: TreeItem in item.get_children():
		item.remove_child(child)
		child.free()
	
	for child: RationalComponent in comp.get_children():
		add_component(child, item)

func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	match id:
		ID_INSTANCE:
			var comp: RationalComponent = item_get_comp(item)
			if mouse_button_index == MOUSE_BUTTON_LEFT and comp:
				Util.get_cache().edit_file(comp.resource_path)
		ID_VISIBLE:
			item_set_visible(item, !item_is_visible(item))

func get_visible_icon(item_visible: bool) -> Texture2D:
	return get_theme_icon(&"GuiVisibilityVisible", &"EditorIcons") if item_visible else get_theme_icon(&"GuiVisibilityHidden", &"EditorIcons")

func get_all_selected_items() -> Array[TreeItem]:
	var selected_items: Array[TreeItem]
	var item: TreeItem = get_root() if get_root().is_selected(0) else get_next_selected(get_root())
	while item:
		selected_items.push_back(item)
		item = get_next_selected(item)
	return selected_items

func sync_selection() -> void:
	for item: TreeItem in self:
		item_set_selected(item, selection.is_selected(item.get_metadata(0)))

func comp_get_item(comp: RationalComponent) -> TreeItem:
	if not comp: return null
	for item: TreeItem in self:
		if item.get_metadata(0) == comp: 
			return item
	return null

func get_selected_comp() -> RationalComponent:
	return item_get_comp(get_selected())

## Sets item selected = [param selected] and uncollapses tree if selected. 
func item_set_selected(item: TreeItem, selected: bool) -> void:
	if not item or item.is_selected(0) == selected: return
	
	if not selected:
		item.deselect(0)
		return
	
	item.select(0)
	item.uncollapse_tree()


## Sets [param item.root.resource_name] if different.
func generate_unique_name(item: TreeItem) -> String:
	if not item or not item_get_comp(item): return ""
	var comp: RationalComponent = item_get_comp(item)
	
	if not comp.resource_name:
		comp.resource_name = Util.comp_get_class(comp)
	
	var name_list: PackedStringArray
	if item.get_parent():
		for sibling: TreeItem in item.get_parent().get_children():
			if item == sibling: continue
			name_list.push_back(sibling.get_text(0))
	
	return Util.generate_unique_name(comp.resource_name, name_list)

func filter_children(items: Array[TreeItem]) -> Array[TreeItem]:
	var result: Array[TreeItem] = items.duplicate()
	var i: int = result.size()
	while i > 0:
		i -= 1
		if result[i].get_parent() in items:
			result.remove_at(i)
	return result

	

func item_can_parent(item: TreeItem) -> bool:
	return item and not item_is_instanced(item) and item_get_comp(item) is Composite

#region Drag&Drop

func get_drop_parent(at_position: Vector2) -> TreeItem:
	var item: TreeItem = get_item_at_position(at_position)
	if item:
		match get_drop_section_at_position(at_position):
			-1:
				item = item.get_parent()
			1:
				item = item.get_next_in_tree().get_parent() if item.get_next_in_tree() else item.get_parent()
	return item

func move_items(to_position: Vector2, items: Array[TreeItem]) -> void:
	var item: TreeItem = get_drop_parent(to_position)
	if not item or not item_can_parent(item):
		return
	
	var index: int = get_drop_section_at_position(to_position)
	index = (item.get_index() + maxi(0, index)) if index != 0 else -1
	var target_parent: RationalComponent = item_get_comp(item)
	var top_components: Array[RationalComponent] = selection.get_top_selected_components()
	
	if target_parent in top_components or (target_parent is Decorator and 1 < top_components.size()):
		return
	
	if 1 < top_components.size() and target_parent is Decorator:
		return
	
	for comp: RationalComponent in top_components:
		request_reparent.emit(comp, get_root_comp().find_parent(comp), target_parent, index)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		match data.get("type", ""):
			"items" when data.get("source") == self:
				drop_mode_flags = DROP_MODE_INBETWEEN | DROP_MODE_ON_ITEM
				return item_can_parent(get_drop_parent(at_position))
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary: return
	match data.get("type", ""):
		"items" when data.get("items", []) is Array:
			move_items(at_position, data.get("items", []))

# { "type": "files", "files": ["res://BitMap.tres"], "from": @Tree@5673:<Tree#495833867875> }
func _get_drag_data(at_position: Vector2) -> Variant:
	if not get_root() or get_root().is_selected(0): return
	var selected_items: Array[TreeItem] = get_all_selected_items()
	
	if selected_items.is_empty():
		return null
	
	var vbox: VBoxContainer = VBoxContainer.new()
	for item: TreeItem in selected_items:
		var button: Button = Button.new()
		button.flat = true
		button.text = item.get_text(0)
		button.icon = item.get_icon(0)
		button.modulate.a = 0.65
		vbox.add_child(button)
	
	set_drag_preview(vbox)
	
	var selected_components: Array[RationalComponent] = []
	selected_components.assign(selected_components.map(item_get_comp))
	
	return {type = "items", items = selected_items, components = selected_components, source = self}

#endregion

#region Iterator

func _iter_init(iter: Array) -> bool:
	iter[0] = get_root()
	return iter[0] != null

func _iter_next(iter: Array) -> bool:
	iter[0] = iter[0].get_next_in_tree(false)
	return iter[0] != null

func _iter_get(iter: Variant) -> Variant:
	return iter

#endregion Iterator

func _on_selected_component(comp: RationalComponent, selected: bool) -> void:
	item_set_selected(comp_get_item(comp), selected)

func _on_multi_selected(item: TreeItem, column: int, selected: bool) -> void:
	if not deselect_queued:
		deselect_queued = true
		deselect_orphan_components.call_deferred()
	
	if selected:
		selection.add_component(item_get_comp(item))
		return
	
	selection.remove_component(item_get_comp(item))

## Removes all selected components not child to the root.
func deselect_orphan_components() -> void:
	if not active_root: return
	var tree_components: Array[RationalComponent] = get_root_comp().get_children(true)
	tree_components.push_back(get_root_comp())
	for comp: RationalComponent in selection.get_selected_components():
		if comp in tree_components: continue
		selection.remove_component(comp)
	deselect_queued = false
