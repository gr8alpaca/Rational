@tool
extends EditorPlugin

const Util := preload("util.gd")
const Settings := preload("settings.gd")

const InpsectorPlugin := preload("plugins/inspector/inspector_plugin.gd")

const Cache := preload("data/cache.gd")
const ClassData := preload("data/rational_class_data.gd")
const Selection := preload("editor/selection.gd")

const WindowWrapper := preload("editor/window_wrapper.gd")
const Editor := preload("editor/main.gd")

var inspector_plugin: InpsectorPlugin

var cache: Cache
var class_data: ClassData
var selection: Selection

var window_wrapper: WindowWrapper
var editor: Editor

# TODO - EditorResourceConversionPlugin ?

func _enter_tree() -> void:
	name = &"Rational"
	Engine.register_singleton(&"Rational", self)
	
	Settings.populate()
	
	resource_saved.connect(_on_resource_saved)
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	scene_closed.connect(_on_scene_closed)
	get_script_create_dialog().script_created.connect(_on_script_created)
	
	cache = Cache.new()
	class_data = ClassData.new()
	
	selection = Selection.new()
	
	window_wrapper = WindowWrapper.new()
	
	editor = preload("editor/main.tscn").instantiate()
	editor.ready.connect(editor.propagate_call.bind(&"init_editor"), CONNECT_ONE_SHOT)
	
	EditorInterface.get_editor_main_screen().add_child(window_wrapper)
	
	inspector_plugin = InpsectorPlugin.new()
	add_inspector_plugin(inspector_plugin)
	
	print_rich("[b]Rational™ initialized[/b]")


func _exit_tree() -> void:
	window_wrapper.queue_free()
	
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
	cache = null
	class_data = null
	selection = null
	
	Engine.unregister_singleton(&"Rational")

func _handles(object: Object) -> bool:
	return object is RationalComponent

func _edit(object: Object) -> void:
	cache.edit_root(object)

func _make_visible(visible: bool) -> void:
	window_wrapper.make_visible(visible)

func _has_main_screen() -> bool:
	return true

func _get_plugin_icon() -> Texture2D:
	return preload("icon.svg")

func _get_plugin_name() -> String:
	return "Rational"

func _save_external_data() -> void:
	cache.save_external_data()

func _get_unsaved_status(for_scene: String) -> String:
	return cache.get_unsaved_status(for_scene)

func _build() -> bool:
	return true

func _apply_changes() -> void:
	pass

func _get_window_layout(configuration: ConfigFile) -> void:
	window_wrapper.get_window_layout(configuration)
	cache.get_window_layout(configuration)
	editor.propagate_call(&"get_window_layout", [configuration])

func _set_window_layout(configuration: ConfigFile) -> void:
	window_wrapper.set_window_layout(configuration)
	cache.set_window_layout(configuration)
	editor.propagate_call(&"set_window_layout", [configuration])

func _on_scene_changed(node: Node) -> void:
	if not node: return
	cache._on_scene_changed(node)

func _on_scene_closed(filepath: String) -> void:
	cache.close_scene_data(filepath)

func _on_scene_saved(filepath: String) -> void:
	print_rich("Scene saved: [color=yellow]%s[/color] " % [filepath])
	#if filepath == "res://TestScene/test_scene_character.tscn":
		#var file_string: String = FileAccess.get_file_as_string(filepath)
		#if get_meta(&"file_string", file_string) != file_string:
			#print_rich("[color=red]FILE CHANGED[/color]")
		#set_meta(&"file_string", file_string)
	cache._on_scene_saved(filepath)

func _on_file_moved(old_file: String, new_file: String) -> void:
	cache.update_path(old_file, new_file)

func _on_resource_saved(res: Resource) -> void:
	if res is Script: return
	print_rich("Resource saved: [color=yellow]%s[/color] @ [color=pink]%s[/color]" % [res, res.resource_path])
	#if res is RationalComponent:
		#print("Adding root... %s" % res)
		#print_rich("Resource saved: %s([color=yellow]%s[/color]) @ [color=pink]%s[/color]" % [res.resource_name, res, res.resource_path])

## TODO: Adds '@tool' to RationalComponent Scripts that don't have it already.
func _on_script_created(script: Script) -> void:
	if not script: return
	print_rich("Script Created: [color=green]%s[/color] [color=yellow]%s[/color] @ [color=pink]%s[/color]" % [script.get_global_name(), script])
	var base: Script = script.get_base_script()
	while base and base.get_global_name() != &"RationalComponent":
		base = base.get_base_script()
	
	if not base:
		return

	print("New script is tool: %s" % script.is_tool())
	print("New script contains '@tool': %s" % script.source_code.containsn("@tool"))
