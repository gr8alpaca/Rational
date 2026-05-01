## Composite node that ticks each child in [member children] in order until the child does not return [member FAILURE]. 
## Returns [member FAILURE] only if all [member children] return [member FAILURE]. Inverse of [Sequence].
@icon("../icons/Fallback.svg")
@tool
class_name Fallback extends Composite


func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	for child: RationalComponent in children:
		print("Falling back to %s" % child.resource_name)
		var status: int = child.tick(delta, board, actor)
		if status != FAILURE: return status
	return FAILURE
