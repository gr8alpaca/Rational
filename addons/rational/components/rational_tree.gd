@tool
@icon("../icons/RationalTree.svg")
class_name RationalTree extends Node

signal tree_enabled
signal tree_disabled

signal ticked(value: int)

enum {SUCCESS, FAILURE, RUNNING}
enum ProcessThread {IDLE, PHYSICS, NONE}

@export var root: RationalComponent: set = set_root

@export var actor: Node: set = set_actor

@export var blackboard: Blackboard: set = set_blackboard

@export var disabled: bool = true: set = set_disabled

@export var process_thread: ProcessThread = ProcessThread.IDLE: set = set_process_thread

var status: int = -1
#var last_tick: int = -1


func _enter_tree() -> void:
	if not Engine.is_editor_hint(): return
	#RationalDebuggerMessages.register_tree()


func _exit_tree() -> void:
	pass


func _ready() -> void:
	if Engine.is_editor_hint():
		update_process()
		return
	
	blackboard = Blackboard.new() if not blackboard else blackboard
	actor = get_parent() if not actor else actor
	blackboard.set_value("actor", actor)
	
	update_process()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	tick(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	tick(delta)

func tick(delta: float) -> int:
	status = root.tick(delta, blackboard, actor)
	ticked.emit(status)
	return status

func can_tick() -> bool:
	return not disabled and not Engine.is_editor_hint() and root and blackboard

func set_root(val: RationalComponent) -> void:
	if root:
		root.set_node(null)
	
	root = val
	update_process()
	
	if root:
		root.set_node(self)

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

func get_debug_info() -> Dictionary:
	var data : Dictionary = {
		id = get_instance_id(),
		path = get_path(),
		name = name,
	}
	
	return data
