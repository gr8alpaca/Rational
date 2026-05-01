## [Leaf] that performs a simple comparison with
## a value in the passed [Blackboard] and returns
## SUCCESS if true and FAILURE otherwise.
@tool
class_name BlackboardCompare extends ConditionLeaf

## Specifies the [param section] to use when retrieving [Blackboard] value.
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, Blackboard.DEFAULT + "," + Blackboard.SHARED)
var section: String = Blackboard.DEFAULT

## Specifies the [param key] to use when retrieving [Blackboard] value.
@export var key: String = ""

## Operator to use when comparing blackboard value.
## The [Blackboard] value will always be on the left
## and [member value] will be on the right side of the equation.
## e.g. [code]x < [/code][member value].
@export var operator: Variant.Operator = OP_EQUAL

## Value to be compare [Blackboard] value with.
## Always will be on the right side of the equation.
## e.g. [code]x < [/code][member value].
@export var value: Variant

## Value to compare against if blackboard does not have a value.
@export var default: Variant

func _tick(delta: float, blackboard: Blackboard, actor: Node) -> int:
	match operator:
		OP_EQUAL:
			return SUCCESS if blackboard.get_value(key, default, section) == value else FAILURE
		OP_NOT_EQUAL:
			return SUCCESS if blackboard.get_value(key, default, section) != value else FAILURE
		OP_LESS:
			return SUCCESS if blackboard.get_value(key, default, section) < value else FAILURE
		OP_LESS_EQUAL:
			return SUCCESS if blackboard.get_value(key, default, section) <= value else FAILURE
		OP_GREATER:
			return SUCCESS if blackboard.get_value(key, default, section) > value else FAILURE
		OP_GREATER_EQUAL:
			return SUCCESS if blackboard.get_value(key, default, section) >= value else FAILURE
	return FAILURE

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS

func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint(): return
	super(property)
	match property.name:
		"operator":
			var arr: PackedStringArray = property.hint_string.split(",")
			arr.resize(OP_GREATER_EQUAL + 1)
			property.hint_string = ",".join(arr)
			
