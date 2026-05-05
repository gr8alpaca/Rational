@tool
extends RefCounted
## Manages selected items for the Rational editor.

signal selected_component(component: RationalComponent, selected: bool)

var cache: RefCounted = Engine.get_singleton(&"Rational").cache
var _changed_signal_queued: bool = false

## [RootData.id]  => [RationalComponent] instance_id.
var _data: Dictionary[int, PackedInt64Array]

func add_component(component: RationalComponent) -> void:
	if not component or is_selected(component): return
	_get_selected().push_back(component.get_instance_id())
	selected_component.emit(component, true)

## Removes [param component] from selected
func remove_component(component: RationalComponent) -> void:
	if not component: return 
	if _get_selected().erase(component.get_instance_id()):
		selected_component.emit(component, false)

func clear() -> void:
	if _get_selected().is_empty(): return
	var deselected_components: Array[RationalComponent] = get_selected_components()
	_get_selected().clear()
	for component: RationalComponent in deselected_components:
		selected_component.emit(component, false)

func is_selected(component: RationalComponent) -> bool:
	return component and component.get_instance_id() in _get_selected()

func get_selection_count() -> int:
	return _get_selected().size()

func _get_selected() -> PackedInt64Array:
	return id_get_selected(get_id())

func id_get_selected(id: int) -> PackedInt64Array:
	if not id in _data:
		if not id: return PackedInt64Array()
		_data[id] = PackedInt64Array()
	return _data[id]

## Returns a duplicated array of selected components.
func get_selected_components() -> Array[RationalComponent]:
	_validate_selected()
	var selected: Array[RationalComponent]
	selected.assign(Array(_get_selected()).map(instance_from_id))
	return selected

## Returns only parents—No children.
func get_top_selected_components() -> Array[RationalComponent]:
	return filter_children(get_selected_components())

## NOTE: Also filters null values.
func filter_children(components: Array[RationalComponent]) -> Array[RationalComponent]:
	components.assign(components.filter(is_instance_valid).filter(func(comp: RationalComponent) -> bool: 
			return not components.any(func (c: RationalComponent) -> bool: return c.has_child(comp))))
	return components

func _validate_selected() -> void:
	var selected: PackedInt64Array = _get_selected()
	var i: int = selected.size()
	while 1 < i:
		i -= 1
		if not is_instance_id_valid(selected[i]):
			selected.remove_at(i)

func get_id() -> int:
	return cache.get_edited_id()

func erase_id(id: int) -> bool:
	return _data.erase(id)
