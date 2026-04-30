@tool
class_name PrintUndoRedo
extends EditorScript

func _run() -> void:
	var ids: Dictionary[int, String] = {EditorUndoRedoManager.GLOBAL_HISTORY: "Global"}
	for node in EditorInterface.get_open_scene_roots():
		var id: int = EditorInterface.get_editor_undo_redo().get_object_history_id(node)
		if id < 1: continue
		ids[id] = node.scene_file_path
	
	for id: int in ids:
		print_undo_redo(EditorInterface.get_editor_undo_redo().get_history_undo_redo(id), ids[id])


func print_undo_redo(ur: UndoRedo, name: String) -> void:
	print("\n- - %s UndoRedo - -\n\tVersion: %d | Count: %d" % [name, ur.get_version(), ur.get_history_count()])
	print("\tIs Commiting: %s" % ur.is_committing_action())
	print("\tHas Undo: %s" % ur.has_undo())
	print("\tHas Redo: %s" % ur.has_redo())

	print("\n    FULL ACTION LIST")
	for id: int in ur.get_history_count():
		print("\t#%d: %s" % [id, ur.get_action_name(id)])
	print("- - - - - - - - - -\n")
