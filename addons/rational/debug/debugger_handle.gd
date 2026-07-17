## Exposes methods for scripts in scene to provide debug info.
@tool
class_name RationalDebuggerHandle


static func can_send_message() -> bool:
	return false #TBR
	return not Engine.is_editor_hint() and OS.is_debug_build() and OS.has_feature("editor") # Remove "editor"?

static func register_tree(tree_data: Dictionary) -> void:
	if tree_data and can_send_message():
		EngineDebugger.send_message("rational:register_tree", [tree_data])

static func unregister_tree(instance_id: int) -> void:
	if can_send_message():
		EngineDebugger.send_message("rational:unregister_tree", [instance_id])

static func process_tick(instance_id: int, status: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("rational:process_tick", [instance_id, status, blackboard])

static func process_begin(instance_id: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("rational:process_begin", [instance_id, blackboard])

static func process_end(instance_id: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("rational:process_end", [instance_id, blackboard])

static func process_interrupt(instance_id: int, blackboard: Dictionary = {}) -> void:
	if can_send_message():
		EngineDebugger.send_message("rational:process_interrupt", [instance_id, blackboard])
