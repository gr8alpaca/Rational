@tool
extends EditorInspectorPlugin

const INSP_STR: String = "[color=LIGHT_GREEN]Inspector[/color]"

func _init() -> void:
	var inspector: EditorInspector = EditorInterface.get_inspector()
	inspector.edited_object_changed.connect(_on_edited_object_changed)
	inspector.object_id_selected.connect(_on_object_id_selected)
	inspector.property_deleted.connect(_on_property_deleted)
	inspector.property_edited.connect(_on_property_edited)
	inspector.resource_selected.connect(_on_resource_selected)


## Returns the object currently selected in the [EditorInspector].
func get_edited() -> Object:
	return EditorInterface.get_inspector().get_edited_object()

## Returns the path of the currently selected property.
func get_path() -> String:
	return EditorInterface.get_inspector().get_selected_path()


## Emitted when the object being edited by the inspector has changed.
func _on_edited_object_changed() -> void:
	var obj: Object = get_meta(&"obj", weakref(null)).get_ref()
	print_rich("%s object [color=yellow]%s => %s[/color]" % [INSP_STR, obj, get_edited()])
	set_meta(&"obj", weakref(get_edited()))

## Emitted when the Edit button of an Object has been pressed in the inspector. 
## This is mainly used in the remote scene tree Inspector.
func _on_object_id_selected(id: int) -> void:
	print_rich("%s [color=orange]ID: %d => %d [/color]" % [INSP_STR, get_meta(&"id", 0), id])
	set_meta(&"id", id)

## Emitted when a property is removed from the inspector.
func _on_property_deleted(property: String) -> void:
	print_rich("%s [color=ORANGE_RED]Property '%s' deleted.[/color]" % [INSP_STR, property])
	set_meta(&"deleted", property)

## Emitted when a property is edited in the inspector.
func _on_property_edited(property: String) -> void:
	print_rich("%s [color=ORANGE_RED]Property '%s' edited.[/color]" % [INSP_STR, property])
	set_meta(&"prop", property)

## Emitted when a resource is selected in the inspector.
func _on_resource_selected(resource: Resource, path: String) -> void:
	print_rich("%s [color=gold]Resource '%s' @ %s selected. | (%s %s)[/color]" % [INSP_STR, resource, path, get_meta(&"res", "NULL"), get_meta(&"path", "")])
	set_meta(&"res", resource)
	set_meta(&"path", path)

func edit_root(root: RationalComponent) -> void:
	EditorInterface.edit_resource(root)

# TODO: Only handle rational components.
func _can_handle(object: Object) -> bool:
	return object is RationalTree or object is RationalComponent

# TODO: Prevent creating buttons for components that are not a root.
func _parse_begin(object: Object) -> void:
	if object is RationalComponent:
		var button: Button = create_button()
		button.pressed.connect(edit_root.bind(object))

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if object is RationalTree and name == "root":
		if get_meta(&"block_parse", false): 
			return false
		
		var button: Button = create_button()
		button.pressed.connect(_on_edit_pressed.bind(object, name))
		var ep: EditorProperty = instantiate_property_editor(object, type, name, hint_type, hint_string, usage_flags, wide)
		
		
		#var picker:= create_picker(object, name, "Composite")
		
		
		return true
	
	return false

func _on_edit_pressed(object: Object, property: String = "") -> void:
	if not object or not object.get(property) is RationalComponent: return
	edit_root(object.get(property))

func _on_picker_changed(res: Resource, editor_property: EditorProperty) -> void:
	editor_property.emit_changed(editor_property.get_edited_property(), res)
	if res:
		if not res.resource_name:
			res.resource_name = res.get_script().get_global_name()
		EditorInterface.edit_resource(res)


func _on_picker_selected(resource: Resource, inspect: bool, editor_property: EditorProperty) -> void:
	var picker: EditorResourcePicker = editor_property.get_child(-1)
	#editor_property.select(- int(editor_property.is_selected()))
	if inspect:
		editor_property.resource_selected.emit(editor_property.get_edited_property(), resource)
	
	#EditorInterface.edit_resource(resource)

func _on_editor_property_changed(property: StringName, value: Variant, field: StringName, changing: bool, picker: EditorResourcePicker) -> void:
	picker.set_block_signals(true)
	picker.set_edited_resource(value)
	picker.set_block_signals(false)

#region GUI

func _on_editor_changed(property: StringName, value: Variant, field: StringName, changing: bool) -> void:
	print_rich("[color=orange]%s | Changing %s | Object: %s => Value: %s[/color]" % [property, changing, get_edited().get(property), value])

func _on_editor_property_selected(path: String, focusable_idx: int) -> void:
	print("Editor Property selected | Path: %s | Focusable index: %d" % [path, focusable_idx])
	edit_root.call_deferred(get_edited().get(path))


func instantiate_property_editor(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, 
		hint_string: String, usage_flags: int, wide: bool) -> EditorProperty:
	set_meta(&"block_parse", true)
	
	var editor_property: EditorProperty = EditorInspector.instantiate_property_editor(object, type, name, hint_type, hint_string, usage_flags, wide)
	editor_property.set_object_and_property(object, name)
	add_property_editor(name, editor_property)
	editor_property.property_changed.connect(_on_editor_changed, )
	editor_property.selected.connect(_on_editor_property_selected)
	set_meta(&"block_parse", null)
	return editor_property

func create_picker(object: Object, property: String, base_type: String) -> EditorResourcePicker:
	var picker: EditorResourcePicker = EditorResourcePicker.new()
	picker.base_type = base_type
	picker.theme_type_variation = &"EditorInspectorButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.edited_resource = object.get(property)
	picker.focus_mode = Control.FOCUS_ALL
	picker.toggle_mode = true
	
	var eprop: EditorProperty = EditorProperty.new()
	eprop.use_folding = true
	eprop.set_object_and_property(object, property)
	eprop.label = property.capitalize()
	eprop.add_child(picker)
	eprop.add_focusable(picker)
	
	#eprop.selected.connect(_on_selected)
	
	eprop.property_changed.connect(_on_editor_property_changed.bind(picker))
	
	picker.resource_changed.connect(_on_picker_changed.bind(eprop))
	picker.resource_selected.connect(_on_picker_selected.bind(eprop))
	
	add_property_editor(property, eprop)
	return picker


func create_button() -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"InspectorActionButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = "Edit Tree"
	button.icon = Engine.get_singleton(&"Rational")._get_plugin_icon() if Engine.has_singleton(&"Rational") else \
			EditorInterface.get_editor_theme().get_icon(&"ExternalLink", &"EditorIcons")
	
	button.tooltip_text = "Switch to the behavior tree editor tab."
	
	var margin_container := MarginContainer.new()
	var margin: int = 4 * EditorInterface.get_editor_scale()
	margin_container.add_theme_constant_override("margin_left", margin)
	margin_container.add_theme_constant_override("margin_right", margin)
	margin_container.add_theme_constant_override("margin_top", margin)
	margin_container.add_theme_constant_override("margin_bottom", margin)
	
	add_custom_control(create_margin_container(button))
	return button


func create_margin_container(child_control: Control = null, margins: Vector2 = Vector2(4, 4), ) -> MarginContainer:
	margins *= EditorInterface.get_editor_scale()
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", margins.x)
	margin_container.add_theme_constant_override("margin_right", margins.x)
	margin_container.add_theme_constant_override("margin_top", margins.y)
	margin_container.add_theme_constant_override("margin_bottom", margins.y)
	if child_control: margin_container.add_child(child_control)
	return margin_container

#endregion GUI
