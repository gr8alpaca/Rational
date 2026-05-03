## [Decorator] that will return the opposite status of its child unless the child returns [member RUNNING].
@tool
class_name Inverter extends Decorator

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children.is_empty():
		return SUCCESS
	return children[0].no_tick(delta, board, actor)

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children.is_empty(): 
		printerr("Decorator '%s' has no children" % resource_name)
		breakpoint
	
	match children[0].tick(delta, board, actor):
		SUCCESS: return FAILURE
		FAILURE: return SUCCESS
		RUNNING: return RUNNING
	
	return FAILURE

#func remove_child(child: RationalComponent) -> void:
	#print("INVERTER REMOVE CHILD...")
	#super(child)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_POSTINITIALIZE:
			print("Inverter %s POSTINITIALIZED" % _to_string())
		NOTIFICATION_PREDELETE:
			print("Inverter %s PREDELETE" % (resource_name + " | " + resource_path))
