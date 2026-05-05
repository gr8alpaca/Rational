@tool
@icon("../icons/RationalTree.svg")
class_name RationalTree extends Node

signal tree_enabled
signal tree_disabled

signal ticked(value: int)

enum {SUCCESS, FAILURE, RUNNING}
enum ProcessThread {IDLE, PHYSICS, NONE}

@export var root: RationalComponent: set = set_root

# ALERT TBR DEBUG ONLY
@export_custom(0, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var root_id: String:
	get(): return root.resource_path.get_slice("::", 1) if root else ""

@export var actor: Node: set = set_actor

@export var blackboard: Blackboard: set = set_blackboard

@export var disabled: bool = true: set = set_disabled

@export var process_thread: ProcessThread = ProcessThread.IDLE: set = set_process_thread

var status: int = -1
#var last_tick: int = -1

func _ready() -> void:
	if Engine.is_editor_hint():
		update_process()
		if root:
			root.set_meta(&"tree_id", get_instance_id())
			#root.set_meta(&"path", str())
		editor_state_changed.connect(_on_editor_state_changed)
		return
	
	blackboard = Blackboard.new() if not blackboard else blackboard
	actor = get_parent() if not actor else actor
	blackboard.set_value("actor", actor)
	
	if name == &"RationalTree" and root:
		root.print_tree_pretty()
	
	update_process()

func _process(delta: float) -> void:
	tick(delta)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> int:
	status = root.tick(delta, blackboard, actor)
	ticked.emit(status)
	return status

func can_tick() -> bool:
	return not disabled and not Engine.is_editor_hint() and root and blackboard

func set_root(val: RationalComponent) -> void:
	if root and root != val and root.get_meta(&"tree_id", -1) == get_instance_id():
		root.set_meta(&"tree_id", null)
		root.set_meta(&"path", null)
	
	root = val
	update_process()
	
	if root:
		root.set_meta(&"tree_id", get_instance_id())
		#root.set_meta(&"path", "%s:root" % owner.get_path_to(self))

func update_process() -> void:
	set_process(process_thread == ProcessThread.IDLE and can_tick())
	set_physics_process(process_thread == ProcessThread.PHYSICS and can_tick())
	assert(not (is_processing() and is_physics_processing()))

func set_disabled(val: bool) -> void:
	disabled = val
	
	update_process()
	
	if disabled:
		tree_disabled.emit()
	else:
		tree_enabled.emit()

func set_blackboard(val: Blackboard) -> void:
	if not Engine.is_editor_hint() and not val:
		val = Blackboard.new()
	blackboard = val

func set_actor(val: Node) -> void:
	if not Engine.is_editor_hint() and not val:
		val = get_parent()
	actor = val

func set_process_thread(val: ProcessThread) -> void:
	process_thread = val
	update_process()

func _on_editor_state_changed() -> void:
	print_rich("[color=orange]Editor State Changed %s[/color]" % name)
