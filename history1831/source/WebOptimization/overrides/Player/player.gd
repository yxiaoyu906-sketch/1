class_name Player extends CharacterBody3D

@export_range(1.0, 10.0, 0.1) var speed: float = 1.35
@export_range(5.0, 80.0, 1.0) var acceleration: float = 12.0
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1.0
@export_range(0.0, 0.08, 0.002) var walk_bob_height: float = 0.04
@export_range(0.0, 0.05, 0.002) var walk_bob_side: float = 0.009
@export_range(4.0, 14.0, 0.5) var walk_bob_speed: float = 7.0

var mouse_captured: bool = false
var pending_touch_look := Vector2.ZERO
var interaction_refresh := 0.0
var render_warmup_complete := false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_dir: Vector2 # Input direction for movement
var look_dir: Vector2 # Input direction for look/aim

var walk_vel: Vector3 # Walking velocity 
var grav_vel: Vector3 # Gravity velocity 
var bob_time: float = 0.0
var camera_rest_position: Vector3
var controls_locked := false
var seated := false
var standing_position := Vector3.ZERO
var standing_camera_position := Vector3.ZERO
var standing_camera_rotation := Vector3.ZERO
var active_seat_area: Area3D
var seated_target_index := 0
@onready var camera: Camera3D = $Camera
@onready var collision_shape: CollisionShape3D = $CShape
@onready var interaction_ray: RayCast3D = $Camera/InteractionRay
@onready var touch_hud: CanvasLayer = $TouchHUD
@onready var heartbeat_player: AudioStreamPlayer = $Heartbeat

func _ready() -> void:
	camera_rest_position = camera.position
	release_mouse()
	call_deferred("_configure_touch_rendering")
	get_viewport().size_changed.connect(_configure_viewport_size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != -1:
		look_dir = event.relative * 0.001
		if mouse_captured: _rotate_camera()
	if Input.is_action_just_pressed(&"exit"): get_tree().quit()

func _process(_delta: float) -> void:
	if not pending_touch_look.is_zero_approx():
		# Consume all gesture displacement once per rendered frame, independent of event batching.
		look_dir = pending_touch_look * (540.0 / maxf(get_viewport().get_visible_rect().size.y, 1.0)) * 0.0022
		_rotate_camera()
		pending_touch_look = Vector2.ZERO
		look_dir = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if controls_locked:
		velocity = Vector3.ZERO
		walk_vel = Vector3.ZERO
		grav_vel = Vector3.ZERO
		_update_interaction_state()
		return
	if mouse_captured: _handle_joypad_camera_rotation(delta)
	velocity = _walk(delta) + _gravity(delta)
	move_and_slide()
	_update_first_person_motion(delta)
	interaction_refresh += delta
	if interaction_refresh >= 0.10:
		interaction_refresh = 0.0
		_update_interaction_state()

func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func _rotate_camera(sens_mod: float = 1.0) -> void:
	camera.rotation.y -= look_dir.x * camera_sens * sens_mod
	camera.rotation.x = clamp(camera.rotation.x - look_dir.y * camera_sens * sens_mod, deg_to_rad(-70.0), deg_to_rad(70.0))

func apply_touch_look(relative: Vector2) -> void:
	if controls_locked and not seated:
		return
	pending_touch_look += relative

func stop_touch_look() -> void:
	pending_touch_look = Vector2.ZERO
	look_dir = Vector2.ZERO

func reset_camera() -> void:
	if seated:
		return
	camera.rotation = Vector3.ZERO


func set_standing_camera_height(height: float) -> void:
	if seated:
		return
	camera.position.y = height
	camera_rest_position = camera.position


func set_interaction_distance(distance: float) -> void:
	interaction_ray.target_position = Vector3(0.0, 0.0, -maxf(distance, 1.0))

func _handle_joypad_camera_rotation(delta: float, sens_mod: float = 1.0) -> void:
	var joypad_dir: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if joypad_dir.length() > 0:
		look_dir += joypad_dir * delta
		_rotate_camera(sens_mod)
		look_dir = Vector2.ZERO

func _walk(delta: float) -> Vector3:
	if controls_locked:
		walk_vel = walk_vel.move_toward(Vector3.ZERO, acceleration * delta)
		return walk_vel
	move_dir = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backwards")
	var _forward: Vector3 = Basis(Vector3.UP, camera.global_rotation.y) * Vector3(move_dir.x, 0, move_dir.y)
	var walk_dir: Vector3 = Vector3(_forward.x, 0, _forward.z).normalized()
	walk_vel = walk_vel.move_toward(walk_dir * speed * move_dir.length(), acceleration * delta)
	return walk_vel

func _gravity(delta: float) -> Vector3:
	if is_on_floor():
		grav_vel = Vector3.ZERO
	else:
		grav_vel.y -= gravity * delta
	return grav_vel

func try_interact() -> void:
	interaction_ray.force_raycast_update()
	if seated:
		var desk_targets := get_tree().get_nodes_in_group(&"seated_desk_interaction")
		var best_target: Node3D
		var best_alignment := -1.0
		var view_direction := -camera.global_transform.basis.z.normalized()
		for candidate in desk_targets:
			if candidate is Node3D:
				var candidate_node := candidate as Node3D
				var target_direction: Vector3 = (candidate_node.global_position - camera.global_position).normalized()
				var alignment: float = view_direction.dot(target_direction)
				if alignment > best_alignment:
					best_alignment = alignment
					best_target = candidate_node
		if best_target != null and best_target.has_method("interact"):
			best_target.interact(self)
			return
		touch_hud.show_notice("桌面物品暂时无法查看")
		return
	# Empty space has no interaction; desk notices belong to the seated branch.
	if not interaction_ray.is_colliding():
		return
	var target: Object = interaction_ray.get_collider()
	if target != null and target.has_method("interact"):
		target.interact(self)


func show_interaction(title: String, body: String) -> void:
	touch_hud.show_information(title, body)

func show_interaction_pages(title: String, pages: PackedStringArray) -> void:
	touch_hud.show_information_pages(title, pages)

func show_virtual_interaction(title: String, body: String, question: String, answer: String, disclaimer: String, display_image_path: String = "") -> void:
	touch_hud.show_virtual_information(title, body, question, answer, disclaimer, display_image_path)

func show_teaching_letter(title: String, body: String, question: String, answer: String, disclaimer: String) -> void:
	touch_hud.show_teaching_letter(title, body, question, answer, disclaimer)

func show_historical_interaction(title: String, original_image_path: String, source_body: String, translation_body: String, classroom_question: String, reference_answer: String) -> void:
	touch_hud.show_historical_information(title, original_image_path, source_body, translation_body, classroom_question, reference_answer)


func queue_warsaw_task_completion(task_id: String) -> void:
	touch_hud.queue_task_completion(task_id)

func play_heartbeat() -> void:
	if heartbeat_player.playing:
		heartbeat_player.stop()
	heartbeat_player.play()

func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	if locked:
		stop_touch_look()
		walk_vel = Vector3.ZERO
		velocity = Vector3.ZERO
		for action in [&"move_forward", &"move_backwards", &"move_left", &"move_right"]:
			Input.action_release(action)

func sit_at(seat_position: Vector3, desk_focus_position: Vector3, seat_area: Area3D) -> void:
	if seated:
		return
	standing_position = global_position
	standing_camera_position = camera.position
	standing_camera_rotation = camera.rotation
	global_position = seat_position
	camera.position = Vector3(0.0, 1.36, 0.0)
	camera.look_at(desk_focus_position, Vector3.UP)
	camera_rest_position = camera.position
	seated = true
	seated_target_index = 0
	active_seat_area = seat_area
	active_seat_area.set_deferred("collision_layer", 0)
	set_controls_locked(true)
	collision_shape.set_deferred("disabled", true)
	touch_hud.set_seated(true)

func stand_up() -> void:
	if not seated:
		return
	global_position = standing_position
	camera.position = standing_camera_position
	camera.rotation = standing_camera_rotation
	camera_rest_position = standing_camera_position
	seated = false
	if active_seat_area != null:
		active_seat_area.set_deferred("collision_layer", 2)
		active_seat_area = null
	collision_shape.set_deferred("disabled", false)
	set_controls_locked(false)
	touch_hud.set_seated(false)

func _update_first_person_motion(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and horizontal_speed > 0.12
	if moving:
		bob_time += delta * walk_bob_speed * clamp(horizontal_speed / speed, 0.35, 1.0)
	var walk_offset := Vector3.ZERO
	if moving:
		walk_offset.x = sin(bob_time) * walk_bob_side
		walk_offset.y = sin(bob_time * 2.0) * walk_bob_height
	var breathing_offset := Vector3(0.0, sin(Time.get_ticks_msec() * 0.0018) * 0.0025, 0.0)
	camera.position = camera.position.lerp(camera_rest_position + walk_offset + breathing_offset, min(delta * 9.0, 1.0))

func _update_interaction_state() -> void:
	if seated:
		touch_hud.set_interaction_available(true, "查看桌面")
		return
	interaction_ray.force_raycast_update()
	var can_interact := false
	if interaction_ray.is_colliding():
		var target: Object = interaction_ray.get_collider()
		can_interact = target != null and target.has_method("interact")
		if can_interact and target.has_method("interaction_label"):
			touch_hud.set_interaction_available(true, str(target.interaction_label()))
			return
	touch_hud.set_interaction_available(can_interact)

func _configure_touch_rendering() -> void:
	_configure_viewport_size()
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = 1.0
	var scene := get_tree().current_scene
	if scene == null:
		return
	for light in scene.find_children("*", "Light3D", true, false):
		light.shadow_enabled = false
	for world in scene.find_children("*", "WorldEnvironment", true, false):
		if world.environment:
			world.environment.ssao_enabled = false
			world.environment.glow_enabled = false
			world.environment.volumetric_fog_enabled = false
	if scene.scene_file_path.ends_with("Stuttgart_Graybox.tscn"):
		await warm_up_view()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.firstSceneReady = true", true)

func _configure_viewport_size() -> void:
	var window := get_window()
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var target := Vector2i(480, 760) if window.size.x < window.size.y else Vector2i(960, 540)
	if window.content_scale_size != target:
		window.content_scale_size = target

func warm_up_view() -> void:
	var original_rotation := camera.rotation
	for step in range(8):
		camera.rotation.y = original_rotation.y + TAU * step / 8.0
		for frame in range(2):
			await get_tree().process_frame
	camera.rotation = original_rotation
	stop_touch_look()
	for frame in range(3):
		await get_tree().process_frame
	render_warmup_complete = true
