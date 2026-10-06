extends Node3D

@export var target_height: float = 1.75
@export var idle_animation: StringName = &"idle"
@export var animation_speed: float = 1.0
@export var context_library: AnimationLibrary
@export var animation_phase: float = 0.0

func _ready() -> void:
	var visual := $ImportedGLB as Node3D
	var bounds := AABB()
	var found := false
	var foot_min_y := INF
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local_bounds: AABB = (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if found else local_bounds
		found = true
		# Props may extend below shoes. Fit the visible feet, not the gun stock/cane.
		if mesh.skin and mesh.has_node(mesh.skeleton):
			var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
			var transform_to_visual := visual.global_transform.affine_inverse() * mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				if vertices.is_empty() or joints.is_empty():
					continue
				var stride: int = joints.size() / vertices.size()
				for vertex in vertices.size():
					var dominant := 0
					for influence in stride:
						if weights[vertex * stride + influence] > weights[vertex * stride + dominant]:
							dominant = influence
					var bind: int = joints[vertex * stride + dominant]
					var bone_name := str(mesh.skin.get_bind_name(bind))
					if bone_name.is_empty():
						var bone := mesh.skin.get_bind_bone(bind)
						bone_name = skeleton.get_bone_name(bone) if bone >= 0 else ""
					if "Foot" in bone_name or "Toe" in bone_name:
						foot_min_y = minf(foot_min_y, (transform_to_visual * vertices[vertex]).y)
	if found and bounds.size.y > 0.001:
		var factor := target_height / bounds.size.y
		visual.scale = Vector3.ONE * factor
		visual.position.y = -(foot_min_y if is_finite(foot_min_y) else bounds.position.y) * factor
		set_meta("foot_grounding_verified", is_finite(foot_min_y))
	_apply_context_materials(visual)
	if context_library:
		var existing := visual.find_children("*", "AnimationPlayer", true, false)
		var controller: AnimationPlayer
		if existing.is_empty():
			controller = AnimationPlayer.new()
			controller.name = "AnimationPlayer"
			visual.add_child(controller)
		else:
			controller = existing[0] as AnimationPlayer
		controller.root_node = controller.get_path_to(visual)
		controller.add_animation_library("context", context_library.duplicate(true))
	if idle_animation.is_empty():
		return
	for child in visual.find_children("*", "AnimationPlayer", true, false):
		var player := child as AnimationPlayer
		if not player.has_animation(idle_animation):
			push_error("Tripo character missing animation: %s" % idle_animation)
			continue
		# Local library: do not mutate the imported resource shared by other actors.
		for library_name in player.get_animation_library_list():
			var local_library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
			player.remove_animation_library(library_name)
			player.add_animation_library(library_name, local_library)
		if str(get_meta("character_id", "")) == "npc_005":
			_stabilize_kneeling_pose(player.get_animation(idle_animation))
		player.get_animation(idle_animation).loop_mode = Animation.LOOP_LINEAR
		player.add_to_group("warsaw_character_animation_players")
		player.set_meta("warsaw_animation", idle_animation)
		player.speed_scale = animation_speed
		player.play(idle_animation)
		player.advance(0.0)
		player.seek(player.get_animation(idle_animation).length * animation_phase, true)
	_align_animated_feet(visual)
	if str(get_meta("character_id", "")) == "npc_005":
		visual.position.y += 0.003 # Tiny clearance for skinning precision at the road surface.

func _align_animated_feet(visual: Node3D) -> void:
	var floor_y := INF
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.skin or not mesh.has_node(mesh.skeleton):
			continue
		var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
		skeleton.force_update_all_bone_transforms()
		var transforms: Array[Transform3D] = []
		var names: Array[String] = []
		for bind in mesh.skin.get_bind_count():
			var bone := skeleton.find_bone(str(mesh.skin.get_bind_name(bind)))
			if bone < 0:
				bone = mesh.skin.get_bind_bone(bind)
			names.append(skeleton.get_bone_name(bone))
			transforms.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
		var to_actor := global_transform.affine_inverse() * skeleton.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or joints.is_empty():
				continue
			var stride: int = joints.size() / vertices.size()
			for vertex in vertices.size():
				var dominant := 0
				for influence in stride:
					if weights[vertex * stride + influence] > weights[vertex * stride + dominant]:
						dominant = influence
				var name := names[joints[vertex * stride + dominant]]
				if not ("Foot" in name or "Toe" in name):
					continue
				var point := Vector3.ZERO
				for influence in stride:
					var idx := vertex * stride + influence
					point += (transforms[joints[idx]] * vertices[vertex]) * weights[idx]
				floor_y = minf(floor_y, (to_actor * point).y)
	if is_finite(floor_y):
		visual.position.y -= floor_y
		set_meta("animated_foot_offset", floor_y)

func _apply_context_materials(visual: Node3D) -> void:
	var path := "res://Assets/Generated/TripoCharacters1831/%s/context_roughness.png" % str(get_meta("character_id", ""))
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if not mesh.mesh:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture == null or source.roughness_texture != null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.roughness = 1.0
			material.roughness_texture = texture
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh.set_surface_override_material(surface, material)

func _stabilize_kneeling_pose(animation: Animation) -> void:
	# This long coat cannot follow the imported kneeling clip's large leg changes.
	# Keep the authored starting crouch, including hips, while the upper body animates.
	var pose_time := animation.length * animation_phase
	var anchored_tracks := 0
	for track in animation.get_track_count():
		var path := str(animation.track_get_path(track)).to_lower()
		if not ("hips" in path or "upleg" in path or "leg" in path or "foot" in path or "toe" in path):
			continue
		var value: Variant
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				value = animation.rotation_track_interpolate(track, pose_time)
			Animation.TYPE_POSITION_3D:
				value = animation.position_track_interpolate(track, pose_time)
			Animation.TYPE_SCALE_3D:
				value = animation.scale_track_interpolate(track, pose_time)
			_:
				continue
		for key in animation.track_get_key_count(track):
			animation.track_set_key_value(track, key, value)
		anchored_tracks += 1
	set_meta("kneeling_anchored_tracks", anchored_tracks)
