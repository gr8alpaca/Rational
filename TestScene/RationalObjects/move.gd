@tool
class_name MoveAction extends ActionLeaf

@export_range(0.0, 200.0, 1.0, "suffix:px/s", "or_greater", "or_less") 
var speed: float = 50.0

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	actor.global_position = actor.global_position.move_toward(board.get_local("target_global_position", Vector2.ZERO), speed * delta)
	return RUNNING
