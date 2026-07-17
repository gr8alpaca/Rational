@tool
class_name RationalDebuggerData extends RefCounted

const INVALID_ID: int = -1

signal tree_registered(id: int)
signal tree_unregistered(id: int)

signal tree_updated(id: int)

signal tree_activated(id: int)

var data: Dictionary[int, Dictionary]

var active_tree: int = INVALID_ID: set = set_active_tree

var tree_pending_activation: int = INVALID_ID




func register_tree(tree: Dictionary) -> void:
	if not tree.get("id", "") is int:
		printerr("ID in RationalTree data is not of type 'int' (%s)." % tree.get("id", "NULL")) 
		return
	
	var id: int = tree.get("id", 0)
	if has_tree(id):
		pass
	
	data[id] = tree
	
	if id == tree_pending_activation:
		set_active_tree(id)
	
	tree_registered.emit(id)


func unregister_tree(id: int) -> void:
	if not has_tree(id): return
	data.erase(id)
	tree_unregistered.emit(id)


func has_tree(id: int) -> bool:
	return id in data

func get_tree(id: int) -> Dictionary:
	return data.get(id, {})

func set_active_tree(val: int) -> void:
	if active_tree == val: return
	active_tree = val
	tree_activated.emit()
