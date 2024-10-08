@tool
class_name Decorator extends Composite


func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	return modify_response((children[0].tick(delta, board, actor)))


func modify_response(response: int) -> int:
	return response


func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"Decorator")
	return names


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Decorator child count != 1"]) if children.size() != 1 else PackedStringArray()


func _validate_property(property: Dictionary) -> void:
	if property["name"] == &"children":
		property["usage"] = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE


func _get(property: StringName) -> Variant:
	return children[0] if property == &"child" and not children.is_empty() else null


func _set(property: StringName, value: Variant) -> bool:
	if property == &"child":
		var childs: Array[RationalComponent]
		if value: childs.push_back(value)
		children = childs

	return super(property, value)


func _get_property_list() -> Array[Dictionary]:
	return [{
				"name": &"child",
				"type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE,
				"hint_string": &"RationalComponent",
				"usage": PROPERTY_USAGE_EDITOR,
			}] 

func _property_can_revert(property: StringName) -> bool:
	if property == &"child":
		return not children.is_empty()
	return false
