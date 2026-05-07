## A type of [Composite] that only holds a single child.
@abstract
@tool
class_name Decorator extends Composite

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

# Ignores idx
func add_child(child: RationalComponent, idx: int = -1) -> void:
	if not can_parent(child): return
	if not children.is_empty():
		remove_child(children[0])
	super(child)

## Does nothing because there should only be one child/index.
func move_child(child: RationalComponent, to_index: int) -> void:
	pass

func set_children(val: Array[RationalComponent]) -> void:
	val = val.filter(can_parent)
	val.resize(mini(1, val.size()))
	super(val)
