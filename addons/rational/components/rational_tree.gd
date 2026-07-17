## [Node] that manages a [RationalComponent] tree.
@tool
@icon("../icons/RationalTree.svg")
class_name RationalTree extends Node

signal tree_enabled
signal tree_disabled

signal ticked(value: int)

## Determines the [Thread] to attempt to call [method tick].
enum ProcessThread {
	## Tree will attempt to call [method tick] during [method _process] calls.
	IDLE = 0, 
	## Tree will attempt to call [method tick] during [method _physics_process] calls.
	PHYSICS = 1, 
	## Tree [method tick] will not be called and must be done manually.
	NONE = 2,
}

@export var root: RationalComponent: set = set_root

@export var actor: Node: set = set_actor

@export var blackboard: Blackboard: set = set_blackboard

@export var disabled: bool = true: set = set_disabled

@export var process_thread: ProcessThread = ProcessThread.IDLE: set = set_process_thread

var status: int = -1
#var last_tick: int = -1

var debug_active: bool

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	RationalDebuggerHandle.register_tree(get_debug_data())

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	RationalDebuggerHandle.unregister_tree(get_instance_id())

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Set to clear any null values.
		blackboard = blackboard
		actor = actor
		
		blackboard.set_value("actor", actor)
	
	update_process()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	tick(delta)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> int:
	if Engine.is_editor_hint(): return RationalComponent.FAILURE
	blackboard.debug_active = debug_active
	if debug_active:
		RationalDebuggerHandle.process_begin(get_instance_id(), blackboard.get_debug_data())
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
	(tree_disabled if disabled else tree_enabled).emit()

func set_blackboard(val: Blackboard) -> void:
	if Engine.is_editor_hint():
		blackboard = val
		return
	
	blackboard = val if val else Blackboard.new()
	if actor:
		blackboard.set_actor(actor)

func set_actor(val: Node) -> void:
	if Engine.is_editor_hint():
		actor = val
		return
	
	actor = val if val else get_parent()
	blackboard.set_actor(actor)

func set_process_thread(val: ProcessThread) -> void:
	process_thread = val
	update_process()

## Return data for debugger.
func get_debug_data() -> Dictionary:
	return {
		"id" = get_instance_id(),
		"name" = get_name(),
		"class" = get_script().get_global_name(),
		"path" = get_path(),
		"root" = comp_get_data(root),
	}

## Returns debugger data for [param comp] and all children recursively.
func comp_get_data(comp: RationalComponent) -> Dictionary:
	if not comp: return {}
	var data: Dictionary = {
		"id" = comp.get_instance_id(),
		"name" = comp.get_name(),
		"class" = comp.get_script().get_global_name(),
		"children" = Array([], TYPE_DICTIONARY, &"", null),
	}
	for child: RationalComponent in comp.get_children():
		if not child: continue
		data.children.push_back(comp_get_data(child))
	return data
