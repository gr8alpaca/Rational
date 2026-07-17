@tool
extends EditorDebuggerPlugin

const INVALID_ID: int = -1
const DebugTab := preload("debugger_display.gd")

var display: DebugTab
var session: EditorDebuggerSession

var tree_data: Dictionary[int, Dictionary]

## 
var active_tree: int = INVALID_ID: set = set_active_tree

var tree_pending_activation: int = INVALID_ID


## True if the debug tab is visible in tree.
var visible: bool = false

func _init() -> void:
	display = DebugTab.new()
	tree_data = {}
	display.tree_data = tree_data
	display.graph.visibility_changed.connect(update_visibility)
	#display.visibility_changed.connect(update_visibility)
	display.tree_selected.connect(_on_tree_selected)
	
	var class_data: RefCounted = Engine.get_singleton(&"Rational").class_data
	class_data.class_data_updated.connect(update_icon_data, CONNECT_APPEND_SOURCE_OBJECT)
	update_icon_data(class_data)

func _has_capture(capture: String) -> bool:
	return capture == "rational"

func _capture(message: String, data: Array, session_id: int) -> bool:
	match message:
		"rational:register_tree":
			register_tree(data[0])
		"rational:unregister_tree":
			unregister_tree(data[0])
		"rational:process_tick":
			process_tick(data[0], data[1], data[2])
		"rational:process_begin":
			process_begin(data[0], data[1])
		"rational:process_end":
			process_end(data[0], data[1])
		"rational:process_interrupt":
			process_interrupt(data[0], data[1])
		_:
			push_warning("Message '%s' not recognized by Rational debugger." % message)
			return false
	return true

func _setup_session(session_id: int) -> void:
	session = get_session(session_id)
	session.started.connect(start_session)
	session.stopped.connect(stop_session)
	session.add_session_tab(display)

func start_session() -> void:

	display.start()
	update_visibility()

func stop_session() -> void:
	display.stop()
	display.visibility_changed.disconnect(update_visibility)
	display.tree_selected.disconnect(_on_tree_selected)
	tree_data.clear()

func update_visibility() -> void:
	visible = display.graph.is_visible_in_tree()


func register_tree(tree: Dictionary) -> void:
	if not tree.get("id", "") is int:
		printerr("ID in RationalTree data is not of type 'int' (%s)." % tree.get("id", "NULL")) 
		return
	
	var tree_id: int = tree.get("id", 0)
	tree_data[tree_id] = tree
	
	display.register_tree(tree)
	
	if tree_id == tree_pending_activation:
		set_active_tree(tree_id)

func unregister_tree(id: int) -> void:
	tree_data.erase(id)
	if active_tree == id:
		clear_active_tree()
	if tree_pending_activation == id:
		tree_pending_activation = INVALID_ID

func process_tick(id: int, status: int, board: Dictionary = {}) -> void:
	if id != active_tree: return

func process_interrupt(id: int, board: Dictionary = {}) -> void:
	if id != active_tree: return

func process_begin(id: int, board: Dictionary = {}) -> void:
	if id != active_tree: return

func process_end(id: int, board: Dictionary = {}) -> void:
	if id != active_tree: return

func set_active_tree(val: int) -> void:
	active_tree = val
	display.set_active_tree_id(val)

func clear_active_tree() -> void:
	active_tree = INVALID_ID

func update_icon_data(class_data: RefCounted) -> void:
	class_data

func _on_tree_selected(id: int) -> void:
	if not session or id == INVALID_ID or active_tree == id: return
	set_active_tree(id)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE when display and not display.is_queued_for_deletion():
			print_debug("Calling queue_free on Rational debug tab node %s" % display)
			display.queue_free()
