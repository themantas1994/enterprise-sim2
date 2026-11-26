extends GdUnitTestSuite
## Film-era kit (ui/themes/tmp): widgets build, font and shader load, touch targets, no cut captions, no text
## under the floor at both test sizes, reduced motion, determinism. No ship data is used.

const F := preload("res://tests/ui/ui_fixtures.gd")
const GALLERY := "res://ui/themes/tmp/tmp_kit_gallery.tscn"
## Ledger ENG-FONT-007 / OFL.txt SHA-256 (ENG-FONT-006).
const FONT_SHA := {
	"res://ui/themes/tmp/fonts/Exo2-Regular.ttf": "b00c1abe9cccdaef971fb79d2445220ae53ab11643558d48063cb002e7e60293",
	"res://ui/themes/tmp/fonts/Exo2-Bold.ttf": "0bae8c900d1c84abfb5264c6867ec2113fd0507680861f79b206093ebe0ce374",
	"res://ui/themes/tmp/fonts/OFL.txt": "cecc43de8bf5449d88fb03a6d33b0b569df304545d3b57760863e833a6434d45",
}


func after_test() -> void:
	UiScale.clear_override()


func _mount(size_key: String) -> Array:
	var cfg: Array = F.SIZES[size_key]
	UiScale.set_override(cfg[1], cfg[2])
	var vp := SubViewport.new()
	vp.size = cfg[0]
	vp.disable_3d = true
	add_child(vp)
	var g: Control = (load(GALLERY) as PackedScene).instantiate()
	vp.add_child(g)
	for i in 3:
		await get_tree().process_frame
	return [g, vp]


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		stack.append_array(n.get_children())
	return out


func test_every_widget_builds() -> void:
	var kit := TmpKit.new()
	assert_str(kit.era()).is_equal("tmp")
	assert_object(auto_free(kit.button())).is_instanceof(TmpButton)
	assert_object(auto_free(kit.gauge("x"))).is_instanceof(TmpBarGauge)
	assert_object(auto_free(kit.frame("x"))).is_instanceof(TmpFrame)
	assert_object(auto_free(kit.readout("a", "b"))).is_instanceof(TmpReadout)
	assert_object(auto_free(kit.schematic())).is_instanceof(TmpSchematic)
	assert_object(auto_free(kit.banner())).is_instanceof(TmpAlertBanner)
	assert_object(auto_free(kit.slider())).is_instanceof(TmpSlider)
	assert_object(auto_free(kit.caption("x"))).is_instanceof(Label)
	assert_object(auto_free(kit.lamp("amber", true))).is_instanceof(TmpLamp)
	assert_object(TmpTheme.build()).is_not_null()
	for n in ["red", "amber", "blue", "green", "white"]:
		assert_bool(TmpTokens.LAMP.has(n)).is_true()
	var g: Control = auto_free((load(GALLERY) as PackedScene).instantiate())
	add_child(g)
	await get_tree().process_frame
	assert_bool(_all_nodes(g).any(func(n: Node) -> bool: return n is TmpButton)).is_true()
	assert_object(g.crt_overlay()).is_not_null()


func test_font_files_match_the_ledger_and_load_through_the_theme() -> void:
	for path: String in FONT_SHA:
		assert_str(FileAccess.get_sha256(path)).override_failure_message(path).is_equal(FONT_SHA[path])
	assert_bool(FileAccess.file_exists("res://ui/themes/tmp/fonts/FONT-NOTICE.txt")).is_true()
	assert_bool(TmpTokens.font() is FontFile).is_true()
	assert_bool(TmpTokens.font_bold() is FontFile).is_true()
	assert_bool(TmpTokens.font() != TmpTokens.font_bold()).is_true()
	assert_bool(TmpTokens.font().has_char("A".unicode_at(0))).is_true()
	var t := TmpTheme.build()
	assert_bool(t.default_font == TmpTokens.font()).is_true()
	assert_bool(t.get_font("font", "Label") == TmpTokens.font()).is_true()


func test_shader_compiles_and_has_the_uniforms() -> void:
	var sh := TmpCrt.shader()
	assert_object(sh).is_not_null()
	assert_int(sh.get_mode()).is_equal(Shader.MODE_CANVAS_ITEM)
	var names: Array = sh.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u["name"])
	for u: String in TmpCrt.UNIFORMS:
		assert_bool(names.has(u) or sh.code.contains("uniform float %s" % u) or sh.code.contains("uniform bool %s" % u)).override_failure_message("uniform " + u).is_true()
	assert_bool(sh.code.contains("hint_screen_texture")).is_true()
	assert_bool(sh.code.contains("SCREEN_UV") and sh.code.contains("FRAGCOORD") and sh.code.contains("TIME")).is_true()
	assert_bool(sh.code.contains("SCREEN_TEXTURE")).is_false()
	var over := TmpCrt.overlay()
	assert_object(over.material).is_instanceof(ShaderMaterial)
	assert_bool(over.mouse_filter == Control.MOUSE_FILTER_IGNORE).is_true()
	auto_free(over)


func test_touch_targets_are_at_least_48_dp_at_both_sizes() -> void:
	for key: String in F.SIZES:
		var m := await _mount(key)
		var min_px := UiScale.dp(48.0) - 0.5
		var count := 0
		for n: Node in _all_nodes(m[0]):
			if n is Control and (n is BaseButton or n is Range or n.is_in_group("touch_target")) and (n as Control).is_visible_in_tree():
				count += 1
				assert_bool(n.size.x >= min_px and n.size.y >= min_px).override_failure_message("%s @ %s %s" % [n.get_path(), key, n.size]).is_true()
		assert_bool(count >= 10).is_true()
		(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func test_no_caption_is_cut_and_no_text_is_below_the_floor_at_both_sizes() -> void:
	for key: String in F.SIZES:
		var m := await _mount(key)
		var floor_size := UiScale.dp(12.0)
		var checked := 0
		for n: Node in _all_nodes(m[0]):
			if not (n is Control) or not (n as Control).is_visible_in_tree():
				continue
			var where := "%s @ %s" % [n.get_path(), key]
			if n is PanelButton:
				checked += 1
				assert_bool(n.is_truncated()).override_failure_message("truncated " + where).is_false()
				for fs: int in n.drawn_font_sizes():
					assert_bool(float(fs) >= floor_size).override_failure_message("small text %s: %d" % [where, fs]).is_true()
			elif n is Label or n is Readout or n is BarGauge or n is TmpSlider or n is TmpFrame or n is TmpAlertBanner:
				checked += 1
				if n.has_method("is_truncated"):
					assert_bool(n.is_truncated()).override_failure_message("truncated " + where).is_false()
				assert_bool(float(n.get_theme_font_size("font_size", "Label")) >= floor_size).override_failure_message("small text " + where).is_true()
		assert_bool(checked >= 20).is_true()
		assert_int(TmpTokens.min_font()).is_greater_equal(int(floor_size))
		(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func test_the_truncation_check_fails_for_a_too_long_caption() -> void:
	var m := await _mount("desktop")
	var b := TmpButton.new()
	b.set_caption("A caption far too long to fit in a small box")
	b.custom_minimum_size.x = 0.0
	b.size = Vector2(UiScale.dp(60.0), UiScale.dp(48.0))
	assert_bool(b.is_truncated()).is_true()
	b.free()
	(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func test_reduced_motion_turns_flicker_off() -> void:
	var over := TmpCrt.overlay(false)
	auto_free(over)
	assert_float(TmpCrt.effective_flicker(over)).is_greater(0.0)
	TmpCrt.set_reduced_motion(over, true)
	assert_float(TmpCrt.effective_flicker(over)).is_equal(0.0)
	var m := await _mount("desktop")
	var g: Control = m[0]
	g.set_reduced_motion(true)
	assert_float(TmpCrt.effective_flicker(g.crt_overlay())).is_equal(0.0)
	for b: AlertBanner in g.banners:
		assert_float(b.blink_period()).is_equal(0.0)
	(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func _signature(root: Node) -> Array:
	var sig: Array = []
	for n: Node in _all_nodes(root):
		var s := n.get_class()
		if n is Control:
			s += "|%s|%s" % [(n as Control).size, (n as Control).custom_minimum_size]
		if n is PanelButton:
			s += "|%s|%s|%s" % [n.caption, n.sub_caption, n.lamp_name()]
		sig.append(s)
	return sig


func test_kit_is_deterministic() -> void:
	var a := await _mount("desktop")
	var sig_a := _signature(a[0])
	(a[1] as SubViewport).queue_free()
	await get_tree().process_frame
	var b := await _mount("desktop")
	assert_array(_signature(b[0])).is_equal(sig_a)
	(b[1] as SubViewport).queue_free()
	await get_tree().process_frame
	# No randomness anywhere in the kit.
	var re := RegEx.new()
	re.compile("\\b(randi|randf|randomize|randi_range|randf_range|RandomNumberGenerator|rand)\\b")
	var dir := DirAccess.open("res://ui/themes/tmp")
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdshader"):
			var text := FileAccess.get_file_as_string("res://ui/themes/tmp/" + f)
			assert_bool(re.search(text) == null).override_failure_message("randomness in " + f).is_true()


func test_gallery_does_not_touch_ship_ids_or_the_host() -> void:
	var text := FileAccess.get_file_as_string("res://ui/themes/tmp/tmp_kit_gallery.gd")
	for word in ["SimHost", "sim_host", "ships/", "1701"]:
		assert_bool(text.contains(word)).override_failure_message(word).is_false()
