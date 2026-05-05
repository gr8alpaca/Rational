@tool
extends EditorProperty

#const Util := preload("res://addons/rational/util.gd")
var picker: EditorResourcePicker


func _init(object: Object, property: String, base_type: String = "RationalComponent") -> void:
	use_folding = true
	set_object_and_property(object, property)
	label = property.capitalize()
	
	picker = EditorResourcePicker.new()
	picker.base_type = base_type
	picker.theme_type_variation = &"EditorInspectorButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.edited_resource = object.get(property)
	picker.focus_mode = Control.FOCUS_ALL
	picker.toggle_mode = true
	add_child(picker)
	add_focusable(picker)

	picker.resource_changed.connect(_on_picker_changed)
	picker.resource_selected.connect(_on_picker_selected)

func _update_property() -> void:
	var res: Resource = get_edited_object().get(get_edited_property()) if get_edited_object() else null
	if res == picker.edited_resource:
		return
	picker.edited_resource = get_edited_object().get(get_edited_property())


func _on_picker_changed(res: Resource) -> void:
	pass
	#emit_changed()

func _on_picker_selected(resource: Resource, inspect: bool) -> void:
	resource_selected.emit(get_edited_property(), resource)

func _on_editor_property_changed(property: StringName, value: Variant, field: StringName, changing: bool) -> void:
	pass
