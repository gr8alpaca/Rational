@tool
extends PopupMenu

const Util:= preload("../util.gd")

enum {
	## No items, menu will be empty.
	ITEM_NONE = 0,
	
	## Add child component to parent.
	ITEM_ADD_CHILD = 1,
	
	## Cut selected components.
	ITEM_CUT = 2,
	
	## Copy selected components.
	ITEM_COPY = 4, 
	
	## Paste clipboard contents as children to selected component.
	ITEM_PASTE = 8,
	
	## Duplicate selected components.
	ITEM_DUPLICATE = 16, 
	
	## Duplicate selected component.
	ITEM_RENAME = 32, 
	
	## Change type of selected component.
	ITEM_CHANGE_TYPE = 64, 
	
	## Save selected component as the root of its own tree.
	ITEM_SAVE_AS_ROOT = 128, 
	
	## Open class documentation for this component.
	ITEM_DOCUMENTATION = 256, 
	
	## Delete selected components.
	ITEM_DELETE = 512,
	
	## Add node to selected spot in editor.
	ITEM_ADD_NODE_HERE = 1024,
	
	## Instantiate another root to selected spot in editor.
	ITEM_INSTANTIATE_HERE = 2048,
	
	## Instantiate another root as a child to selected component.
	ITEM_INSTANTIATE_CHILD = 4096,
	
	## Paste clipboard contents to selected spot in editor.
	ITEM_PASTE_HERE = 8192,
	
	## Paste clipboard contents as sibling to selected node.
	ITEM_PASTE_AS_SIBLING = 16384,
	
	## Move selected component up the tree.
	ITEM_MOVE_UP = 32768,
	
	## Move selected component down the tree.
	ITEM_MOVE_DOWN = 65536,
	
	## Reparent selected component.
	ITEM_REPARENT = 131072,
	
	## Move selected node(s) to a position in editor.
	ITEM_MOVE_NODE_HERE = 262144,
	
	## Reveal component in the editor window.
	ITEM_SHOW_IN_EDITOR = 524288,
	
	## Arrange all ancestors of selected component.
	ITEM_ARRANGE_SUBTREE = 1048576,

	## ITEM_CUT | ITEM_COPY | ITEM_DUPLICATE | ITEM_RENAME | ITEM_CHANGE_TYPE | ITEM_DOCUMENTATION | ITEM_DELETE
	ITEMS_DEFAULT = 886,
	
	## ITEM_ADD_NODE_HERE | ITEM_INSTANTIATE_HERE | ITEM_MOVE_NODE_HERE | ITEM_PASTE_HERE
	ITEMS_HERE = 273408,
	
	## All possible items.
	ITEMS_ALL = 2147483648,
}

func popup_at(options: int, at_position: Vector2, disabled_options: int = ITEM_NONE) -> void:
	set_menu_options(options)
	set_disabled(disabled_options)
	popup(Rect2(at_position, Vector2.ZERO))


func create_item(label: String, icon: StringName = &"", shortcut: StringName = "", id: int = -1, metadata: Variant = null) -> void:
	add_item(label, id)
	if icon:
		set_item_icon(item_count - 1, Util.get_icon(icon))
	if shortcut:
		set_item_shortcut(item_count - 1, Util.get_shortcut(shortcut))
		set_item_accelerator(item_count - 1, Util.get_accel(shortcut))
	if metadata != null:
		set_item_metadata(item_count -1, metadata)



func set_menu_options(options: int = ITEM_NONE) -> void:
	clear()
	if not options: return
	
	if options & ITEM_ADD_NODE_HERE:
		create_item("Add Component Here...", &"Add", &"add_child", ITEM_ADD_NODE_HERE)
	if options & ITEM_INSTANTIATE_HERE:
		create_item("Instantiate Component Here...", &"Instance", &"instantiate_child",ITEM_INSTANTIATE_HERE)
	if options & ITEM_PASTE_HERE:
		create_item("Paste Component(s) Here", &"ActionPaste", &"paste", ITEM_PASTE_HERE)
	if options & ITEM_MOVE_NODE_HERE:
		create_item("Move Component(s) Here", &"ToolMove", &"", ITEM_MOVE_NODE_HERE)
	if options & ITEM_ADD_CHILD:
		create_item("Add Child...", &"Add", &"add_child",ITEM_ADD_CHILD)
	if options & ITEM_INSTANTIATE_CHILD:
		create_item("Instantiate Child...", &"Instance", &"instantiate_child",ITEM_INSTANTIATE_CHILD)
	
	add_separator("")
	
	if options & ITEM_CUT:
		create_item("Cut", &"ActionCut", &"cut",ITEM_CUT)
	if options & ITEM_COPY:
		create_item("Copy", &"ActionCopy", &"copy",ITEM_COPY)
	if options & ITEM_PASTE:
		create_item("Paste", &"ActionPaste", &"paste",ITEM_PASTE)
	if options & ITEM_PASTE_AS_SIBLING:
		create_item("Paste as Sibling", &"ActionPaste", &"paste_as_sibling",ITEM_PASTE_AS_SIBLING)
	
	add_separator("")
	
	if options & ITEM_RENAME:
		create_item("Rename", &"Rename", &"rename",ITEM_RENAME)
	if options & ITEM_CHANGE_TYPE:
		create_item("Change Type...", &"RotateLeft", &"change_type",ITEM_CHANGE_TYPE)
	if options & ITEM_MOVE_UP:
		create_item("Move Up", &"MoveUp", &"move_up",ITEM_MOVE_UP)
	if options & ITEM_MOVE_DOWN:
		create_item("Move Down", &"MoveDown", &"move_down",ITEM_MOVE_DOWN)
	if options & ITEM_DUPLICATE:
		create_item("Duplicate", &"Duplicate", &"duplicate",ITEM_DUPLICATE)
	if options & ITEM_REPARENT:
		create_item("Reparent...", &"Reparent", &"reparent",ITEM_REPARENT)
	
	if options & ITEM_SAVE_AS_ROOT:
		add_separator("")
		create_item("Save As Root...", &"NewRoot", &"save_as_root", ITEM_SAVE_AS_ROOT)
	
	if options & ITEM_SHOW_IN_EDITOR:
		add_separator("")
		create_item("Show in Editor", &"ShowInFileSystem", &"show_in_file_system", ITEM_SHOW_IN_EDITOR)
	
	if options & ITEM_ARRANGE_SUBTREE:
		add_separator("")
		create_item("Arrange Subtree", &"GridLayout", &"", ITEM_ARRANGE_SUBTREE)
	
	if options & ITEM_DOCUMENTATION:
		add_separator("")
		create_item("Open Documentation", &"Help", &"",ITEM_DOCUMENTATION)
	if options & ITEM_DELETE:
		add_separator("")
		create_item("Delete", &"Remove", &"delete",ITEM_DELETE)
	
	# Clears any adjacent seperators
	var i: int = item_count
	while 1 < i:
		i -= 1
		if is_item_separator(i) and is_item_separator(i - 1):
			remove_item(i)
	
	# Clears separators on ends
	if is_item_separator(0):
		remove_item(0)
	if is_item_separator(item_count - 1):
		remove_item(item_count - 1)

# TBR if not used
func set_disabled(options: int = ITEM_NONE) -> void:
	if not options: return
	for index: int in item_count:
		if is_item_separator(index): continue
		set_item_disabled(index, options & get_item_id(index))
