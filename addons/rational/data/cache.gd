## Manages [RationalComponent] roots and stores editor data.
@tool
extends RefCounted

const FILE_CACHE: String = "cache.cfg"
const FILE_BACKUP: String = "rational_root_backup.cfg"

const SECTION: String = "root_data_list"


signal data_added(data: RootData)
signal data_erased(data: RootData)

signal data_closed(data: RootData)

## Emited when [param root] needs to be saved via file dialog.
signal request_save_as(data: RationalComponent)

## Emitted when the selected RationalComponent tree root changes.
signal edited_tree_changed(data: RootData)

var root_data_list: Array[RootData]

var edited_tree: RootData: set = set_edited_tree, get = get_edited_tree

func _init() -> void:
	EditorInterface.get_file_system_dock().files_moved.connect(_on_file_moved)
	EditorInterface.get_resource_filesystem().resources_reload.connect(_on_resources_reload)

func inspect_object(obj: Object, property: String = "") -> void:
	if get_meta(&"inspect_queued", false) or EditorInterface.get_inspector().get_edited_object() == obj: return
	set_meta(&"inspect_queued", true)
	EditorInterface.inspect_object(obj, property, true)
	if EditorInterface.get_inspector().get_edited_object() != obj:
		EditorInterface.get_inspector().edited_object_changed.connect(remove_meta.bind(&"inspect_queued"), CONNECT_ONE_SHOT)
		return
	remove_meta(&"inspect_queued")

func _on_resources_reload(resources: PackedStringArray) -> void:
	print("Resources Reloaded:\n", "\n\t".join(resources) )

func get_edited_id() -> int:
	return edited_tree.id if edited_tree else 0

func get_edited_tree() -> RootData:
	return edited_tree

func get_edited_root() -> RationalComponent:
	return edited_tree.root if edited_tree else null

func can_edit_tree(tree: RootData) -> bool:
	return edited_tree != tree and (not tree or tree.is_valid())

func set_edited_tree(val: RootData) -> void:
	if edited_tree == val: return
	
	if not can_edit_tree(val):
		return
	
	if val and (not val in root_data_list):
		add_data(val)
	
	edited_tree = val
	
	edited_tree_changed.emit(val)

## Sets [param tree_data] as the [member edited_tree] and opens [param tree_data.root] in the Rational editor
## and [EditorInpsector]. If [param editor_only] is [code]true[/code] then the editor will edit
## [param tree_data]  without setting [EditorInspector] and changing editor screens.
func edit_tree(tree_data: RootData, editor_only: bool = false) -> void:
	if not tree_data or not tree_data in root_data_list: return
	if not editor_only:
		inspect_object(tree_data.root)
	EditorInterface.set_main_screen_editor("Rational")
	set_edited_tree(tree_data)

## Will create data if it doesn't already exist and
## [method comp_is_root] returns [code]true[/code] for [param root].
func edit_root(root: RationalComponent, editor_only: bool = false) -> void:
	if not root: return
	var real_root: RationalComponent = root.get_root()
	if real_root != root:
		pass
	#if not comp_is_root(root):
		#push_warning("Cannot edit root %s as it is currently owned." % root)
		#return
	edit_tree(get_or_add_root(root), editor_only)


## Returns [code]true[/code] if [param comp] is not owned and therefore a tree root. 
func comp_is_root(comp: RationalComponent) -> bool:
	return comp and comp.is_root()

func comp_get_owner(comp: RationalComponent) -> RootData:
	for data: RootData in root_data_list:
		if data_owns_comp(data, comp):
			return data
	return null

func data_owns_comp(data: RootData, comp: RationalComponent) -> bool:
	return data.is_owner_of(comp)

func data_owns_path(data: RootData, path: String) -> void:
	pass

func edit_file(path: String) -> void:
	if not FileAccess.file_exists(path): return
	edit_root(ResourceLoader.load(path))

func edit_id(id: int) -> void:
	edit_tree(get_id(id))

func get_data(root: RationalComponent = null, path: String = "", default: RootData = null) -> RootData:
	for r: RootData in root_data_list:
		if r.is_root(root) or r.is_path(path):
			return r
	return default

func has_data(root_data: RootData) -> bool:
	return get_data(root_data.root, root_data.path) != null

func path_get_data(path: String) -> RootData:
	for data: RootData in get_data_list():
		if data.is_path(path):
			return data
	return null

func has_path(path: String) -> bool:
	return path_get_data(path) != null

func root_get_data(root: RationalComponent) -> RootData:
	for data: RootData in get_data_list():
		if data.is_root(root):
			return data
	return null

func has_root(root: RationalComponent) -> bool:
	return root_get_data(root) != null

func has_root_or_path(root: RationalComponent, path: String) -> bool:
	return get_data(root, path) != null

func get_id(id: int) -> RootData:
	for data: RootData in get_data_list():
		if data.id == id:
			return data
	return null

func has_id(id: int) -> bool:
	return get_id(id) != null

func add_data(root_data: RootData) -> void:
	if not root_data or has_data(root_data): return 
	if root_data.is_closed(): return
	
	root_data_list.push_back(root_data)
	root_data.request_edit.connect(_on_data_request_edit, CONNECT_APPEND_SOURCE_OBJECT)
	root_data.closed.connect(erase_data, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_ONE_SHOT)
	
	data_added.emit(root_data)

func get_or_add_path(path: String) -> RootData:
	return add_path(path)

func get_or_add_root(root: RationalComponent) -> RootData:
	return add_root(root)

func add_root(root: RationalComponent) -> RootData:
	if not root: return null
	
	root = root.get_root()
	
	if has_root(root):
		return root_get_data(root)
	
	var data: RootData = RootData.new(root.resource_path, root)
	add_data(data)
	return data


func add_path(path: String) -> RootData:
	if not path or has_path(path): return null
	var data: RootData = RootData.new(path)
	add_data(data)
	return data


func erase_data(data: RootData) -> void:
	if not data: return
	
	if not data.is_closed():
		data.close()
		return
	
	if edited_tree == data:
		set_edited_tree(null)
	
	if data in root_data_list:
		root_data_list.erase(data)
	
	if data.is_edited() and data.is_external():
		data.save()
	
	store_data_backup(data)
	
	assert(not has_data(data), "Rational cache data persists after close: %s" % data)

func erase_path(path: String) -> void:
	erase_data(path_get_data(path))

func get_data_list() -> Array[RootData]:
	return root_data_list

## Returns [RootData] associated in [param scene_path]. 
func scene_get_data(scene_path: String) -> Array[RootData]:
	var result: Array[RootData]
	result.assign(root_data_list.filter(func(data: RootData) -> bool: return data.is_in_scene(scene_path)))
	return result

func get_open_path_list() -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray()
	for data in root_data_list:
		if not data.path: continue
		list.push_back(data.path)
	return list

func close_scene_data(scene_path: String) -> void:
	return
	for data: RootData in scene_get_data(scene_path):
		data.close()

func reload_scene_data(scene_path: String) -> void:
	print("Reloading scene data '%s'" % scene_path)

func _on_scene_changed(node: Node) -> void:
	pass

func _on_scene_saved(scene_path: String) -> void:
	for data: RootData in scene_get_data(scene_path):
		data.update_save_status()


func _on_file_moved(from: String, to: String) -> void:
	for data: RootData in root_data_list:
		if data.path != from: continue
		data.update_path(to)
		return

func _on_resource_removed(res: Resource) -> void:
	pass
	#if res is RationalComponent and has_root(res):
		#get_data(res).clear_path()

func _on_data_request_edit(data: RootData) -> void:
	if data.is_closed(): return
	edit_tree(data)

#region Save/Load

func is_loading() -> bool:
	return get_meta(&"loading", false)

func save_external_data() -> void:
	save()

func get_save_path(file: String = FILE_CACHE) -> String:
	return get_script().resource_path.get_base_dir().path_join(file)

func get_unsaved_status(scene_path: String) -> String:
	var unsaved_roots: PackedStringArray = PackedStringArray()
	for rd: RootData in (scene_get_data(scene_path) if scene_path else root_data_list):
		if not rd.is_edited(): continue
		unsaved_roots.push_back("%s(#%d) - %s" % [rd.name, rd.id, rd.get_scene_id()])
	
	if unsaved_roots.is_empty():
		return ""
	
	return "The following Rational trees are unsaved:\n\n● %s" % "\n●".join(unsaved_roots)

func apply_changes() -> void:
	pass
	#for data in root_data_list:
		#data.take_over_path()

func save_and_close() -> void:
	save()
	set_meta(&"block_saving", true)
	print_rich("[color=yellow]BLOCKING CACHE SAVES[/color]")
	for data in get_data_list():
		data.close()

func save() -> void:
	if get_meta(&"block_saving", false): return
	var root_data: Array[Dictionary]
	for rd: RootData in get_data_list():
		if rd.is_temp(): continue
		
		if rd.is_edited():
			rd.save()
		
		root_data.push_back(rd.serialize())
	
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, "datetime", Time.get_datetime_string_from_system())
	cfg.set_value(SECTION, "version", Engine.get_singleton(&"Rational").get_plugin_version())
	cfg.set_value(SECTION, "roots", root_data)
	var err:= cfg.save(get_save_path())
	
	if err == OK:
		if OS.is_stdout_verbose():
			print_rich("[color=green]Cache saved %d roots.[/color]" % root_data.size())
	else:
		printerr("Rational cache save error: %s" % error_string(err))


func load() -> void:
	if is_loading(): return
	set_meta(&"loading", true)
	
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await Engine.get_main_loop().process_frame
	
	var cfg: ConfigFile = ConfigFile.new()
	var err:= cfg.load(get_save_path())
	if err != OK:
		printerr("Error loading Rational files: %s.\nCheck save file '%s'." % [error_string(err), get_save_path()])
		return
	
	for dict: Dictionary in cfg.get_value(SECTION, "roots", []):
		add_data(RootData.deserialize(dict))

func save_data_as(data: RootData) -> void:
	if not data: return
	request_save_as.emit(data)


func store_data_backup(data: RootData) -> void:
	pass

func get_window_layout(configuration: ConfigFile) -> void:
	configuration.set_value("Rational", "open_path_list", get_open_path_list())


func set_window_layout(configuration: ConfigFile) -> void:
	if not configuration.get_value("Rational", "open_path_list", PackedStringArray()) is PackedStringArray: return
	print(" | ".join(configuration.get_value("Rational", "open_path_list", PackedStringArray())))

#endregion Save/Load
