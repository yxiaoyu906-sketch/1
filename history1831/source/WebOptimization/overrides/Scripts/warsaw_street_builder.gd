@tool
extends Node3D

const Q_ROOT := "res://Assets/CC0/Quaternius/MedievalVillageStandard/"
const Q_BUILDINGS := "res://Assets/CC0/Quaternius/MedievalVillageBuildings/"
const BARRELS := "res://Assets/CC0/cc0/polyhaven/wooden_barrels_01/wooden_barrels_01_1k.gltf"
const CANNON := "res://Assets/CC0/cc0/polyhaven/cannon_01/cannon_01_1k.gltf"
const LANTERN := "res://Assets/CC0/cc0/polyhaven/Lantern_01/Lantern_01_1k.gltf"
const FIRE_TEXTURE := "res://Assets/TeachingMaterials/fire_flame_teardrop.svg"
const NIGHT_SKY_TEXTURE := "res://Assets/TeachingMaterials/warsaw_storm_night_panorama_v1.png"
const CIVILIANS_TEXTURE := "res://Assets/TeachingMaterials/period_groups/warsaw_civilians_1831.webp"
const SOLDIERS_TEXTURE := "res://Assets/TeachingMaterials/period_groups/russian_soldiers_1831.webp"
const INSURGENTS_TEXTURE := "res://Assets/TeachingMaterials/period_groups/polish_insurgents_1831.webp"
const ANIMATED_MEN := "res://Assets/CC0/Quaternius/AnimatedMen/"
const TRIPO_CHARACTERS := {
 "npc_003": preload("res://scenes/characters/Character_NPC003.tscn"),
 "npc_006": preload("res://scenes/characters/Character_NPC006.tscn"),
 "npc_010": preload("res://scenes/characters/Character_NPC010.tscn"),
 "npc_011": preload("res://scenes/characters/Character_NPC011.tscn"),
 "npc_012": preload("res://scenes/characters/Character_NPC012.tscn"),
 "npc_013": preload("res://scenes/characters/Character_NPC013.tscn"),
 "npc_014": preload("res://scenes/characters/Character_NPC014.tscn"),
 "npc_015": preload("res://scenes/characters/Character_NPC015.tscn"),

 "npc_001": preload("res://scenes/characters/Character_NPC001.tscn"),
 "npc_002": preload("res://scenes/characters/Character_NPC002.tscn"),
 "npc_004": preload("res://scenes/characters/Character_NPC004.tscn"),
 "npc_005": preload("res://scenes/characters/Character_NPC005.tscn"),
 "npc_007": preload("res://scenes/characters/Character_NPC007.tscn"),
 "npc_008": preload("res://scenes/characters/Character_NPC008.tscn"),
 "npc_009": preload("res://scenes/characters/Character_NPC009.tscn"),
 "runner_001": preload("res://scenes/characters/Character_Runner001.tscn"),
 "runner_002": preload("res://scenes/characters/Character_Runner002.tscn"),
}
const TRIPO_GROUP_IDS := {
 "resident": ["npc_001", "npc_002", "npc_003", "npc_004", "npc_005"],
 "soldier": ["npc_011", "npc_012", "npc_013", "npc_014", "npc_015"],
 "insurgent": ["npc_006", "npc_007", "npc_008", "npc_009", "npc_010"],
}
const CHARACTER_FILES := [
	"Smooth_Male_Casual.fbx",
	"Smooth_Male_LongSleeve.fbx",
	"Smooth_Male_Shirt.fbx",
	"Smooth_Male_Suit.fbx",
]

const AUTHORED_RUIN := "res://Assets/CC0/PolyScan/AbandonedBrickHouse/AbandonedBrickHouse.glb"
var weather_materials: Dictionary = {}
var wall_material: Material
var street_material: Material
var wood_material: Material
var dark_wood_material: Material
var stone_material: Material
var brass_material: Material
var skin_material: Material
var coat_materials: Array[Material] = []
var completed_tasks: Dictionary = {}
var lesson_introduced := false
var build_complete := false


func _ready() -> void:
	add_to_group("warsaw_task_tracker")
	var player := get_node_or_null("Player") as Player
	if player:
		player.set_controls_locked(true)
	call_deferred("_build")


func _build() -> void:
	if Engine.is_editor_hint():
		return
	if has_node("GeneratedWarsawStreet"):
		get_node("GeneratedWarsawStreet").free()
	build_complete = false
	await _advance_loading("正在准备华沙场景", 0.76)
	_prepare_materials()
	var generated := Node3D.new()
	generated.name = "GeneratedWarsawStreet"
	add_child(generated)
	_build_environment(generated)
	await _advance_loading("正在准备华沙街道", 0.8)
	_build_street(generated)
	_build_rain(generated)
	await _advance_loading("正在准备街道建筑", 0.84)
	_build_buildings(generated)
	_build_barricade(generated)
	await _advance_loading("正在准备场景人物", 0.88)
	_build_period_figures(generated)
	await _advance_loading("正在准备场景氛围", 0.92)
	_build_battle_atmosphere(generated)
	await _advance_loading("正在准备交互内容", 0.95)
	_build_interactions(generated)
	_apply_touch_performance(generated)
	_update_hud()
	_configure_player_view()
	await _advance_loading("场景已就绪，即将进入", 0.98)
	# Render the complete street behind the opaque loading screen before revealing it.
	for frame in range(6):
		await get_tree().process_frame
	build_complete = true
	var player := get_node_or_null("Player") as Player
	if player:
		player.set_controls_locked(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.completeWarsawTransition && window.completeWarsawTransition()", true)

func _advance_loading(label: String, progress: float) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.setWarsawTransitionProgress && window.setWarsawTransitionProgress(" + JSON.stringify(label) + "," + str(progress) + ")", true)
	await get_tree().process_frame



func _prepare_materials() -> void:
	street_material = load("res://Assets/CC0/materials/cobblestone_floor_04_2k.tres").duplicate()
	if street_material is BaseMaterial3D:
		street_material.roughness = 0.50
		street_material.metallic = 0.0
		street_material.uv1_triplanar = true
		street_material.uv1_world_triplanar = true
		street_material.uv1_scale = Vector3.ONE * 0.7
		street_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wall_material = load("res://Assets/CC0/materials/plastered_wall_03_2k.tres")
	wood_material = load("res://Assets/CC0/materials/wood_floor_worn_2k.tres").duplicate()
	dark_wood_material = load("res://Assets/CC0/materials/wood_floor_worn_2k.tres").duplicate()
	if wood_material is BaseMaterial3D:
		wood_material.albedo_color = Color(0.58, 0.32, 0.16)
		wood_material.roughness = 0.88
		wood_material.uv1_triplanar = true
	if dark_wood_material is BaseMaterial3D:
		dark_wood_material.albedo_color = Color(0.16, 0.075, 0.035)
		dark_wood_material.roughness = 0.94
		dark_wood_material.uv1_triplanar = true
	stone_material = _material(Color(0.19, 0.2, 0.22), 0.94)
	brass_material = _material(Color(0.34, 0.22, 0.07), 0.52, 0.72)
	skin_material = _material(Color(0.48, 0.29, 0.21), 0.86)
	coat_materials = [
		_material(Color(0.055, 0.075, 0.105), 0.9),
		_material(Color(0.15, 0.065, 0.045), 0.92),
		_material(Color(0.075, 0.105, 0.09), 0.93),
		_material(Color(0.19, 0.16, 0.12), 0.95),
	]


func _build_environment(parent: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var night_sky := Sky.new()
	var night_material := PanoramaSkyMaterial.new()
	night_material.panorama = load(NIGHT_SKY_TEXTURE)
	night_material.energy_multiplier = 0.92
	night_sky.sky_material = night_material
	environment.sky = night_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.31, 0.37, 0.49)
	environment.ambient_light_energy = 0.70
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.04
	environment.ssao_enabled = false
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.45
	environment.glow_enabled = false
	environment.glow_intensity = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.27, 0.31, 0.4)
	environment.fog_light_energy = 0.96
	environment.fog_density = 0.004
	environment.fog_height = 0.5
	environment.fog_height_density = 0.14
	environment.volumetric_fog_enabled = false
	environment.volumetric_fog_density = 0.004
	environment.volumetric_fog_albedo = Color(0.43, 0.5, 0.62)
	environment.volumetric_fog_emission = Color(0.055, 0.075, 0.12)
	environment.volumetric_fog_emission_energy = 0.42
	environment.volumetric_fog_length = 54.0
	environment.volumetric_fog_detail_spread = 1.8
	environment.volumetric_fog_sky_affect = 0.04
	world.environment = environment
	parent.add_child(world)

	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(-49.0, 31.0, 0.0)
	moon.light_color = Color(0.72, 0.78, 0.9)
	moon.light_energy = 1.42
	moon.shadow_enabled = false
	parent.add_child(moon)
	_build_sky_dome(parent)
	_build_moonlight_patches(parent)


func _build_sky_dome(parent: Node3D) -> void:
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 58.0
	dome_mesh.height = 116.0
	dome_mesh.radial_segments = 96
	dome_mesh.rings = 48
	var dome_material := StandardMaterial3D.new()
	dome_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dome_material.cull_mode = BaseMaterial3D.CULL_FRONT
	dome_material.albedo_texture = load(NIGHT_SKY_TEXTURE)
	dome_material.albedo_color = Color(1.06, 1.08, 1.12)
	dome_material.disable_fog = true
	dome_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	dome_mesh.material = dome_material
	var dome := MeshInstance3D.new()
	dome.name = "VisibleStormSkyDome"
	dome.position = Vector3(0, 3.5, 0)
	dome.rotation_degrees.y = -24.0
	dome.mesh = dome_mesh
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dome)


func _build_moonlight_patches(parent: Node3D) -> void:
	var patch_texture := _make_moon_halo_texture()
	for position in [Vector3(-1.8, 0.36, 10.5), Vector3(2.25, 0.36, -2.8), Vector3(-0.4, 0.36, -14.0)]:
		var decal := Decal.new()
		decal.name = "MoonlightGroundPatch"
		decal.position = position
		decal.size = Vector3(4.8, 0.8, 6.2)
		decal.texture_albedo = patch_texture
		decal.modulate = Color(0.48, 0.62, 0.9, 0.18)
		decal.upper_fade = 0.35
		decal.lower_fade = 0.35
		parent.add_child(decal)


func _build_night_sky(parent: Node3D) -> void:
	var sky := Node3D.new()
	sky.name = "MoonAndStars"
	parent.add_child(sky)
	var moon_material := _emissive_material(Color(0.78, 0.87, 1.0), 4.4)
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 2.2
	moon_mesh.height = 4.4
	moon_mesh.radial_segments = 32
	moon_mesh.rings = 16
	moon_mesh.material = moon_material
	var moon_disc := MeshInstance3D.new()
	moon_disc.name = "VisibleMoon"
	moon_disc.position = Vector3(-15.0, 21.0, -38.0)
	moon_disc.mesh = moon_mesh
	sky.add_child(moon_disc)
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(10.0, 10.0)
	var halo_material := StandardMaterial3D.new()
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.albedo_texture = _make_moon_halo_texture()
	halo_material.albedo_color = Color(0.56, 0.7, 1.0, 0.72)
	halo_material.emission_enabled = true
	halo_material.emission = Color(0.32, 0.49, 0.86)
	halo_material.emission_energy_multiplier = 1.55
	halo_mesh.material = halo_material
	var moon_halo := MeshInstance3D.new()
	moon_halo.name = "MoonHalo"
	moon_halo.position = moon_disc.position + Vector3(0.0, 0.0, 0.35)
	moon_halo.mesh = halo_mesh
	sky.add_child(moon_halo)

	var star_material := _emissive_material(Color(0.78, 0.86, 1.0), 2.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18310907
	for index in range(26):
		var star_mesh := SphereMesh.new()
		var star_size := rng.randf_range(0.045, 0.12)
		star_mesh.radius = star_size
		star_mesh.height = star_size * 2.0
		star_mesh.radial_segments = 6
		star_mesh.rings = 4
		star_mesh.material = star_material
		var star := MeshInstance3D.new()
		star.name = "Star_%02d" % index
		star.position = Vector3(rng.randf_range(-34.0, 34.0), rng.randf_range(10.0, 27.0), rng.randf_range(-43.0, 24.0))
		star.mesh = star_mesh
		sky.add_child(star)


func _build_cloud_horizon(parent: Node3D) -> void:
	var clouds := Node3D.new()
	clouds.name = "MoonlitCloudHorizon"
	parent.add_child(clouds)
	var cloud_texture := _make_cloud_texture()
	var placements := [
		[Vector3(-18.0, 12.5, -36.0), Vector2(27.0, 8.0), Color(0.43, 0.5, 0.64, 0.38)],
		[Vector3(15.0, 16.0, -40.0), Vector2(31.0, 9.0), Color(0.34, 0.42, 0.58, 0.32)],
		[Vector3(-31.0, 11.0, -5.0), Vector2(24.0, 7.0), Color(0.26, 0.34, 0.5, 0.28)],
		[Vector3(32.0, 14.0, 5.0), Vector2(28.0, 8.0), Color(0.31, 0.39, 0.55, 0.3)],
		[Vector3(-16.0, 10.0, 38.0), Vector2(25.0, 7.0), Color(0.24, 0.3, 0.43, 0.27)],
		[Vector3(17.0, 15.0, 41.0), Vector2(30.0, 8.5), Color(0.32, 0.4, 0.56, 0.3)],
	]
	for index in range(placements.size()):
		var config: Array = placements[index]
		var cloud_mesh := QuadMesh.new()
		cloud_mesh.size = config[1]
		var cloud_material := StandardMaterial3D.new()
		cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloud_material.albedo_texture = cloud_texture
		cloud_material.albedo_color = config[2]
		cloud_material.emission_enabled = true
		cloud_material.emission = Color(0.15, 0.22, 0.38)
		cloud_material.emission_energy_multiplier = 0.7
		cloud_mesh.material = cloud_material
		var cloud := MeshInstance3D.new()
		cloud.name = "CloudBank_%02d" % index
		cloud.position = config[0]
		cloud.mesh = cloud_mesh
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds.add_child(cloud)

	# A low blue-gray luminous band establishes a readable horizon behind the city.
	var horizon_mesh := CylinderMesh.new()
	horizon_mesh.top_radius = 47.0
	horizon_mesh.bottom_radius = 47.0
	horizon_mesh.height = 4.0
	horizon_mesh.radial_segments = 64
	horizon_mesh.rings = 1
	var horizon_material := StandardMaterial3D.new()
	horizon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	horizon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	horizon_material.cull_mode = BaseMaterial3D.CULL_FRONT
	horizon_material.albedo_color = Color(0.23, 0.29, 0.39, 0.2)
	horizon_material.emission_enabled = true
	horizon_material.emission = Color(0.12, 0.18, 0.3)
	horizon_material.emission_energy_multiplier = 0.72
	horizon_mesh.material = horizon_material
	var horizon_band := MeshInstance3D.new()
	horizon_band.name = "VisibleHorizonBand"
	horizon_band.position.y = 3.1
	horizon_band.mesh = horizon_mesh
	horizon_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clouds.add_child(horizon_band)


func _build_rain(parent: Node3D) -> void:
	var rain := GPUParticles3D.new()
	rain.name = "StreetRain"
	rain.position = Vector3(0, 10.0, 0)
	rain.amount = 90
	rain.lifetime = 1.7
	rain.randomness = 0.38
	rain.visibility_aabb = AABB(Vector3(-15, -12, -27), Vector3(30, 24, 54))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-0.08, -1.0, 0.04)
	process.spread = 4.5
	process.initial_velocity_min = 11.0
	process.initial_velocity_max = 17.0
	process.gravity = Vector3(-0.7, -6.0, 0.2)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(13.0, 0.5, 25.0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.46, 0.012)
	var drop_material := StandardMaterial3D.new()
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.albedo_color = Color(0.61, 0.72, 0.86, 0.56)
	drop.material = drop_material
	rain.draw_pass_1 = drop
	parent.add_child(rain)


func _build_street(parent: Node3D) -> void:
	# The broad foundation and perimeter collisions prevent the player from reaching a void.
	_box(parent, "DistrictFoundation", Vector3(0, -0.48, 0), Vector3(31.0, 0.7, 52.0), street_material, true)
	_box(parent, "WetCobblestoneRoad", Vector3(0, -0.12, 0), Vector3(10.2, 0.22, 48), street_material, true)
	_box(parent, "LeftPavement", Vector3(-6.0, -0.02, 0), Vector3(1.8, 0.32, 48), stone_material, true)
	_box(parent, "RightPavement", Vector3(6.0, -0.02, 0), Vector3(1.8, 0.32, 48), stone_material, true)
	_box(parent, "LeftCurb", Vector3(-5.05, 0.13, 0), Vector3(0.18, 0.3, 48), stone_material, true)
	_box(parent, "RightCurb", Vector3(5.05, 0.13, 0), Vector3(0.18, 0.3, 48), stone_material, true)
	_collision_box(parent, Vector3(-14.9, 2.0, 0), Vector3(0.5, 4.0, 52.0))
	_collision_box(parent, Vector3(14.9, 2.0, 0), Vector3(0.5, 4.0, 52.0))
	_collision_box(parent, Vector3(0, 2.0, -25.8), Vector3(30.0, 4.0, 0.5))
	_collision_box(parent, Vector3(0, 2.0, 25.8), Vector3(30.0, 4.0, 0.5))
	for z in [-19.5, -12.5, -5.0, 3.5, 11.0, 18.5]:
		_build_lamp(parent, Vector3(-5.75, 0.14, z))
		_build_lamp(parent, Vector3(5.75, 0.14, z + 1.1))


func _build_buildings(parent: Node3D) -> void:
	var buildings := Node3D.new()
	buildings.name = "PeriodBuildings"
	parent.add_child(buildings)
	# Source AABBs are recorded in metres before scaling. Local +Z is each facade's front.
	# Complete buildings replace the former box volumes and pasted-on facade pieces.
	var left_row := [
		["Inn.fbx", 21.2, 2.02, Vector3(4.03, 3.49, 4.02)],
		["House_1.fbx", 16.8, 2.15, Vector3(2.14, 3.39, 2.66)],
		["House_2.fbx", 12.4, 2.2, Vector3(2.22, 3.25, 3.42)],
		["House_1.fbx", 8.2, 2.15, Vector3(2.14, 3.39, 2.66)],
		["Inn.fbx", 3.0, 2.02, Vector3(4.03, 3.49, 4.02)],
		["Blacksmith.fbx", -4.0, 2.35, Vector3(3.89, 3.00, 3.28)],
		["Stable.fbx", -10.8, 2.82, Vector3(4.70, 2.49, 3.33)],
	]
	var right_row := [
		["Blacksmith.fbx", 21.3, 2.35, Vector3(3.89, 3.00, 3.28)],
		["House_1.fbx", 17.0, 2.15, Vector3(2.14, 3.39, 2.66)],
		["House_3.fbx", 12.8, 3.35, Vector3(1.94, 2.09, 2.12)],
		["House_4.fbx", 8.8, 6.35, Vector3(1.94, 1.07, 2.12)],
		["Blacksmith.fbx", 3.4, 2.35, Vector3(3.89, 3.00, 3.28)],
		["House_2.fbx", -2.2, 2.2, Vector3(2.22, 3.25, 3.42)],
		["Inn.fbx", -7.8, 2.02, Vector3(4.03, 3.49, 4.02)],
		["House_1.fbx", -13.1, 2.15, Vector3(2.14, 3.39, 2.66)],
	]
	for config in left_row:
		var z_value: float = config[1]
		if z_value in [12.4, 3.0]: continue # Authored house occupies this frontage.
		if z_value in [16.8, 8.2, -4.0, -10.8]:
			_build_ruined_house(buildings, -1.0, z_value, 4.7, 4.2)
		else:
			_place_finished_building(buildings, config[0], -1.0, z_value, config[2], config[3])
	for config in right_row:
		var z_value: float = config[1]
		if z_value in [3.4, -7.8]: continue # Authored house occupies this frontage.
		if z_value in [17.0, 8.8, -2.2, -13.1]:
			_build_ruined_house(buildings, 1.0, z_value, 4.7, 4.2)
		else:
			_place_finished_building(buildings, config[0], 1.0, z_value, config[2], config[3])

	# Finished buildings close both ends and extend the skyline behind the player.
	_place_finished_building(buildings, "Bell_Tower.fbx", -1.0, -17.7, 2.05, Vector3(1.94, 4.76, 2.23), 6.1)
	_place_finished_building(buildings, "Mill.fbx", 1.0, -18.6, 1.55, Vector3(3.40, 4.80, 2.73), 6.4)
	_place_finished_building(buildings, "Bell_Tower.fbx", 1.0, 22.7, 1.72, Vector3(1.94, 4.76, 2.23), 6.2)
	_place_finished_building(buildings, "Sawmill.fbx", -1.0, 22.1, 1.54, Vector3(4.0, 3.2, 3.5), 6.2)
	_build_distant_city(buildings)


func _place_finished_building(parent: Node3D, file_name: String, side: float, z: float, scale_factor: float, source_size: Vector3, front_x := 5.05) -> void:
	var scaled_size := source_size * scale_factor
	var center_x := side * (front_x + scaled_size.z * 0.5)
	var rotation_y := 90.0 if side < 0.0 else -90.0
	var building := _asset(
		parent,
		Q_BUILDINGS + file_name,
		Vector3(center_x, 0.14, z),
		Vector3(0, rotation_y, 0),
		Vector3.ONE * scale_factor
	)
	if building:
		building.name = "FinishedBuilding_%s" % file_name.get_basename()
	_collision_box(
		parent,
		Vector3(center_x, 0.14 + scaled_size.y * 0.5, z),
		Vector3(scaled_size.x * 0.92, scaled_size.y, scaled_size.z * 0.92),
		Vector3(0, rotation_y, 0)
	)


func _build_ruined_house(parent: Node3D, side: float, z: float, _width: float = 4.7, _depth: float = 4.2) -> void:
	var ruin := Node3D.new()
	ruin.name = "BombedHouse_%s" % str(z).replace(".", "_")
	ruin.position = Vector3(side * 7.6, 0.14, z)
	parent.add_child(ruin)
	if z in [8.2, -2.2]:
		var authored := _asset(ruin, AUTHORED_RUIN, Vector3(side * 1.1, 0, 0), Vector3(0, 90.0 if side < 0.0 else -90.0, 0), Vector3.ONE)
		if authored:
			authored.name = "AuthoredAbandonedBrickHouse"
		_build_smoke_column(ruin, Vector3(side * 0.4, 1.8, 0.2))
		_collision_box(parent, Vector3(side * 8.7, 3.3, z), Vector3(7.2, 6.6, 10.3))
		return
	var finished_models := ["House_1.fbx", "Blacksmith.fbx", "House_2.fbx"]
	var finished_file: String = finished_models[int(abs(z) * 10.0) % finished_models.size()]
	var rotation_y := 90.0 if side < 0.0 else -90.0
	var building := _asset(ruin, Q_BUILDINGS + finished_file, Vector3.ZERO, Vector3(0, rotation_y, side * 2.5), Vector3.ONE * 2.25)
	if building:
		building.name = "FinishedCollapsedHouseShell"

	# Finished masonry, roof and floor modules supply real profiles and authored surface detail.
	var street_x := -side * 2.15
	_asset(ruin, Q_ROOT + "Wall_UnevenBrick_Window_Wide_Round.gltf", Vector3(street_x, 1.22, -1.35), Vector3(0, rotation_y, side * 11.0), Vector3.ONE * 1.7)
	_asset(ruin, Q_ROOT + "Wall_UnevenBrick_Straight.gltf", Vector3(street_x, 0.88, 1.55), Vector3(0, rotation_y, side * -8.0), Vector3(1.55, 1.2, 1.55))
	_asset(ruin, Q_ROOT + "Roof_Wooden_2x1_Corner.gltf", Vector3(-side * 0.35, 2.85, 0.45), Vector3(22, rotation_y, side * 28), Vector3.ONE * 1.85)
	_asset(ruin, Q_ROOT + "Floor_WoodDark_Half2.gltf", Vector3(street_x - side * 0.5, 0.28, -0.4), Vector3(18, rotation_y + 12, side * 24), Vector3.ONE * 1.45)
	_asset(ruin, Q_ROOT + "Floor_WoodDark_Half3.gltf", Vector3(street_x - side * 0.28, 0.42, 1.05), Vector3(-12, rotation_y - 18, side * -20), Vector3.ONE * 1.25)
	for index in range(10):
		var rubble_z := -2.0 + float(index % 5) * 0.88
		var rubble_x := street_x - side * (0.08 + float(index / 5) * 0.42)
		_asset(ruin, Q_ROOT + "Prop_Brick%d.gltf" % (1 + index % 4), Vector3(rubble_x, 0.04, rubble_z), Vector3(index * 13.0, index * 37.0, index * 9.0), Vector3.ONE * (0.9 + (index % 3) * 0.14))
	_build_smoke_column(ruin, Vector3(side * 0.4, 1.8, 0.2))
	_collision_box(parent, Vector3(side * 7.6, 1.75, z), Vector3(4.5, 3.5, 5.0))


func _build_distant_city(parent: Node3D) -> void:
	# A second row hides the edge of the playable district without adding nearby clutter.
	var distant_rows := [
		["House_3.fbx", -1.0, -13.5, 2.8],
		["Inn.fbx", -1.0, -4.0, 1.9],
		["House_4.fbx", -1.0, 7.5, 5.2],
		["Stable.fbx", -1.0, 17.0, 2.4],
		["House_2.fbx", 1.0, -15.5, 2.0],
		["Blacksmith.fbx", 1.0, -6.5, 2.1],
		["House_1.fbx", 1.0, 5.0, 2.0],
		["Inn.fbx", 1.0, 16.5, 1.85],
	]
	for config in distant_rows:
		var side: float = config[1]
		var rotation_y := 90.0 if side < 0.0 else -90.0
		var instance := _asset(
			parent,
			Q_BUILDINGS + String(config[0]),
			Vector3(side * 13.0, 0.0, config[2]),
			Vector3(0, rotation_y, 0),
			Vector3.ONE * config[3]
		)
		if instance:
			instance.name = "DistantCity_%s" % String(config[0]).get_basename()
	# Cross-street buildings fill both forward and rear views.
	_asset(parent, Q_BUILDINGS + "Inn.fbx", Vector3(-3.6, 0.0, -24.0), Vector3(0, 180, 0), Vector3.ONE * 2.18)
	_asset(parent, Q_BUILDINGS + "Blacksmith.fbx", Vector3(4.2, 0.0, -24.2), Vector3(0, 180, 0), Vector3.ONE * 2.25)
	_asset(parent, Q_BUILDINGS + "Stable.fbx", Vector3(-4.0, 0.0, 24.0), Vector3.ZERO, Vector3.ONE * 2.55)
	_asset(parent, Q_BUILDINGS + "House_2.fbx", Vector3(4.4, 0.0, 24.2), Vector3.ZERO, Vector3.ONE * 2.2)
	_build_horizon_landmarks(parent)


func _build_horizon_landmarks(parent: Node3D) -> void:
	# A dense non-playable outer ring keeps every camera direction inside a continuous city.
	var landmarks := [
		["Bell_Tower.fbx", Vector3(-13.0, 0.0, -27.0), Vector3(0, 180, 0), 3.25],
		["Inn.fbx", Vector3(-7.0, 0.0, -27.0), Vector3(0, 180, 0), 2.95],
		["House_2.fbx", Vector3(-1.8, 0.0, -27.0), Vector3(0, 180, 0), 3.25],
		["Blacksmith.fbx", Vector3(4.0, 0.0, -27.0), Vector3(0, 180, 0), 3.1],
		["House_1.fbx", Vector3(9.0, 0.0, -27.0), Vector3(0, 180, 0), 3.5],
		["Bell_Tower.fbx", Vector3(14.0, 0.0, -27.0), Vector3(0, 180, 0), 3.3],
		["House_2.fbx", Vector3(-15.8, 0.0, -18.0), Vector3(0, 90, 0), 3.15],
		["Inn.fbx", Vector3(-15.8, 0.0, -7.0), Vector3(0, 90, 0), 2.85],
		["Stable.fbx", Vector3(-15.8, 0.0, 5.0), Vector3(0, 90, 0), 3.15],
		["Mill.fbx", Vector3(-15.8, 0.0, 17.0), Vector3(0, 90, 0), 2.8],
		["House_1.fbx", Vector3(15.8, 0.0, -18.0), Vector3(0, -90, 0), 3.6],
		["Blacksmith.fbx", Vector3(15.8, 0.0, -7.0), Vector3(0, -90, 0), 3.15],
		["Inn.fbx", Vector3(15.8, 0.0, 5.0), Vector3(0, -90, 0), 2.9],
		["Bell_Tower.fbx", Vector3(15.8, 0.0, 17.0), Vector3(0, -90, 0), 3.35],
		["Sawmill.fbx", Vector3(-12.5, 0.0, 27.0), Vector3.ZERO, 3.0],
		["House_1.fbx", Vector3(-7.0, 0.0, 27.0), Vector3.ZERO, 3.5],
		["Blacksmith.fbx", Vector3(-1.0, 0.0, 27.0), Vector3.ZERO, 3.15],
		["Inn.fbx", Vector3(5.5, 0.0, 27.0), Vector3.ZERO, 2.9],
		["Bell_Tower.fbx", Vector3(12.0, 0.0, 27.0), Vector3.ZERO, 3.25],
	]
	for index in range(landmarks.size()):
		var config: Array = landmarks[index]
		var building := _asset(parent, Q_BUILDINGS + String(config[0]), config[1], config[2], Vector3.ONE * float(config[3]))
		if building:
			building.name = "HorizonLandmark_%02d" % index


func _build_lamp(parent: Node3D, position: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "StreetLantern"
	lamp.position = position
	parent.add_child(lamp)
	_cylinder(lamp, "IronPost", Vector3(0, 1.35, 0), 0.055, 2.7, dark_wood_material)
	_cylinder(lamp, "PostBase", Vector3(0, 0.15, 0), 0.18, 0.3, brass_material)
	var lantern := _asset(lamp, LANTERN, Vector3(0, 2.72, 0), Vector3.ZERO, Vector3(1.55, 1.55, 1.55))
	if lantern:
		lantern.name = "FinishedAntiqueLantern"
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.72, 0)
	light.light_color = Color(1.0, 0.58, 0.27)
	light.light_energy = 1.25
	light.omni_range = 5.0
	light.shadow_enabled = false
	lamp.add_child(light)
	_collision_box(parent, position + Vector3(0, 1.35, 0), Vector3(0.38, 2.7, 0.38))


func _build_barricade(parent: Node3D) -> void:
	var barricade := Node3D.new()
	barricade.name = "1831Barricade"
	parent.add_child(barricade)
	_asset(barricade, Q_ROOT + "Prop_Wagon.gltf", Vector3(-4.25, 0.02, -1.7), Vector3(0, 22, 0), Vector3(0.92, 0.92, 0.92))
	_asset(barricade, Q_ROOT + "Prop_Crate.gltf", Vector3(-3.65, 0.05, -0.3), Vector3(0, 19, 0), Vector3(0.82, 0.82, 0.82))
	_asset(barricade, Q_ROOT + "Prop_Crate.gltf", Vector3(3.65, 0.05, -1.25), Vector3(0, -13, 0), Vector3(0.68, 0.68, 0.68))
	_asset(barricade, BARRELS, Vector3(3.7, 0.03, -0.05), Vector3(0, -25, 0), Vector3(0.58, 0.58, 0.58))
	_asset(barricade, CANNON, Vector3(-3.35, 0.05, -7.8), Vector3(0, 8, 0), Vector3(2.35, 2.35, 2.35))
	_collision_box(barricade, Vector3(-4.25, 0.7, -1.7), Vector3(1.8, 1.4, 3.7), Vector3(0, 22, 0))
	_collision_box(barricade, Vector3(-3.65, 0.53, -0.3), Vector3(0.9, 1.05, 0.9), Vector3(0, 19, 0))
	_collision_box(barricade, Vector3(3.65, 0.43, -1.25), Vector3(0.74, 0.85, 0.74), Vector3(0, -13, 0))
	_collision_box(barricade, Vector3(3.7, 0.5, -0.05), Vector3(2.0, 1.0, 1.6), Vector3(0, -25, 0))
	_collision_box(barricade, Vector3(-3.35, 0.82, -7.8), Vector3(2.4, 1.55, 4.2), Vector3(0, 8, 0))
	var timber_positions := [Vector3(-4.25, 0.78, -1.0), Vector3(-3.25, 1.0, -1.2), Vector3(3.15, 0.8, -1.5), Vector3(4.2, 1.02, -1.25)]
	for index in range(timber_positions.size()):
		_box(barricade, "BarricadeTimber", timber_positions[index], Vector3(1.65, 0.24, 0.32), wood_material, true, Vector3(0, 0, -12 + index * 8))
	for offset in [Vector3(-4.0, 0.04, -2.5), Vector3(4.0, 0.04, -2.45), Vector3(3.35, 0.04, -3.2)]:
		var number := 1 + int(abs(offset.x)) % 4
		_asset(barricade, Q_ROOT + "Prop_Brick%d.gltf" % number, offset, Vector3(0, offset.x * 17.0, 0), Vector3(0.85, 0.85, 0.85))
	_build_fire(barricade, Vector3(4.35, 0.15, -5.8), false)
	_build_fire(barricade, Vector3(-6.9, 0.5, -13.2), true)


func _build_fire(parent: Node3D, position: Vector3, distant: bool) -> void:
	var fire := Node3D.new()
	fire.name = "DistantBuildingFire" if distant else "BarricadeFire"
	fire.position = position
	parent.add_child(fire)
	for index in range(3):
		_cylinder(fire, "CharredLog", Vector3((index - 1) * 0.16, 0.06, 0), 0.07, 0.75, dark_wood_material, Vector3(0, 0, 90 + index * 28))
	var flames := GPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 6 if not distant else 8
	flames.lifetime = 0.72
	flames.randomness = 0.55
	flames.visibility_aabb = AABB(Vector3(-2, -0.2, -2), Vector3(4, 5, 4))
	var flame_process := ParticleProcessMaterial.new()
	flame_process.direction = Vector3(0, 1, 0)
	flame_process.spread = 18.0
	flame_process.initial_velocity_min = 0.55
	flame_process.initial_velocity_max = 1.45
	flame_process.gravity = Vector3(0, 0.35, 0)
	flame_process.scale_min = 0.42
	flame_process.scale_max = 0.95
	flame_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	flame_process.emission_box_extents = Vector3(0.32, 0.06, 0.22)
	flames.process_material = flame_process
	var flame_quad := QuadMesh.new()
	flame_quad.size = Vector2(0.28, 0.72) if not distant else Vector2(0.45, 1.15)
	flame_quad.orientation = PlaneMesh.FACE_Z
	var flame_mat := StandardMaterial3D.new()
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flame_mat.albedo_texture = load(FIRE_TEXTURE)
	flame_mat.albedo_color = Color(1.0, 0.38, 0.08, 0.92)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.18, 0.025)
	flame_mat.emission_energy_multiplier = 2.8
	flame_quad.material = flame_mat
	flames.draw_pass_1 = flame_quad
	fire.add_child(flames)

	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = Vector3(0, 0.55, 0)
	smoke.amount = 4 if not distant else 5
	smoke.lifetime = 4.2
	smoke.randomness = 0.7
	smoke.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 11, 8))
	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.direction = Vector3(0.12, 1.0, -0.08)
	smoke_process.spread = 24.0
	smoke_process.initial_velocity_min = 0.42
	smoke_process.initial_velocity_max = 0.95
	smoke_process.gravity = Vector3(0.04, 0.08, 0)
	smoke_process.scale_min = 0.55
	smoke_process.scale_max = 1.6
	smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	smoke_process.emission_box_extents = Vector3(0.28, 0.08, 0.24)
	smoke.process_material = smoke_process
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(1.1, 1.1) if not distant else Vector2(1.8, 1.8)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.albedo_texture = _make_smoke_texture()
	smoke_mat.albedo_color = Color(0.35, 0.37, 0.4, 0.5)
	smoke_quad.material = smoke_mat
	smoke.draw_pass_1 = smoke_quad
	fire.add_child(smoke)

	var light := OmniLight3D.new()
	light.name = "DistantFireLight" if distant else "FireLight"
	light.position = Vector3(0, 0.75, 0)
	light.light_color = Color(1.0, 0.29, 0.055)
	light.light_energy = 1.9 if distant else 2.65
	light.omni_range = 7.0 if distant else 5.4
	light.shadow_enabled = false
	light.add_to_group("warsaw_fire_lights")
	light.set_meta("base_energy", light.light_energy)
	light.set_meta("phase", position.x)
	fire.add_child(light)


func _build_battle_atmosphere(parent: Node3D) -> void:
	var battle := Node3D.new()
	battle.name = "BattleAtmosphere"
	parent.add_child(battle)

	# Finished artillery and period props stay to the sides, leaving a walkable centre line.
	_asset(battle, CANNON, Vector3(3.45, 0.05, -9.8), Vector3(0, 168, 0), Vector3.ONE * 2.25)
	_asset(battle, BARRELS, Vector3(-4.25, 0.02, 7.4), Vector3(0, 18, 0), Vector3.ONE * 0.52)
	for config in [
		[Vector3(-4.35, 0.04, -9.0), 1], [Vector3(-3.85, 0.04, -9.5), 4],
		[Vector3(4.25, 0.04, 6.8), 2], [Vector3(3.8, 0.04, 7.25), 3],
		[Vector3(-4.4, 0.04, 14.6), 2], [Vector3(4.35, 0.04, -15.5), 4],
	]:
		var debris_position: Vector3 = config[0]
		_asset(battle, Q_ROOT + "Prop_Brick%d.gltf" % int(config[1]), debris_position, Vector3(0, debris_position.z * 9.0, 0), Vector3.ONE * 1.15)

	# Authored wall, roof and floor fragments replace the former plain rectangular beam piles.
	var broken_wall_data := [
		[Vector3(-6.65, 1.7, -8.6), Vector3(0, 88, -8)],
		[Vector3(6.62, 1.45, 7.4), Vector3(0, -91, 12)],
		[Vector3(-6.58, 1.25, 15.2), Vector3(0, 92, 17)],
	]
	for index in range(broken_wall_data.size()):
		var data: Array = broken_wall_data[index]
		_asset(battle, Q_ROOT + "Wall_UnevenBrick_Window_Wide_Round.gltf", data[0], data[1], Vector3.ONE * 1.65)
		for beam_index in range(3):
			_asset(
				battle,
				Q_ROOT + "Floor_WoodDark_Half%d.gltf" % (1 + beam_index),
				data[0] + Vector3((beam_index - 1) * 0.42, -1.12 + beam_index * 0.08, 0.45),
				Vector3(8 + beam_index * 5, beam_index * 24, 18 + beam_index * 9),
				Vector3.ONE * (0.88 + beam_index * 0.08)
			)

	for fire_position in [
		Vector3(-5.8, 0.2, -8.7), Vector3(5.75, 0.2, 7.2),
		Vector3(-5.9, 0.25, 15.1), Vector3(5.9, 0.3, -15.0),
	]:
		_build_fire(battle, fire_position, true)
	for smoke_position in [Vector3(-6.0, 1.2, -3.0), Vector3(6.1, 1.1, 12.0)]:
		_build_smoke_column(battle, smoke_position)
	_build_dust_cloud(battle)
	_build_spark_field(battle)
	_build_dynamic_shells(battle)
	_build_explosion_flashes(battle)


func _build_smoke_column(parent: Node3D, position: Vector3) -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "WarSmokeColumn"
	smoke.position = position
	smoke.amount = 24
	smoke.lifetime = 7.0
	smoke.randomness = 0.72
	smoke.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 18, 10))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.16, 1.0, -0.08)
	process.spread = 31.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.25
	process.gravity = Vector3(0.08, 0.06, -0.03)
	process.scale_min = 0.8
	process.scale_max = 2.7
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.8, 0.2, 0.8)
	smoke.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(2.5, 2.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _make_smoke_texture()
	material.albedo_color = Color(0.17, 0.18, 0.2, 0.62)
	quad.material = material
	smoke.draw_pass_1 = quad
	parent.add_child(smoke)


func _build_dust_cloud(parent: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.name = "StreetDustAndAsh"
	dust.position = Vector3(0, 0.9, 0)
	dust.amount = 64
	dust.lifetime = 5.8
	dust.randomness = 0.88
	dust.visibility_aabb = AABB(Vector3(-12, -2, -24), Vector3(24, 9, 48))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.45, 0.18, -0.25)
	process.spread = 55.0
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.72
	process.gravity = Vector3(0, 0.05, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(7.0, 1.2, 21.0)
	dust.process_material = process
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(0.09, 0.09)
	var dust_material := StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.albedo_color = Color(0.52, 0.48, 0.41, 0.48)
	dust_mesh.material = dust_material
	dust.draw_pass_1 = dust_mesh
	parent.add_child(dust)


func _build_spark_field(parent: Node3D) -> void:
	for position in [Vector3(-5.2, 1.0, -8.6), Vector3(5.0, 0.8, 7.0), Vector3(4.7, 1.0, -14.8)]:
		var sparks := GPUParticles3D.new()
		sparks.name = "WindblownFireSparks"
		sparks.position = position
		sparks.amount = 18
		sparks.lifetime = 1.9
		sparks.randomness = 0.78
		sparks.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(7, 8, 7))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.3, 1.0, -0.12)
		process.spread = 38.0
		process.initial_velocity_min = 1.2
		process.initial_velocity_max = 3.6
		process.gravity = Vector3(0.3, -0.4, 0)
		sparks.process_material = process
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.025, 0.1, 0.025)
		spark_mesh.material = _emissive_material(Color(1.0, 0.32, 0.035), 4.2)
		sparks.draw_pass_1 = spark_mesh
		parent.add_child(sparks)


func _build_dynamic_shells(parent: Node3D) -> void:
	for index in range(3):
		var shell := MeshInstance3D.new()
		shell.name = "FlyingCannonShell_%d" % (index + 1)
		var shell_mesh := SphereMesh.new()
		shell_mesh.radius = 0.11
		shell_mesh.height = 0.22
		shell_mesh.material = _material(Color(0.035, 0.035, 0.038), 0.32, 0.82)
		shell.mesh = shell_mesh
		shell.add_to_group("warsaw_dynamic_shells")
		shell.set_meta("phase", index * 1.45)
		shell.set_meta("origin", Vector3(-5.0 + index * 5.0, 1.15, -12.0 + index * 8.0))
		shell.set_meta("direction", 1.0 if index % 2 == 0 else -1.0)
		parent.add_child(shell)


func _build_explosion_flashes(parent: Node3D) -> void:
	var positions := [Vector3(-4.9, 0.9, -10.2), Vector3(4.8, 1.1, 6.5), Vector3(-5.1, 1.0, 15.0)]
	for index in range(positions.size()):
		var blast := Node3D.new()
		blast.name = "TimedExplosion_%d" % (index + 1)
		blast.position = positions[index]
		blast.add_to_group("warsaw_explosion_flashes")
		blast.set_meta("phase", index * 2.15)
		parent.add_child(blast)
		var flash := MeshInstance3D.new()
		flash.name = "Flash"
		var flash_mesh := SphereMesh.new()
		flash_mesh.radius = 0.42
		flash_mesh.height = 0.84
		flash_mesh.radial_segments = 16
		flash_mesh.rings = 8
		flash_mesh.material = _emissive_material(Color(1.0, 0.23, 0.025), 5.5)
		flash.mesh = flash_mesh
		blast.add_child(flash)
		var light := OmniLight3D.new()
		light.name = "BlastLight"
		light.light_color = Color(1.0, 0.24, 0.035)
		light.light_energy = 0.0
		light.omni_range = 9.0
		blast.add_child(light)


func _build_musket(parent: Node3D, position: Vector3, rotation: Vector3) -> void:
	var musket := Node3D.new()
	musket.name = "PeriodMusket"
	musket.position = position
	musket.rotation_degrees = rotation
	parent.add_child(musket)
	_box(musket, "WoodenStock", Vector3(0, -0.38, 0), Vector3(0.12, 0.86, 0.09), wood_material)
	_cylinder(musket, "SteelBarrel", Vector3(0, 0.36, 0), 0.025, 1.12, _material(Color(0.08, 0.085, 0.095), 0.3, 0.78))


func _identity_label(parent: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.name = "IdentityLabel"
	label.position = position
	label.text = text
	label.font_size = 27
	label.outline_size = 8
	label.modulate = Color(0.96, 0.82, 0.48)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


func _build_period_figures(parent: Node3D) -> void:
	var figures := Node3D.new()
	figures.name = "PeriodFigures"
	parent.add_child(figures)
	_create_period_group(figures, "避难的市民", "resident", [Vector3(-2.8, 0.15, 9.1), Vector3(-3.85, 0.15, 8.4), Vector3(-3.8, 0.15, 6.7), Vector3(-2.7, 0.15, 7.25), Vector3(-3.65, 0.15, 10.8)])
	_create_period_group(figures, "推进的沙皇俄国军队", "soldier", [Vector3(2.5, 0.15, 5.65), Vector3(3.7, 0.15, 4.3), Vector3(2.35, 0.15, 3.35), Vector3(3.75, 0.15, 1.75), Vector3(2.65, 0.15, 1.0)])
	_create_period_group(figures, "波兰起义者", "insurgent", [Vector3(-3.5, 0.15, -10.4), Vector3(-2.55, 0.15, -11.0), Vector3(-3.8, 0.15, -12.1), Vector3(-2.65, 0.15, -13.2), Vector3(-3.65, 0.15, -14.45)])
	_create_running_crowd(figures)


func _create_period_group(parent: Node3D, identity: String, role: String, positions: Array[Vector3]) -> void:
	var group := Node3D.new()
	group.name = identity
	parent.add_child(group)
	for index in range(positions.size()):
		var actor: Node3D
		var character_id: String = TRIPO_GROUP_IDS[role][index]
		if TRIPO_CHARACTERS.has(character_id):
			actor = TRIPO_CHARACTERS[character_id].instantiate() as Node3D
		else:
			push_error("Missing approved character: " + character_id)
			continue
		actor.name = "%s_%d" % [identity, index + 1]
		actor.position = positions[index]
		if actor.has_meta("character_id"):
			actor.position.y = -0.01 # Top of the existing cobblestone road.
		var facings := {"resident": [-55.0, 32.0, 18.0, 42.0, -20.0], "soldier": [-25.0, -12.0, -4.0, -25.0, -43.0], "insurgent": [-25.0, 18.0, 35.0, 12.0, 48.0]}
		actor.rotation_degrees.y = facings[role][index]
		group.add_child(actor)
		actor.add_to_group("warsaw_idle_figures")
		actor.set_meta("idle_phase", float(index) * 1.7 + positions[index].x)
		_collision_box(actor, Vector3(0, 0.9, 0), Vector3(0.62, 1.8, 0.62))
	var centre := (positions[0] + positions[1] + positions[2]) / 3.0
	_identity_label(group, identity, centre + Vector3(0, 2.2, 0))
	var fill := OmniLight3D.new()
	fill.name = "TaskGroupFillLight"
	fill.position = centre + Vector3(0, 2.35, 0.8)
	fill.light_color = Color(0.64, 0.72, 0.9) if role == "soldier" else Color(0.92, 0.72, 0.52)
	fill.light_energy = 1.1
	fill.omni_range = 4.8
	fill.shadow_enabled = false
	group.add_child(fill)


func _create_running_crowd(parent: Node3D) -> void:
	var runners := [
		[Vector3(-1.65, 0.0, 18.0), -1.0, 0],
		[Vector3(1.65, 0.0, -18.0), 1.0, 1],
	]
	for index in range(runners.size()):
		var config: Array = runners[index]
		var start_position: Vector3 = config[0]
		var runner_file: String = CHARACTER_FILES[index % 2]
		var runner: Node3D = TRIPO_CHARACTERS["runner_%03d" % (index + 1)].instantiate()
		parent.add_child(runner)
		_normalize_finished_character(runner, 1.7 + index * 0.06)
		runner.name = "FleeingCivilian_%d" % (index + 1)
		runner.position = start_position
		_place_character_on_ground(runner, start_position.y)
		runner.rotation_degrees.x = 0.0
		runner.rotation_degrees.y = 180.0 if float(config[1]) < 0.0 else 0.0
		runner.add_to_group("warsaw_running_figures")
		runner.set_meta("start_z", runner.position.z)
		runner.set_meta("direction", float(config[1]))
		runner.set_meta("speed", [2.74, 2.98][index])
		runner.set_meta("phase", index * 0.73)
		runner.set_meta("ground_y", runner.position.y)
		# Tripo wrapper already starts the local looping Run animation.


func _normalize_finished_character(actor: Node3D, target_height: float) -> void:
	if actor == null:
		return
	var bounds := _character_bounds(actor)
	if bounds.size.y <= 0.001:
		return
	var factor := target_height / bounds.size.y
	actor.scale = Vector3.ONE * factor


func _place_character_on_ground(actor: Node3D, ground_y: float) -> void:
	if actor == null:
		return
	var bounds := _character_bounds(actor)
	actor.position.y = ground_y - bounds.position.y * actor.scale.y


func _character_bounds(actor: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	var inverse_root := actor.global_transform.affine_inverse()
	for mesh_node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds: AABB = (inverse_root * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds


func _build_interactions(parent: Node3D) -> void:
	_create_interaction(parent, "CiviliansContext", Vector3(-3.2, 1.0, 8.35), "街道一侧 · 避难的市民", "这些市民的动作和神情呈现出怎样的状态？", "他们显得紧张、惊恐和疲惫。有人保护孩子，有人搀扶同伴，有人准备离开，表现出战火中普通人的不安与无助。")
	_create_interaction(parent, "SoldiersContext", Vector3(3.15, 1.0, 4.55), "街道深处 · 推进的沙皇俄国军队", "这支军队的队列和姿态给你怎样的感觉？", "他们队列整齐、装备统一并不断向前推进，给人强势、冷峻和压迫的感觉，与临时组织的起义者形成明显对比。")
	_create_interaction(parent, "BarricadeContext", Vector3(-2.9, 1.0, -10.8), "破损的街垒前 · 波兰起义者", "这些起义者正在做什么？他们的姿态表现出怎样的心情？", "他们依托街垒警戒、举旗并持枪准备抵抗。姿态紧绷，既表现出害怕和压力，也表现出保卫家园的坚定与勇气。")


func _create_interaction(parent: Node3D, node_name: String, position: Vector3, title: String, question: String, answer: String) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = position
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_script(load("res://Scripts/interaction_spot.gd"))
	area.set("information_title", title)
	area.set("information_body", "")
	area.set("classroom_question", question)
	area.set("reference_answer", answer)
	area.set("completion_id", node_name)
	parent.add_child(area)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.15
	shape.shape = sphere
	area.add_child(shape)
	var hint := Label3D.new()
	hint.position = Vector3(0, 1.55, 0)
	hint.text = "查看"
	hint.font_size = 30
	hint.outline_size = 8
	hint.modulate = Color(0.96, 0.78, 0.42, 0.9)
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.no_depth_test = true
	area.add_child(hint)


func _update_hud() -> void:
	var title := get_node_or_null("Player/TouchHUD/SafeArea/SceneHeader/VBox/Title") as Label
	var subtitle := get_node_or_null("Player/TouchHUD/SafeArea/SceneHeader/VBox/Subtitle") as Label
	if title:
		title.text = "肖邦《革命练习曲》"
	if subtitle:
		subtitle.text = "第二幕 · 肖邦想象中的华沙"


func _configure_player_view() -> void:
	var player := get_node_or_null("Player") as Player
	if player:
		player.set_standing_camera_height(1.78)
		player.set_interaction_distance(6.5)
		player.camera_sens = 1.3


func register_warsaw_task(task_id: String) -> void:
	if task_id.is_empty() or completed_tasks.has(task_id):
		return
	completed_tasks[task_id] = true
	if completed_tasks.size() >= 3 and not lesson_introduced:
		lesson_introduced = true
		call_deferred("_show_revolutionary_etude_intro")


func _show_revolutionary_etude_intro() -> void:
	var player := get_node_or_null("Player") as Player
	if player == null:
		return
	player.touch_hud.show_lesson_completion(
			"刚才，我们从居民的惊慌、起义者的抗争和军队逼近的压迫感中，听见了同一段音乐里的不同情绪。\n\n接下来走进肖邦《革命练习曲》，从左手奔涌的音型、右手有力的旋律以及力度变化中，理解音乐怎样表达他对故乡的担忧、愤怒与不屈。"
	)


func _play_character_animation(root: Node3D, keyword: String) -> void:
	for child in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := child as AnimationPlayer
		if animation_player == null:
			continue
		var selected := StringName()
		for animation_name in animation_player.get_animation_list():
			if keyword.to_lower() in String(animation_name).to_lower():
				selected = animation_name
				break
		if not selected.is_empty():
			animation_player.speed_scale = 1.18 if keyword.to_lower() == "run" else 0.9
			animation_player.add_to_group("warsaw_character_animation_players")
			animation_player.set_meta("warsaw_animation", selected)
			animation_player.play(selected)


func _asset(parent: Node3D, path: String, position: Vector3, rotation: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Missing asset: " + path)
		return null
	var instance := packed.instantiate() as Node3D
	instance.position = position
	instance.rotation_degrees = rotation
	instance.scale = scale_value
	parent.add_child(instance)
	if path.begins_with(Q_BUILDINGS):
		_apply_weathered_building_materials(instance)
	return instance


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, collision := false, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = position
		body.rotation_degrees = rotation
		parent.add_child(body)
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		body.add_child(collision_shape)
	return mesh_instance


func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance


func _capsule(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 8
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance


func _collision_box(parent: Node3D, position: Vector3, size: Vector3, rotation := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.position = position
	body.rotation_degrees = rotation
	parent.add_child(body)
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	return body


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _make_smoke_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.84, 0.86, 0.88, 0.44),
		Color(0.61, 0.64, 0.67, 0.23),
		Color(0.41, 0.44, 0.47, 0.09),
		Color(0.25, 0.27, 0.3, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_moon_halo_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.52, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.86, 0.92, 1.0, 0.9),
		Color(0.63, 0.77, 1.0, 0.5),
		Color(0.38, 0.57, 0.92, 0.2),
		Color(0.2, 0.34, 0.68, 0.06),
		Color(0.08, 0.14, 0.31, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_cloud_texture() -> Texture2D:
	var image := Image.create(256, 96, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1831
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	for y in range(image.get_height()):
		var normalized_y := float(y) / float(image.get_height() - 1)
		var vertical_fade := pow(maxf(0.0, 1.0 - absf(normalized_y - 0.52) * 2.0), 1.7)
		for x in range(image.get_width()):
			var value := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var edge_fade := smoothstep(0.0, 0.12, float(x) / 255.0) * smoothstep(0.0, 0.12, float(255 - x) / 255.0)
			var alpha := clampf((value - 0.37) * 1.55 * vertical_fade * edge_fade, 0.0, 0.72)
			image.set_pixel(x, y, Color(0.78, 0.84, 0.94, alpha))
	return ImageTexture.create_from_image(image)

func _apply_weathered_building_materials(building: Node3D) -> void:
	for child in building.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null or original.albedo_texture != null: continue
			var name := original.resource_name
			if not weather_materials.has(name):
				var mat: BaseMaterial3D
				if "Plaster" in name:
					mat = wall_material.duplicate()
					mat.albedo_color = Color(0.75, 0.67, 0.55)
				elif "Wood" in name:
					mat = wood_material.duplicate()
					mat.albedo_color = Color(0.30, 0.22, 0.15) if not "Light" in name else Color(0.45, 0.34, 0.22)
				elif "Stone" in name or "Roof" in name:
					var module := (load(Q_ROOT + "Wall_UnevenBrick_Straight.gltf") as PackedScene).instantiate()
					for part in module.find_children("*", "MeshInstance3D", true, false):
						for part_surface in part.mesh.get_surface_count():
							var candidate: BaseMaterial3D = part.get_active_material(part_surface)
							if "Brick" in candidate.resource_name: mat = candidate.duplicate()
					module.free()
					if mat == null: mat = wall_material.duplicate()
					mat.albedo_color = Color(0.34, 0.31, 0.29) if "Roof" in name else Color(0.63, 0.59, 0.52)
				else:
					mat = original.duplicate()
					mat.albedo_color = Color(0.10, 0.14, 0.16)
					mat.roughness = 0.45
				mat.uv1_triplanar = true
				mat.uv1_world_triplanar = true
				mat.uv1_scale = Vector3.ONE * 1.3
				weather_materials[name] = mat
			mesh.set_surface_override_material(surface, weather_materials[name])

func _apply_touch_performance(root: Node) -> void:
	for node in root.find_children("*", "Light3D", true, false):
		node.shadow_enabled = false
		if node is OmniLight3D and node.name == "LampLight":
			node.distance_fade_enabled = true
			node.distance_fade_begin = 7.0
			node.distance_fade_length = 4.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = 0.75
