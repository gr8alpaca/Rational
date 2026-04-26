@tool
extends RefCounted
## Manages selected items for the Rational editor.

signal selected_component(component: RationalComponent, selected: bool)

var cache: RefCounted
var _changed_signal_queued: bool = false
var _data: Dictionary[RootData, Array]

func _init() -> void:
	_init_selection.call_deferred()

func _init_selection() -> void:
	cache = Engine.get_singleton(&"Rational").cache
	cache.data_erased.connect(_on_data_erased)

func add_component(component: RationalComponent) -> void:
	if not component or is_selected(component): return
	_get_selected().push_back(component)
	selected_component.emit(component, true)

func remove_component(component: RationalComponent) -> void:
	if not component or not is_selected(component): return
	_get_selected().erase(component)
	selected_component.emit(component, false)

func clear() -> void:
	if _get_selected().is_empty(): return
	var deselected_components: Array[RationalComponent] = get_selected_components()
	_get_selected().clear()
	for component: RationalComponent in deselected_components:
		selected_component.emit(component, false)

func is_selected(component: RationalComponent) -> bool:
	return component in _get_selected()

func get_selection_count() -> int:
	return _get_selected().size()

func _get_selected() -> Array[RationalComponent]:
	if not _get_key() in _data:
		var arr: Array[RationalComponent]
		_data[_get_key()] = arr
	return _data[_get_key()]

## Returns a duplicated array of selected components.
func get_selected_components() -> Array[RationalComponent]:
	return _get_selected().duplicate()

## Returns only parents—No children.
func get_top_selected_components() -> Array[RationalComponent]:
	var components: Array[RationalComponent] = get_selected_components()
	var i: int = components.size()
	while 0 < i:
		i -= 1
		for c: RationalComponent in components:
			if not c.has_child(components[i], true): continue
			components.remove_at(i)
			break
	return components

func _get_key() -> RootData:
	return cache.get_edited_tree()

func _on_data_erased(tree: RootData) -> void:
	_data.erase(tree)
