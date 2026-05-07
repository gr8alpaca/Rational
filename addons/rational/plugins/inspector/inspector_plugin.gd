@tool
extends EditorInspectorPlugin

var root_buttons: PackedInt64Array = PackedInt64Array()

func edit_root(root: RationalComponent, editor_only: bool = false) -> void:
	if not root: return
	Engine.get_singleton(&"Rational").cache.edit_root(root, true)

func edit_tree(tree: RationalTree) -> void:
	edit_root(tree.root, true)

func _can_handle(object: Object) -> bool:
	return object is RationalTree or object is RationalComponent

func _parse_begin(object: Object) -> void:
	if object is RationalComponent:
		var root_id: int = object.get_root_id()
		if not root_buttons.has(root_id):
			create_button().pressed.connect(edit_root.bind(object), CONNECT_DEFERRED)
			root_buttons.push_back(root_id)
			EditorInterface.get_inspector().edited_object_changed.connect(Callable.create(root_buttons, &"erase").bind(root_id), CONNECT_ONE_SHOT)
	elif object is RationalTree:
		create_button().pressed.connect(edit_tree.bind(object), CONNECT_DEFERRED)

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if get_meta(&"block_parse", false): return false
	var val: Variant = object.get(name) if object else null
	if val is RationalComponent:
		instantiate_property_editor(object, type, name, hint_type, hint_string, usage_flags, wide)
		return true
	elif val is Array[RationalComponent]:
		var ep: EditorProperty = instantiate_property_editor(object, type, name, hint_type, hint_string, usage_flags, wide)
		if object is RationalComponent:
			object.children_changed.connect(ep.update_property)
		return true
	return false

func instantiate_property_editor(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> EditorProperty:
	set_meta(&"block_parse", true)
	var editor_property: EditorProperty = EditorInspector.instantiate_property_editor(object, type, name, hint_type, hint_string, usage_flags, wide)
	editor_property.set_object_and_property(object, name)
	add_property_editor(name, editor_property)
	set_meta(&"block_parse", null)
	return editor_property

func create_button() -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"InspectorActionButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = "Edit Tree"
	button.tooltip_text = "Switch to the tree editor."
	button.icon = Engine.get_singleton(&"Rational")._get_plugin_icon()
	
	var con := MarginContainer.new()
	var margin: int = 4 * EditorInterface.get_editor_scale()
	con.add_theme_constant_override(&"margin_left", 4 * EditorInterface.get_editor_scale())
	con.add_theme_constant_override(&"margin_right", con.get_theme_constant(&"margin_left"))
	con.add_theme_constant_override(&"margin_top", con.get_theme_constant(&"margin_left"))
	con.add_theme_constant_override(&"margin_bottom", con.get_theme_constant(&"margin_left"))
	con.add_child(button)
	add_custom_control(con)
	
	return button
