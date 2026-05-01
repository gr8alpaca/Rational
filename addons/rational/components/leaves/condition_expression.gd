## [Leaf] that returns SUCCESS if its expression evaluates
## to [code]true[/code] and [code]false[/code] otherwise.
@tool
class_name ConditionExpression extends ConditionLeaf

## Expression that will return [code]SUCCESS[/code] if true
## and [code]FAILURE[/code] if false. Executes expression using [member RationalTree.actor]
## as the base instance and a reference to the blackboard as [code]board[/code].
@export_custom(PROPERTY_HINT_EXPRESSION, "") 
var condition: String = "": set = set_condition, get = get_condition

## Expression that is executed on [method RationalComponent.tick] call.
var expression: Expression = Expression.new()

## Represents if the current [member condition] and [member expression] are valid.
var expression_valid: bool = false

func set_condition(value: String) -> void:
	condition = value
	
	expression_valid = expression.parse(condition, PackedStringArray(["board"])) == OK
	if not expression_valid and not Engine.is_editor_hint():
		push_error("Couldn't parse condition `%s`: %s" % [condition, expression.get_error_text()])

func get_condition() -> String:
	return condition

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if not expression_valid:
		return FAILURE
		
	var result: Variant = expression.execute([board], actor, true)
	
	if expression.has_execute_failed():
		return FAILURE
	
	#if not result:
		#print("%s Condition Failed" % resource_name)
	
	return SUCCESS if result else FAILURE
