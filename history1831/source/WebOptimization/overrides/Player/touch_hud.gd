extends CanvasLayer

@onready var player: Player = get_parent()
@onready var interact_button: Button = $SafeArea/InteractButton
@onready var info_panel: PanelContainer = $SafeArea/InformationPanel
@onready var info_title: Label = $SafeArea/InformationPanel/Margin/VBox/Title
@onready var info_kicker: Label = $SafeArea/InformationPanel/Margin/VBox/LetterHeader/Kicker
@onready var info_image: TextureRect = $SafeArea/InformationPanel/Margin/VBox/OriginalImage
@onready var info_body: Label = $SafeArea/InformationPanel/Margin/VBox/Body
@onready var info_disclaimer: Label = $SafeArea/InformationPanel/Margin/VBox/Disclaimer
@onready var info_question: Label = $SafeArea/InformationPanel/Margin/VBox/Question
@onready var info_answer: Label = $SafeArea/InformationPanel/Margin/VBox/Answer
@onready var notice: Label = $SafeArea/Notice

var notice_tween: Tween
var audio_muted := false
var look_touch_index := -1
var information_pages: Array[Dictionary] = []
var information_page_index := 0
var pending_task_completion := ""
var touch_moves: Dictionary = {}
var touch_positions: Dictionary = {}
var last_touch_msec := -1000
var information_scroll: ScrollContainer
var touch_navigation := false
var browser_ui_scale := 1.0

func _ready() -> void:
	touch_navigation = OS.has_feature("mobile")
	_configure_information_layout()
	get_viewport().size_changed.connect(_release_touch_controls)
	get_viewport().size_changed.connect(_resize_touch_layout)
	call_deferred("_resize_touch_layout")
	_bind_hold_button($SafeArea/MovePad/Up, &"move_forward")
	_bind_hold_button($SafeArea/MovePad/Down, &"move_backwards")
	_bind_hold_button($SafeArea/MovePad/Left, &"move_left")
	_bind_hold_button($SafeArea/MovePad/Right, &"move_right")
	$SafeArea/LookZone.gui_input.connect(_on_look_zone_input)
	interact_button.pressed.connect(player.try_interact)
	$SafeArea/ResetView.pressed.connect(_reset_view_pressed)
	$SafeArea/SoundToggle.pressed.connect(_toggle_audio)
	$SafeArea/InformationPanel/Margin/VBox/Next.pressed.connect(_show_next_information_page)
	$SafeArea/InformationPanel/Margin/VBox/Close.pressed.connect(hide_information)
	$SafeArea/InformationPanel/Margin/VBox/LetterHeader/LetterClose.pressed.connect(hide_information)
	$SafeArea/StandButton.pressed.connect(player.stand_up)
	$SafeArea/IntroOverlay/Center/Panel/Margin/VBox/Begin.pressed.connect(_enter_stuttgart_room)
	set_interaction_available(false)
	var is_stuttgart := get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("Stuttgart_Graybox.tscn")
	$SafeArea/IntroOverlay.visible = is_stuttgart
	if is_stuttgart:
		$SafeArea/SceneHeader/VBox/Subtitle.text = "1831年9月·斯图加特"
		player.set_controls_locked(true)

func _bind_hold_button(button: BaseButton, action: StringName) -> void:
	button.button_down.connect(func() -> void: _mouse_move_press(action))
	button.button_up.connect(func() -> void: _mouse_move_release(action))
	button.mouse_exited.connect(func() -> void:
		if _mouse_input_allowed() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			Input.action_release(action)
	)

func _mouse_move_press(action: StringName) -> void:
	if _mouse_input_allowed():
		Input.action_press(action)

func _mouse_move_release(action: StringName) -> void:
	if _mouse_input_allowed():
		Input.action_release(action)

func _mouse_input_allowed() -> bool:
	# A held finger remains a touch gesture even after a pause with no drag events.
	return touch_positions.is_empty() and Time.get_ticks_msec() - last_touch_msec > 700

func _reset_view_pressed() -> void:
	if look_touch_index == -1 and touch_moves.is_empty():
		player.reset_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		last_touch_msec = Time.get_ticks_msec()
		if event.pressed:
			touch_positions[event.index] = event.position
			if not player.controls_locked and not info_panel.visible:
				var buttons := {"Up": &"move_forward", "Down": &"move_backwards", "Left": &"move_left", "Right": &"move_right"}
				for key in buttons:
					var button := get_node("SafeArea/MovePad/" + key) as Control
					if button.is_visible_in_tree() and button.get_global_rect().has_point(event.position):
						touch_moves[event.index] = buttons[key]
						Input.action_press(buttons[key])
						get_viewport().set_input_as_handled()
						break
		else:
			touch_positions.erase(event.index)
			if touch_moves.has(event.index):
				var action: StringName = touch_moves[event.index]
				touch_moves.erase(event.index)
				if not touch_moves.values().has(action):
					Input.action_release(action)
				get_viewport().set_input_as_handled()
			if event.index == look_touch_index:
				look_touch_index = -1
				player.stop_touch_look()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		last_touch_msec = Time.get_ticks_msec()
		if not touch_positions.has(event.index):
			return
		var previous: Vector2 = touch_positions[event.index]
		touch_positions[event.index] = event.position
		if event.index == look_touch_index:
			# Track this finger globally, including when it crosses another GUI control.
			# Absolute positions avoid mouse-relative deltas shared by multiple pointers.
			player.apply_touch_look(event.position - previous)
			get_viewport().set_input_as_handled()
		elif touch_moves.has(event.index):
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_touch_controls()

func _release_touch_controls() -> void:
	for action in [&"move_forward", &"move_backwards", &"move_left", &"move_right"]:
		Input.action_release(action)
	touch_moves.clear()
	touch_positions.clear()
	last_touch_msec = Time.get_ticks_msec()
	look_touch_index = -1
	if is_instance_valid(player):
		player.stop_touch_look()

func _on_look_zone_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and look_touch_index == -1 and not touch_moves.has(event.index) and not info_panel.visible:
			look_touch_index = event.index
			$SafeArea/LookZone.accept_event()
		elif not event.pressed and event.index == look_touch_index:
			look_touch_index = -1
			$SafeArea/LookZone.accept_event()
	elif event is InputEventMouseMotion and event.device != -1 and _mouse_input_allowed() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		player.apply_touch_look(event.relative)
		$SafeArea/LookZone.accept_event()

func set_interaction_available(available: bool, label: String = "查看") -> void:
	interact_button.modulate = Color(1.0, 0.86, 0.48, 1.0) if available else Color(0.72, 0.72, 0.72, 0.72)
	interact_button.text = label if available else "交互"

func set_seated(value: bool) -> void:
	$SafeArea/StandButton.visible = value
	$SafeArea/MovePad.visible = not value
	$SafeArea/ResetView.visible = not value

func _enter_stuttgart_room() -> void:
	$SafeArea/IntroOverlay.visible = false
	player.set_controls_locked(false)

func show_information(title: String, body: String) -> void:
	show_information_pages(title, PackedStringArray([body]))

func show_information_pages(title: String, pages: PackedStringArray) -> void:
	var formatted_pages: Array[Dictionary] = []
	for page_text in pages:
		formatted_pages.append({"text": page_text, "image_path": "", "button": "下一步", "disclaimer": ""})
	_show_structured_information(title, formatted_pages)

func show_virtual_information(title: String, body: String, question: String, answer: String, disclaimer: String, display_image_path: String = "") -> void:
	var pages: Array[Dictionary] = [
		{"text": question, "image_path": "", "button": "显示参考答案", "disclaimer": disclaimer},
		{"text": "参考答案：" + answer, "image_path": "", "button": "关闭", "disclaimer": ""},
	]
	_show_structured_information(title, pages)

func show_teaching_letter(title: String, body: String, question: String, answer: String, disclaimer: String) -> void:
	var pages: Array[Dictionary] = [
		{"letter": true, "text": body, "disclaimer": disclaimer, "button": "进入课堂问题"},
		{"text": "课堂提问\n\n" + question, "button": "显示参考答案"},
		{"text": "参考答案\n\n" + answer, "button": "关闭"},
	]
	_show_structured_information(title, pages)

func show_historical_information(title: String, original_image_path: String, source_body: String, translation_body: String, classroom_question: String, reference_answer: String) -> void:
	var pages: Array[Dictionary] = [
		{"text": source_body, "image_path": original_image_path, "button": "查看中文翻译"},
		{"text": "中文教学节译\n\n" + translation_body, "image_path": "", "button": "进入课堂问题"},
		{"text": "课堂提问\n\n" + classroom_question, "image_path": "", "button": "显示参考答案"},
		{"text": "参考答案\n\n" + reference_answer, "image_path": "", "button": "返回原件"},
	]
	_show_structured_information(title, pages)

func _show_structured_information(title: String, pages: Array[Dictionary]) -> void:
	_release_touch_controls()
	player.set_controls_locked(true)
	info_title.text = title
	information_pages = pages
	information_page_index = 0
	_render_information_page()
	info_panel.visible = true
	_set_browser_fullscreen_button(false)

func _render_information_page() -> void:
	if information_pages.is_empty():
		info_body.text = ""
		info_image.visible = false
		return
	var page := information_pages[information_page_index]
	var is_letter: bool = bool(page.get("letter", false))
	$SafeArea/InformationPanel/Margin/VBox/LetterHeader.visible = is_letter
	info_kicker.text = "教学情境信件" if is_letter else ""
	info_question.text = str(page.get("question", ""))
	info_question.visible = is_letter and not info_question.text.is_empty()
	info_answer.text = str(page.get("answer", ""))
	info_answer.visible = is_letter and not info_answer.text.is_empty()
	$SafeArea/InformationPanel/Margin/VBox/Close.visible = not is_letter
	info_body.size_flags_vertical = Control.SIZE_FILL
	info_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP if is_letter else VERTICAL_ALIGNMENT_CENTER
	_resize_information_panel()
	information_scroll.scroll_vertical = 0
	info_title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86, 1) if is_letter else Color(0.96, 0.78, 0.4, 1))
	info_body.text = str(page.get("text", ""))
	var disclaimer := str(page.get("disclaimer", ""))
	info_disclaimer.text = disclaimer
	info_disclaimer.visible = not disclaimer.is_empty()
	info_disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_letter else HORIZONTAL_ALIGNMENT_RIGHT
	info_disclaimer.add_theme_font_size_override("font_size", 19 if is_letter else 14)
	var image_path := str(page.get("image_path", ""))
	info_image.visible = not image_path.is_empty()
	info_image.texture = load(image_path) as Texture2D if not image_path.is_empty() else null
	var next_button: Button = $SafeArea/InformationPanel/Margin/VBox/Next
	next_button.visible = bool(page.get("show_next", information_pages.size() > 1))
	next_button.text = str(page.get("button", "下一步")) if is_letter else "%s  %d/%d" % [str(page.get("button", "下一步")), information_page_index + 1, information_pages.size()]

func _show_next_information_page() -> void:
	if information_pages.is_empty():
		return
	if information_page_index == information_pages.size() - 1 and str(information_pages[information_page_index].get("button", "")) == "关闭":
		hide_information()
		return
	information_page_index = (information_page_index + 1) % information_pages.size()
	_render_information_page()

func hide_information() -> void:
	var reached_answer := not information_pages.is_empty() and information_page_index == information_pages.size() - 1
	var completed_task := pending_task_completion if reached_answer else ""
	pending_task_completion = ""
	info_panel.visible = false
	_set_browser_fullscreen_button(true)
	if not player.seated:
		player.set_controls_locked(false)
	info_disclaimer.visible = false
	information_pages.clear()
	information_page_index = 0
	if not completed_task.is_empty():
		for tracker in get_tree().get_nodes_in_group("warsaw_task_tracker"):
			if tracker.has_method("register_warsaw_task"):
				tracker.register_warsaw_task(completed_task)

func _toggle_audio() -> void:
	audio_muted = not audio_muted
	AudioServer.set_bus_mute(0, audio_muted)
	$SafeArea/SoundToggle.text = "声音" if audio_muted else "静音"

func show_notice(message: String) -> void:
	notice.text = message
	notice.modulate.a = 1.0
	notice.visible = true
	if notice_tween != null:
		notice_tween.kill()
	notice_tween = create_tween()
	notice_tween.tween_interval(1.2)
	notice_tween.tween_property(notice, "modulate:a", 0.0, 0.45)
	notice_tween.tween_callback(func() -> void: notice.visible = false)


func queue_task_completion(task_id: String) -> void:
	pending_task_completion = task_id


func show_lesson_completion(lesson_body: String) -> void:
	# A separate opaque full-screen page, above all exploration controls.
	info_panel.hide()
	player.set_controls_locked(true)
	var screen := ColorRect.new()
	screen.name = "LessonCompletion"
	screen.color = Color(0.035, 0.028, 0.024, 1.0)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$SafeArea.add_child(screen)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://Assets/Backdrops/chopin_lesson.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	screen.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "肖邦《革命练习曲》"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 42)
	heading.add_theme_color_override("font_color", Color(0.96, 0.78, 0.4))
	column.add_child(heading)
	var body := Label.new()
	body.text = "当对故乡的担忧与不屈的精神化作琴声，\n肖邦如何用音乐表达？"
	body.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	body.add_theme_color_override("font_shadow_color", Color.BLACK)
	body.add_theme_constant_override("shadow_offset_x", 2)
	body.add_theme_constant_override("shadow_offset_y", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 26)
	var final_scroll := ScrollContainer.new()
	final_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	final_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	final_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(final_scroll)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	final_scroll.add_child(body)
	var begin := Button.new()
	begin.text = "进入学习"
	begin.custom_minimum_size = Vector2(320, 64)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.add_theme_font_size_override("font_size", 26)
	column.add_child(begin)
	begin.pressed.connect(func() -> void:
		heading.text = "肖邦《革命练习曲》"
		body.text = lesson_body
		begin.hide()
	)
	begin.grab_focus()

func _exit_tree() -> void:
	for action in [&"move_forward", &"move_backwards", &"move_left", &"move_right"]:
		Input.action_release(action)

func _configure_information_layout() -> void:
	var box := $SafeArea/InformationPanel/Margin/VBox
	information_scroll = ScrollContainer.new()
	information_scroll.name = "ReadingScroll"
	information_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	information_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	information_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	information_scroll.clip_contents = true
	box.add_child(information_scroll)
	box.move_child(information_scroll, 2)
	var content := VBoxContainer.new()
	content.name = "ReadingContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	information_scroll.add_child(content)
	for node in [info_image, info_body, info_disclaimer, info_question, info_answer]:
		node.reparent(content)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.size_flags_vertical = Control.SIZE_FILL
		if node is Label:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			node.add_theme_font_size_override("font_size", 28 if node != info_disclaimer else 18)
	info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_title.add_theme_font_size_override("font_size", 32)
	info_image.custom_minimum_size = Vector2(0, 180)
	$SafeArea/InformationPanel/Margin/VBox/Next.custom_minimum_size.y = 58
	$SafeArea/InformationPanel/Margin/VBox/Close.custom_minimum_size.y = 58
	_resize_information_panel()

func _resize_information_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var intro_panel := $SafeArea/IntroOverlay/Center/Panel as Control
	intro_panel.custom_minimum_size.x = minf(680.0, viewport_size.x - 40.0)
	var panel_width := minf(880.0, viewport_size.x - 40.0)
	var panel_height := maxf(340.0, viewport_size.y - 48.0)
	info_panel.offset_left = -panel_width * 0.5
	info_panel.offset_right = panel_width * 0.5
	info_panel.offset_top = -panel_height * 0.5
	info_panel.offset_bottom = panel_height * 0.5
	info_image.custom_minimum_size.y = minf(220.0, panel_height * 0.30)

func _set_browser_fullscreen_button(visible_button: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval('document.getElementById("fullscreen").hidden=' + ("false" if visible_button else "true"), true)

func _place_touch_control(control: Control, bounds: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = bounds.position
	control.size = bounds.size

func _safe_touch_rect() -> Rect2:
	var view := get_viewport().get_visible_rect()
	var inset := Vector4(24.0, 18.0, 24.0, 24.0)
	if OS.has_feature("web"):
		var metrics = JavaScriptBridge.eval("window.classroomViewportInsets ? window.classroomViewportInsets() : ''", true)
		var values := str(metrics).split(",")
		if values.size() == 6:
			var scale_x := view.size.x / maxf(values[4].to_float(), 1.0)
			var scale_y := view.size.y / maxf(values[5].to_float(), 1.0)
			browser_ui_scale = scale_y
			inset.x += values[0].to_float() * scale_x
			inset.y += values[1].to_float() * scale_y
			inset.z += values[2].to_float() * scale_x
			inset.w += values[3].to_float() * scale_y
	return Rect2(view.position + Vector2(inset.x, inset.y), view.size - Vector2(inset.x + inset.z, inset.y + inset.w))

func _resize_touch_layout() -> void:
	_resize_information_panel()
	var safe := _safe_touch_rect()
	var view_size := get_viewport().get_visible_rect().size
	_place_touch_control($SafeArea/LookZone, Rect2(Vector2(view_size.x * 0.32, 0), Vector2(view_size.x * 0.68, view_size.y)))
	var edge := clampf(safe.size.y * 0.14, 76.0, 82.0)
	var gap := 8.0
	var span := edge * 3.0 + gap * 2.0
	var pad := $SafeArea/MovePad as Control
	_place_touch_control(pad, Rect2(Vector2(safe.position.x, safe.end.y - span), Vector2(span, span)))
	var step := edge + gap
	for key in {"Up": Vector2(step, 0), "Left": Vector2(0, step), "Right": Vector2(step * 2, step), "Down": Vector2(step, step * 2)}:
		var position_in_pad: Vector2 = {"Up": Vector2(step, 0), "Left": Vector2(0, step), "Right": Vector2(step * 2, step), "Down": Vector2(step, step * 2)}[key]
		_place_touch_control(pad.get_node(key), Rect2(position_in_pad, Vector2(edge, edge)))
	var action_width := minf(168.0, safe.size.x * 0.32)
	var action_height := 72.0
	_place_touch_control(interact_button, Rect2(Vector2(safe.end.x-action_width, safe.end.y-action_height), Vector2(action_width, action_height)))
	_place_touch_control($SafeArea/ResetView, Rect2(Vector2(safe.end.x-88.0, safe.end.y-action_height-76.0), Vector2(88,60)))
	_place_touch_control($SafeArea/StandButton, Rect2(Vector2(safe.end.x-action_width, safe.end.y-action_height-76.0), Vector2(action_width,60)))
	# Fullscreen is the upper-right browser control; keep sound immediately below it.
	_place_touch_control($SafeArea/SoundToggle, Rect2(Vector2(safe.end.x-96.0, safe.position.y+maxf(72.0,60.0*browser_ui_scale)), Vector2(96,56)))
	var header := $SafeArea/SceneHeader as Control
	_place_touch_control(header, Rect2(safe.position, Vector2(minf(464.0, safe.size.x-120.0),84)))
	$SafeArea/SceneHeader/VBox/Title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$SafeArea/SceneHeader/VBox/Subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
