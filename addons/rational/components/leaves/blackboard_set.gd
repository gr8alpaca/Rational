## [Leaf] that sets a value in the passed 
## [Blackboard] and always returns SUCCESS.
@tool
class_name BlackboardSet extends ActionLeaf

## Specifies the [param section] to use when calling [method Blackboard.set_value].
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, Blackboard.DEFAULT + "," + Blackboard.SHARED)
var section: String = Blackboard.DEFAULT

## Specifies the [param key] to use when calling [method Blackboard.set_value].
@export var key: String = ""

## Indicates that you want to use an [Expression]
## as the [member value] to set.
@export var use_expression: bool: set = set_use_expresssion, get = get_use_expression

## Value to set blackboard [member key] to.
@export var value: Variant: set = set_value, get = get_value

## Expression that key in [Blackboard] will be set to.
## Executes expression using [member RationalTree.actor] as the 
## base instance and a reference to the blackboard as [code]board[/code].
@export_custom(PROPERTY_HINT_EXPRESSION, "", PROPERTY_USAGE_STORAGE) 
var value_expression: String = "": set = set_value_expression, get = get_value_expression

## Expression that is executed on [method RationalComponent.tick] call.
var expression: Expression = Expression.new()

## Represents if the current [member expression] is valid.
var expression_valid: bool = false

func _tick(delta: float, blackboard: Blackboard, actor: Node) -> int:
	print("TICK %s" % resource_name)
	blackboard.set_value(key, expression.execute([blackboard], actor, true) if use_expression else value, section)
	if expression.has_execute_failed():
		printerr("EXECUTION FAILED: %s" % self)
		return FAILURE
	#print("%s => %s" % [resource_name, blackboard.get_value(section, "<INVALID>", section)])
	return SUCCESS

func get_value_expression() -> String:
	return value_expression

func set_value_expression(val: String) -> void:
	value_expression = val
	expression_valid = expression.parse(value_expression, PackedStringArray(["board"])) == OK
	if not expression_valid and not Engine.is_editor_hint():
		push_error("Couldn't parse condition `%s`: %s" % [value_expression, expression.get_error_text()])

func get_use_expression() -> bool:
	return use_expression

func set_use_expresssion(val: bool) -> void:
	use_expression = val
	notify_property_list_changed()

func set_value(val: Variant) -> void:
	value = val

func get_value() -> Variant:
	return value

func _validate_property(property: Dictionary) -> void:
	if not use_expression: return
	match property.name:
		"value":
			property.usage &= ~(PROPERTY_USAGE_EDITOR)
		"value_expression":
			property.usage |= PROPERTY_USAGE_EDITOR
