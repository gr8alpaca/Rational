## [Decorator] that will always return [member FAILURE]. Inverse of [Succeeder].
@icon("../../icons/Failer.svg")
@tool
class_name Failer extends Decorator

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children:
		children[0].no_tick(delta, board, actor)
	return FAILURE

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children:
		children[0].tick(delta, board, actor)
	return FAILURE
