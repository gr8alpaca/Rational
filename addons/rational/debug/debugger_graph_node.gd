@tool
extends GraphNode

const Style := preload("editor_style.gd")

const PORT_RADIUS: float = 7.0

var icon_rect: TextureRect
var title_label: Label
var status_label: Label 

var panels_tween: Tween

var horizontal: bool
var status: int = -1

func _init() -> void:
	custom_minimum_size = Vector2(50, 50) * EditorInterface.get_editor_scale()
	draggable = false
	
	add_theme_color_override("close_color", Color.TRANSPARENT)
	add_theme_icon_override("close", ImageTexture.new())
	
	icon_rect = TextureRect.new()
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0) * EditorInterface.get_editor_scale()
	
	status_label = Label.new()
	update_status() # Sets panel, text and port colors.
	add_child(status_label)
	
	# Attempt using titlebar.get_child(0) instead
	title_label = Label.new()
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_override("font", Style.title_font)
	
	var titlebar: HBoxContainer = get_titlebar_hbox()
	titlebar.get_child(0).queue_free()
	titlebar.add_child(title_label)
	titlebar.add_child(icon_rect)

func set_icon(icon: Texture2D) -> void:
	icon_rect.texture = icon

func set_title_text(text: String) -> void:
	title_label.text = text

func update_status() -> void:
	status_label.text = status_string(status)
	match status:
		RationalComponent.SUCCESS:
			set_color(Style.SUCCESS_COLOR)
			set_stylebox_overrides(Style.panel_success, Style.titlebar_success)
		RationalComponent.FAILURE:
			set_color(Style.FAILURE_COLOR)
			set_stylebox_overrides(Style.panel_failure, Style.titlebar_failure)
		RationalComponent.RUNNING:
			set_color(Style.RUNNING_COLOR)
			set_stylebox_overrides(Style.panel_running, Style.titlebar_running)
		_:
			set_color(Style.NORMAL_COLOR)
			set_stylebox_overrides(Style.panel_normal, Style.titlebar_normal)

func status_string(status: int) -> String:
	match status:
		RationalComponent.SUCCESS: return "Status: SUCCESS"
		RationalComponent.FAILURE: return "Status: FAILURE"
		RationalComponent.RUNNING: return "Status: RUNNING"
	return " "

func set_color(color: Color) -> void:
	set_slot_color_left(0, color)
	set_slot_color_right(0, color)

func set_stylebox_overrides(panel_stylebox: StyleBox, titlebar_stylebox: StyleBox) -> void:
	if not has_theme_stylebox_override("panel") or panel_stylebox != Style.panel_normal:
		if panels_tween:
			panels_tween.kill()
		
		add_theme_stylebox_override("panel", panel_stylebox)
		add_theme_stylebox_override("titlebar", titlebar_stylebox)
	
	if panels_tween:
		return
	
	# Don't need to do anything if our colors are already the same as a normal
	var cur_panel_stylebox: StyleBox = get_theme_stylebox("panel")
	var cur_titlebar_stylebox: StyleBox = get_theme_stylebox("titlebar")
	if cur_panel_stylebox.bg_color == Style.panel_normal.bg_color:
		return
	
	# Apply a duplicate of our current panels that we can tween
	add_theme_stylebox_override("panel", cur_panel_stylebox.duplicate())
	add_theme_stylebox_override("titlebar", cur_titlebar_stylebox.duplicate())
	cur_panel_stylebox = get_theme_stylebox("panel")
	cur_titlebar_stylebox = get_theme_stylebox("titlebar")
	
	# Going back to normal is a fade
	panels_tween = create_tween().set_parallel()
	panels_tween.tween_property(cur_panel_stylebox, "bg_color", panel_stylebox.bg_color, 1.0)
	panels_tween.tween_property(cur_panel_stylebox, "border_color", panel_stylebox.border_color, 1.0)
	panels_tween.tween_property(cur_titlebar_stylebox, "bg_color", panel_stylebox.bg_color, 1.0)
	panels_tween.tween_property(cur_titlebar_stylebox, "border_color", panel_stylebox.border_color, 1.0)

func _draw_port(slot_index: int, port_position: Vector2i, left: bool, color: Color) -> void:
	const POINT_COUNT: int = 8
	const ANGLE_UP: float = PI/2.0
	const ANGLE_DOWN: float = 3.0/2.0 * PI
	const ANGLE_OFFSET: float = 0.2
	if horizontal:
		if left and is_slot_enabled_left(0):
			draw_arc(Vector2(0, size.y / 2), PORT_RADIUS/2.0, ANGLE_DOWN + ANGLE_OFFSET, ANGLE_UP - ANGLE_OFFSET , POINT_COUNT, color, PORT_RADIUS, true)
		elif not left and is_slot_enabled_right(0):
			draw_arc(Vector2(size.x, size.y / 2), PORT_RADIUS/2.0, -ANGLE_UP - ANGLE_OFFSET, ANGLE_UP + ANGLE_OFFSET, POINT_COUNT, color, PORT_RADIUS, true)
	else:
		if left and is_slot_enabled_left(0):
			draw_arc(Vector2(size.x / 2, 0), PORT_RADIUS/2.0, -PI - ANGLE_OFFSET, ANGLE_OFFSET, POINT_COUNT, color, PORT_RADIUS, true)
		elif not left and is_slot_enabled_right(0):
			draw_arc(Vector2(size.x / 2, size.y), PORT_RADIUS/2.0, - ANGLE_OFFSET, PI + ANGLE_OFFSET, POINT_COUNT, color, PORT_RADIUS, true)

func get_input_position() -> Vector2:
	return Vector2(0, size.y / 2) if horizontal else Vector2(size.x / 2, 0)

func get_output_position() -> Vector2:
	return Vector2(size.x, size.y / 2) if horizontal else Vector2(size.x / 2, size.y)
