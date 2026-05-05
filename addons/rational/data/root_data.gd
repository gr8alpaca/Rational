@tool
class_name RootData extends RefCounted

const TIMEOUT_MSEC: int = 5000

static var _id_count: int = 0
static func generate_id() -> int:
	_id_count += 1
	return _id_count

## Emitted when data changed.
signal changed

signal tree_changed

signal request_edit

signal closed

signal unsaved_changes_changed

signal loaded

var id: int = -1

var root: RationalComponent: set = set_root, get = get_root

var path: String: set = set_path

var name: String: set = set_name

## Tracks if the tree is saved or not. It is saved when set to [code]-1[/code].
var saved_version: int = -1: set = set_saved_version

func _init(_path: String = "", _root: RationalComponent = null, _id: int = RootData.generate_id()) -> void:
	id = _id - int(_id == 0) # Prevents id == 0
	set_meta(&"_loading", true)
	# Must set path before root. 
	path = _path if _path or not _root else _root.resource_path
	root = _root
	
	Engine.get_main_loop().process_frame.connect(load_path, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func edit() -> void:
	request_edit.emit()

func is_root(_root: RationalComponent) -> bool:
	return _root and root == _root


func is_path(_path: String) -> bool:
	return path and path == _path 


func is_root_or_path(_root: RationalComponent, _path: String) -> bool:
	return is_root(_root) or is_path(_path)

func can_save() -> bool:
	return path != ""

func get_root_class() -> String:
	return root.get_script().get_global_name() if root else ""


func rename(to_name: String) -> void:
	if to_name == name: return
	name = to_name

func get_root() -> RationalComponent:
	return root

func set_root(val: RationalComponent) -> void:
		if root == val: return
		
		if root:
			root.changed.disconnect(_on_root_changed)
			root.script_changed.disconnect(_on_root_script_changed)
			root.tree_changed.disconnect(_on_tree_changed)
		
		root = val
		
		if root:
			name = root.resource_name
			root.changed.connect(_on_root_changed)
			root.script_changed.connect(_on_root_script_changed)
			root.tree_changed.connect(_on_tree_changed)
		
		changed.emit()

func set_path(val: String) -> void:
	if path == val: return
	path = val
	changed.emit()

func clear_path() -> void:
	if OS.is_stdout_verbose():
		print("Clearing path %s" % self)
	if root:
		root.resource_path = ""
	set_path("")

func set_name(val: String) -> void:
		if name == val: return
		name = val if val else get_root_class()
		if root and root.resource_name != name:
			root.resource_name = name
		changed.emit()

func save_as(save_path: String) -> Error:
	if not root:
		return ERR_INVALID_DATA
	
	if not save_path:
		return ERR_FILE_BAD_PATH
	
	if save_path == path:
		return save()
	
	var root_copy: RationalComponent = root.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	root_copy.take_over_path(save_path)
	return ResourceSaver.save(root_copy, save_path, )


func save() -> Error:
	if not root:
		return ERR_INVALID_DATA
	
	var err: int = ERR_BUG
	
	if root.is_built_in():
		err = OK
	
	#elif is_temp():
		#err = ERR_UNCONFIGURED
	
	#elif is_builtin():
		#if not is_scene_open():
			#printerr("Built-in Resource %s is open while scene is closed." % self)
		#elif not ResourceLoader.exists(path):
			#err = ERR_FILE_BAD_PATH
			# Removed because if resource not saved in scene will throw this error.
		#elif ResourceLoader.load(path, "Resource") != root:
			#err = ResourceSaver.save(root, "", )
			#EditorInterface.save_all_scenes()
			#ResourceLoader.load.call_deferred(get_scene_file(), "", ResourceLoader.CACHE_MODE_REPLACE)
		#else:
			#root.take_over_path(path)
			#err = OK
			
	
	elif not path.get_file().is_valid_filename() or not DirAccess.dir_exists_absolute(path.get_base_dir()):
		err = ERR_FILE_BAD_PATH
	
	else:
		#if root.resource_path != path:
			#root.take_over_path(path)
		err = ResourceSaver.save(root, path, ResourceSaver.FLAG_CHANGE_PATH)
	
	match err:
		OK:
			clear_version()
			path = root.resource_path
			if OS.is_stdout_verbose():
				print("Saved %s" % self)
		ERR_BUG:
			printerr("BUGGED => RootData did not return true for any of is_temp, is_external, is_builtin.")
		ERR_ALREADY_EXISTS:
			printerr("Error saving %s => %s. \nDESYNC: Resource loaded from path is different from RootData." %[self, error_string(err)])
		ERR_UNCONFIGURED, ERR_FILE_BAD_PATH, _:
			printerr("Error saving %s => %s" %[self, error_string(err)])
	
	return err


## Returns [code]true[/code] if [param save_path] is valid to save to.
func is_save_path_valid(save_path: String) -> bool:
	return path.get_file().is_valid_filename() and DirAccess.dir_exists_absolute(path.get_base_dir())

func serialize() -> Dictionary:
	return {
		id = id,
		path = path,
		root = root.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL),
		datetime = Time.get_datetime_string_from_system(),
		}

static func deserialize(data: Dictionary) -> RootData:
	var data_path: String = data.get("path", "") if data.get("path", "") is String else ""
	var data_root: RationalComponent = data.get("root", null) if data.get("root", null) is RationalComponent else null
	return RootData.new(data_path, data_root)

func load_path() -> void:
	
	if not path or (root and path == root.resource_path):
		update_reference()
		set_meta(&"_loading", null)
		loaded.emit()
		return
	
	var err:= await load_deferred()
	
	match err:
		OK:
			print_rich("[color=green]Loaded %s successfully.[/color]" % self)
		
		ERR_FILE_UNRECOGNIZED:
			printerr("Resource at path '%s' does not extend RationalComponent. Caching %s without path." % [path, self])
			clear_path()
		
		ERR_TIMEOUT:
			if is_builtin() and not is_scene_open():
				push_warning("Timeout trying to load '%s'. Closing..." % self)
				close()
			else:
				push_warning("Timeout trying to load '%s'. Closing..." % self)
				clear_path()
		_:
			printerr("Unknown error loading path '%s' => %s" % [path, error_string(err)])
			clear_path()
	
	set_meta(&"_loading", null)
	loaded.emit()


func load_deferred() -> Error:
	# Use Cached Ref for built-ins to avoid ResourceLoader throwing errors 'Resource file not found' and 'Error loading resource' .
	var check_callable: Callable = ResourceLoader.has_cached if is_builtin() else ResourceLoader.exists
	var load_callable: Callable = ResourceLoader.get_cached_ref if is_builtin() else ResourceLoader.load.bind("", ResourceLoader.CACHE_MODE_REPLACE)
	
	var start_tick: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_tick < TIMEOUT_MSEC:
		if check_callable.call(path):
			var res: Resource = load_callable.call(path)
			if not res is RationalComponent:
				printerr("Resource at path '%s' is not type 'RationalComponent'." % path)
				return ERR_FILE_UNRECOGNIZED
			
			set_root(res)
			return OK
		
		await Engine.get_main_loop().process_frame
	
	return ERR_TIMEOUT

func save_local_scene() -> void:
	if not get_local_scene(): return
	if not is_part_of_edited_scene(): 
		EditorInterface.open_scene_from_path
		return
	var current_scene: String = EditorInterface.get_edited_scene_root().scene_file_path
	EditorInterface.open_scene_from_path(root.get_local_scene().scene_file_path)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.open_scene_from_path.call_deferred(current_scene)

## Changes [member path] and [member root.resource_path] to [param to_path]
func update_path(to_path: String) -> void:
	path = to_path
	if root and not root.resource_path == to_path:
		take_over_path()

func is_saved() -> bool:
	return not is_loaded() or not root or not EditorInterface.is_object_edited(root)

func has_unsaved_changes() -> bool:
	return is_loaded() and root and EditorInterface.is_object_edited(root)

func set_saved_version(version: int) -> void:
	saved_version = version
	print("Version: %d | Edited: %s " % [saved_version, EditorInterface.is_object_edited(root), ])

## Call when making changes to root.
func change_version(old: int, new: int) -> void:
	if old == new: return
	
	if saved_version == -1:
		saved_version = old
	
	elif new == saved_version:
		saved_version = -1
		set_object_edited(false)
	
	if saved_version != -1:
		set_object_edited(true)
		
	#print("Change version %d => %d | Saved version: %d" % [old, new, saved_version])

func set_object_edited(edited: bool) -> void:
	var currently_edited: bool = EditorInterface.is_object_edited(root)
	EditorInterface.set_object_edited(root, edited)
	if currently_edited != edited:
		unsaved_changes_changed.emit()

func update_save_status() -> void:
	print("Updating save status: %s" % EditorInterface.is_object_edited(root))
	if EditorInterface.is_object_edited(root): return
	saved_version = -1
	unsaved_changes_changed.emit()

## Sets [member saved_version] to [code]-1[/code].
func clear_version() -> void:
	set_saved_version(-1)

## Sets to [code]-1[/code] if saved else [code]-2[/code].
func clear_save_version() -> void:
	saved_version = -2 + int(saved_version == -1)

func get_history_id() -> int:
	return maxi(0, EditorInterface.get_editor_undo_redo().get_object_history_id(root.get_local_scene() if root.get_local_scene() else root))

func _on_history_cleared(id: int) -> void:
	return
	if root.is_built_in(): return
	if id != get_history_id(): return
	clear_save_version()

func _on_root_changed() -> void:
	name = root.resource_name
	path = root.resource_path

func _on_root_script_changed() -> void:
	changed.emit()

func _on_tree_changed() -> void:
	tree_changed.emit()

func is_loaded() -> bool:
	return not get_meta(&"_loading", false)

## Returns [code]true[/code] if root is saved to file.
func is_external() -> bool:
	return FileAccess.file_exists(path)

## Returns [code]true[/code] if root is subresource of a PackedScene.
func is_builtin() -> bool:
	return path.contains("::")

## Returns [code]true[/code] if root has no path and is only saved in cache.
func is_temp() -> bool:
	return not path

func get_local_scene() -> Node:
	return root.get_local_scene() if root else null

func is_part_of_edited_scene() -> bool:
	return get_local_scene().is_part_of_edited_scene() if get_local_scene() else false

## Returns file of scene if root is built-in else returns [code]""[/code]
func get_scene_file() -> String:
	return path.get_slice("::", 0) if is_builtin() else ""

## Returns Resource ID in scene if root is built-in else returns [code]""[/code]
func get_scene_id() -> String:
	return path.get_slice("::", 1) if is_builtin() else ""

func is_in_scene(filepath: String) -> bool:
	return filepath and is_builtin() and path.contains(filepath)

func is_scene_open() -> bool:
	return get_scene_file() in EditorInterface.get_open_scenes()

func take_over_path() -> void:
	if not root or not path: return
	root.take_over_path(path) 

## Returns [code]true[/code]/[code]false[/code] if [member root] is ancestor of [param component]. 
func is_owner_of(component: RationalComponent) -> bool:
	return root and root.has_child(component, true)

## Returns [code]true[/code]/[code]false[/code] if [member root] is ancestor of [param component]. 
func is_path_owner(res_path: String) -> bool:
	if not res_path: return false
	if res_path == path or (root and root.resource_path == res_path):
		return true
	if not root:
		return false
	if ResourceLoader.has_cached(res_path):
		return root.has_child(ResourceLoader.get_cached_ref(res_path), true)
	for child: RationalComponent in root.get_children(true):
		if child.resource_path == res_path:
			return true
	return false

func update_reference() -> void:
	if not ResourceLoader.has_cached(path): return
	if root != ResourceLoader.get_cached_ref(path):
		root = ResourceLoader.get_cached_ref(path)

func close() -> void:
	if is_closed(): return
	set_meta(&"root_closed", true)
	closed.emit()

func is_closed() -> bool:
	return get_meta(&"root_closed", false)

func is_valid() -> bool:
	return not is_closed() #and not is_loading()

func _to_string() -> String:
	return ("RootData: %s" % root) if root else ("RootData: %s" % path)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			print("PREDELETE RootData: ID: %d | %s | %s" % [id, name, path, ])
	
