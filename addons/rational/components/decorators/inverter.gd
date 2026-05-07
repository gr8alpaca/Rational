## [Decorator] that will return the opposite status of its child unless the child returns [member RUNNING].
@tool
class_name Inverter extends Decorator

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children.is_empty():
		return SUCCESS
	return children[0].no_tick(delta, board, actor)

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if not children.is_empty(): 
		match children[0].tick(delta, board, actor):
			SUCCESS: return FAILURE
			FAILURE: return SUCCESS
			RUNNING: return RUNNING
	
	printerr("Decorator '%s' has no children" % resource_name)
	return FAILURE
