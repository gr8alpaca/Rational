@tool
extends ResourceFormatSaver

func _recognize(resource: Resource) -> bool:
	return resource is RationalComponent

func _recognize_path(resource: Resource, path: String) -> bool:
	return false


# FLAG_NONE = 0
# No resource saving option.
# ● FLAG_RELATIVE_PATHS = 1
# Save the resource with a path relative to the scene which uses it.
# ● FLAG_BUNDLE_RESOURCES = 2
# Bundles external resources.
# ● FLAG_CHANGE_PATH = 4
# Changes the Resource.resource_path of the saved resource to match its new location.
# ● FLAG_OMIT_EDITOR_PROPERTIES = 8
# Do not save editor-specific metadata (identified by their __editor prefix).
# ● FLAG_SAVE_BIG_ENDIAN = 16
# Save as big endian (see FileAccess.big_endian).
# ● FLAG_COMPRESS = 32
# Compress the resource on save using FileAccess.COMPRESSION_ZSTD. Only available for binary resource types.
# ● FLAG_REPLACE_SUBRESOURCE_PATHS = 64
# Take over the paths of the saved subresources (see Resource.take_over_path()).


func _save(resource: Resource, path: String, flags: int) -> Error:
	if not resource:
		printerr("Cannot save <null> resource (rational_saver.gd)") 
		return ERR_INVALID_PARAMETER
	
	path = resource.resource_path if not path else path

	if not path or not path.is_valid_filename():
		printerr("Save path null or invalid")
		return ERR_INVALID_PARAMETER
	


	if flags < 0:
		printerr("Invalid SaveFlags < 0 (rational_saver.gd)")
		flags = 0
	
	return OK

# ERR_ALREADY_EXISTS
func _set_uid(path: String, uid: int) -> Error:
	return save_cache_uid(path, uid)

func load_cache() -> Dictionary:
	if not FileAccess.file_exists(get_cache_path("RationalSaver.dat")): return {}
	var result: Dictionary
	var fa:= FileAccess.open(get_cache_path("RationalSaver.dat"), FileAccess.READ_WRITE)
	if fa:
		while fa.get_position() < fa.get_length():
			var uid: int = fa.get_64()
			var bytes: PackedByteArray = PackedByteArray([fa.get_8()])
			while bytes[-1] != 0:
				bytes.push_back(fa.get_8())
			result[uid] = bytes.get_string_from_ascii()
		fa.close()
	return result

func save_cache_uid(path: String, uid: int) -> Error:
	if not path: 
		return ERR_FILE_BAD_PATH
	if not uid:
		return ERR_INVALID_DATA
	var fa:= FileAccess.open(get_cache_path("RationalSaver.dat"), FileAccess.READ_WRITE)
	if not fa:
		return FileAccess.get_open_error()
	fa.seek_end()
	if not fa.store_64(uid):
		return ERR_FILE_CANT_WRITE
	if not fa.store_buffer(path.to_ascii_buffer()) or not fa.store_8(0):
		return ERR_FILE_CANT_WRITE
	if not fa.store_8(0):
		return ERR_FILE_CANT_WRITE
	return OK

func copy_file_to(file: StringName, to: StringName) -> Error:
	if not FileAccess.file_exists(file):
		return ERR_FILE_NOT_FOUND
	var buffer:= FileAccess.get_file_as_bytes(file)
	if buffer.is_empty():
		return FileAccess.get_open_error()
	var fa:= FileAccess.open(to, FileAccess.WRITE)
	if not fa:
		return FileAccess.get_open_error()
	fa.store_buffer(buffer)
	return OK

func save_external_data() -> void:
	copy_file_to(get_cache_path("RationalSaver.dat"), get_data_file("tmp.dat"))

func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	const EXTENSIONS: PackedStringArray = ["tres", "res"]
	return EXTENSIONS

func get_cache_path(file: String) -> String:
	#EditorInterface.get_editor_paths().get_cache_dir()
	return "res://addons/rational/data/".path_join(file)

func get_data_file(file: String) -> String:
	#return EditorInterface.get_editor_paths().get_data_dir().path_join(file)
	return "res://".path_join(file)
