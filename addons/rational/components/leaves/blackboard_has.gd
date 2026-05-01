## [Leaf] that returns SUCCESS if [Blackboard] has
## a key and FAILURE otherwise.
@tool
class_name BlackboardHas extends ConditionLeaf

## Specifies the [param section] to use when retrieving [Blackboard] value.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, Blackboard.DEFAULT + "," + Blackboard.SHARED)
var section: String = Blackboard.DEFAULT

## Specifies the [param key] to use when retrieving [Blackboard] value.
@export var key: String = ""

func _tick(delta: float, blackboard: Blackboard, actor: Node) -> int:
	var result: int = SUCCESS if blackboard.has(key, section) else FAILURE
	if result == FAILURE:
		print("%s FAILING..." % resource_name)
	return SUCCESS if blackboard.has(key, section) else FAILURE

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS
