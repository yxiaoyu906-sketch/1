extends Area3D

@export_file("*.tscn") var target_scene: String = ""
@export var transition_message: String = "正在进入第二幕：华沙"
var changing_scene := false

func interact(player: Player) -> void:
	if changing_scene or target_scene.is_empty():
		return
	changing_scene = true
	player.set_controls_locked(true)
	player.touch_hud.show_notice(transition_message)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.prepareWarsawPack && window.prepareWarsawPack(false)")
		var state := "loading"
		while state != "ready":
			state = str(JavaScriptBridge.eval("window.warsawPackState || 'loading'"))
			if state == "error":
				changing_scene = false
				player.set_controls_locked(false)
				player.touch_hud.show_notice("第二幕资源载入未完成，请点击出口重试")
				return
			await get_tree().create_timer(0.1).timeout
		if not ProjectSettings.load_resource_pack("/warsaw.pck", false):
			JavaScriptBridge.eval("window.abortWarsawTransition && window.abortWarsawTransition()", true)
			changing_scene = false
			player.set_controls_locked(false)
			player.touch_hud.show_notice("第二幕资源载入失败，请重新打开网页")
			return
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_file(target_scene)
