@tool
extends VBoxContainer

signal property_changed(property: StringName, value: Variant, field: StringName, changing: bool)

#var cache: RefCounted = Engine.get_singleton(&"Rational").cache
var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()

var block_property_signal: bool = false

func update_display(comp: Object) -> void:
	clear()
	disconnect_signals()
	
	if not comp: 
		return
	
	comp.property_list_changed.connect(_on_property_list_changed, CONNECT_APPEND_SOURCE_OBJECT)
	
	for prop: Dictionary in get_component_properties(comp):
		var ep: EditorProperty = EditorInspector.instantiate_property_editor(comp, prop.type, prop.name, prop.hint, prop.hint_string, prop.usage)
		ep.mouse_filter = Control.MOUSE_FILTER_STOP
		ep.draw_background = false
		ep.selectable = false
		ep.use_folding = true
		ep.set_object_and_property(comp, prop.name)
		ep.label = prop.name
		ep.update_property()
		ep.property_changed.connect(_on_property_edited, CONNECT_APPEND_SOURCE_OBJECT)
		add_child(ep)

# changing refers to whether the EditorProperty itself needs to be changed, not anything to do with the value.
func _on_property_edited(property: StringName, value: Variant, field: StringName, changing: bool, ep: EditorProperty) -> void:
	#printt("Property Edited...", property, changing, ep.get_edited_object(), ep.get_edited_object().get(property), value)
	if block_property_signal or not property or not ep.get_edited_object() or ep.get_edited_object().get(property) == value: return
	
	# CHAD PROGRAMMER ALERT
	var graph_edit: GraphEdit = Engine.get_singleton(&"Rational").editor.graph_edit
	
	var comp: RationalComponent = ep.get_edited_object()
	if not graph_edit.create_action("Set %s" % property, UndoRedo.MERGE_ENDS, graph_edit.comp_in_tree(comp)):
		return
	
	undo_redo.add_undo_method(self, &"set_component_property", comp, property, comp.get(property))
	undo_redo.add_do_method(self, &"set_component_property", comp, property, value)
	graph_edit.commit(false)

func _on_property_list_changed(comp: RationalComponent) -> void:
	update_display(comp)

func set_component_property(comp: RationalComponent, property: StringName, value: Variant) -> void:
	if not comp: return
	
	comp.set(property, value)
	
	for ep: EditorProperty in get_editor_properties():
		if ep.get_edited_property() != property: continue
		block_property_signal = true
		ep.update_property()
		block_property_signal = false
		return

func has_focus_recursive(node: Node) -> bool:
	if not node: return false
	
	if node is Control and node.has_focus():
		return true
		
	for child in node.get_children(true):
		if has_focus_recursive(child):
			return true
	
	return false

func get_editor_properties() -> Array[EditorProperty]:
	var result: Array[EditorProperty]
	for child in get_children():
		if not child is EditorProperty: continue
		result.push_back(child)
	return result

func clear() -> void:
	for ep: EditorProperty in get_editor_properties():
		remove_child(ep)
		ep.free()

func disconnect_signals() -> void:
	for con: Dictionary in get_incoming_connections():
		if con.callable == _on_property_list_changed:
			con.signal.disconnect(con.callable)

func get_component_properties(comp: Object) -> Array[Dictionary]:
	var result: Array[Dictionary]
	const IGNORED_PROPERTY_NAMES: PackedStringArray = ["children", "child", "resource_local_to_scene", "resource_path", "resource_name", "script"]
	for property: Dictionary in comp.get_property_list():
		if not (property.usage & PROPERTY_USAGE_EDITOR): continue
		if property.name.contains("metadata/"): continue
		if property.name in IGNORED_PROPERTY_NAMES: continue
		result.push_back(property)
	return result

func has_properties() -> bool:
	return 0 < get_child_count()
