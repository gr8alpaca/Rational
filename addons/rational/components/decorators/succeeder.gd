## [Decorator] that will always return [member SUCCESS]. Inverse of [Failer].
@icon("../../icons/Succeeder.svg")
@tool
class_name Succeeder extends Decorator

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children:
		children[0].tick(delta, board, actor)
	return SUCCESS

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children:
		children[0].tick(delta, board, actor)
	return SUCCESS
