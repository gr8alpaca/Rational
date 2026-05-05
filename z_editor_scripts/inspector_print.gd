@tool
class_name PrintInspector extends EditorScript

func _run() -> void:
	print_rich("[color=LIGHT_GREEN]Inspector[/color] OBJECT: %s | PATH: %s | Is Edited: %s" % [
		 EditorInterface.get_inspector().get_edited_object(), 
		EditorInterface.get_inspector().get_selected_path(),
		EditorInterface.is_object_edited(EditorInterface.get_inspector().get_edited_object())
		])
	
	if not Engine.has_singleton(&"Rational"):
		return
	
	var plug: EditorInspectorPlugin = Engine.get_singleton(&"Rational").inspector_plugin
	if plug.has_meta(&"deleted"):
		print_rich("\t[color=KHAKI]Deleted path: %s" % plug.get_meta(&"deleted", ""))
	if plug.has_meta(&"prop"):
		print_rich("\t[color=KHAKI]Last Edited Property: %s" % plug.get_meta(&"prop", ""))
	if plug.has_meta(&"res"):
		print_rich("\t[color=KHAKI]Selected Resource: %s | Path: %s" % [plug.get_meta(&"res", ""), plug.get_meta(&"path", "")])
