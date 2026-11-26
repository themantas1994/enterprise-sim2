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


func test_shader_uniform_list_and_required_builtins_parse() -> void:
	# Headless runs use the dummy renderer: this checks that the shader source parses (the uniform list comes
	# from the parser) and names the required built-ins. Drawing is checked by the Compatibility screenshot run.
	var sh := TmpCrt.shader()
	assert_object(sh).is_not_null()
	assert_int(sh.get_mode()).is_equal(Shader.MODE_CANVAS_ITEM)
	var names: Array = sh.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u["name"])
	for u: String in TmpCrt.UNIFORMS:
		assert_bool(names.has(u)).override_failure_message("uniform " + u).is_true()
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


const DRAWN_TYPES := ["TmpButton", "TmpFrame", "TmpAlertBanner", "TmpBarGauge", "TmpReadout", "TmpSlider"]


## Text drawn smaller than `floor_size`, from what the widgets draw (drawn_font_sizes), plus cut captions.
## Returns {"small": [descriptions], "cut": [descriptions], "types": {class name: count checked}}.
func _text_report(root: Node, floor_size: float, key: String) -> Dictionary:
	var out := {"small": [], "cut": [], "types": {}, "small_types": {}}
	for n: Node in _all_nodes(root):
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var where := "%s @ %s" % [n.get_path(), key]
		if n.has_method("drawn_font_sizes"):
			var tname: String = n.get_script().get_global_name()
			out["types"][tname] = int(out["types"].get(tname, 0)) + 1
			for fs: int in n.drawn_font_sizes():
				if float(fs) < floor_size:
					out["small"].append("%s: %d" % [where, fs])
					out["small_types"][tname] = true
		if n.has_method("is_truncated") and n.is_truncated():
			out["cut"].append(where)
		elif n is Label and float(n.get_theme_font_size("font_size", "Label")) < floor_size:
			out["small"].append("%s: label" % where)
	return out


func test_no_caption_is_cut_and_no_drawn_text_is_below_the_floor_at_both_sizes() -> void:
	for key: String in F.SIZES:
		var m := await _mount(key)
		var rep := _text_report(m[0], UiScale.dp(12.0), key)
		assert_array(rep["small"]).is_empty()
		assert_array(rep["cut"]).is_empty()
		for t: String in DRAWN_TYPES:
			assert_bool(int(rep["types"].get(t, 0)) > 0).override_failure_message("no %s checked @ %s" % [t, key]).is_true()
		assert_int(TmpTokens.min_font()).is_greater_equal(int(UiScale.dp(12.0)))
		(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


## Negative control: with the floor raised above what the widgets draw, the same check must report every
## widget type as too small, at both sizes. This proves the check can fail for each type.
func test_the_text_floor_check_can_fail_for_every_widget_type_at_both_sizes() -> void:
	for key: String in F.SIZES:
		var m := await _mount(key)
		var rep := _text_report(m[0], UiScale.dp(60.0), key)
		for t: String in DRAWN_TYPES:
			assert_bool(rep["small_types"].has(t)).override_failure_message("%s not reported @ %s" % [t, key]).is_true()
		(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func test_a_narrow_button_shrinks_its_text_to_the_minimum_before_cutting() -> void:
	var m := await _mount("desktop")
	var b := TmpButton.new()
	b.set_caption("Caption text")
	b.custom_minimum_size.x = 0.0   # a Control cannot be sized below its minimum
	var default_fs := int(UiScale.dp(16.0))
	var info := b._metrics(UiScale.touch_min())
	var bold := TmpTokens.font_bold()
	var min_need := bold.get_string_size(b.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, TmpTokens.min_font()).x + float(info["text_x"]) + float(info["pad"]) + float(info["bevel"]) * 2.0
	# Wide enough for the minimum size only: shrunk, not cut.
	b.size = Vector2(min_need + 2.0, UiScale.touch_min())
	var sizes: Array = b.drawn_font_sizes()
	assert_int(sizes[0]).is_less(default_fs)
	assert_int(sizes[0]).is_greater_equal(TmpTokens.min_font())
	assert_bool(b.is_truncated()).is_false()
	# Narrower than the minimum size needs: the size stays at the minimum and the text is cut (and reported).
	b.size = Vector2(min_need * 0.6, UiScale.touch_min())
	assert_int(b.drawn_font_sizes()[0]).is_equal(TmpTokens.min_font())
	assert_bool(b.is_truncated()).is_true()
	b.free()
	(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func test_set_fill_after_set_caption_grows_the_button_for_the_marker() -> void:
	var b := TmpButton.new()
	b.set_caption("Medium caption")
	var before := b.custom_minimum_size.x
	b.set_fill(0.5)
	assert_float(b.custom_minimum_size.x).is_greater(before)
	b.free()


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
	assert_int(g.crt_overlays().size()).is_equal(2)
	for o: ColorRect in g.crt_overlays():
		assert_float(TmpCrt.effective_flicker(o)).is_equal(0.0)
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
			s += "|%s|%s|%s|%s|%s" % [n.caption, n.sub_caption, n.lamp_name(), n.level, n.is_pressed()]
		if n.has_method("drawn_font_sizes"):
			s += "|fs%s" % [n.drawn_font_sizes()]
		if n is TmpLamp:
			s += "|%s|%s|%s" % [n.lamp_name, n.lit, TmpTokens.lamp_color(n.lamp_name).to_html()]
		if n is TmpSchematic:
			s += "|%s" % n.trace_color().to_html()
		if n is ColorRect and n.material is ShaderMaterial:
			s += "|" + ",".join(TmpCrt.UNIFORMS.map(func(u: String) -> String: return str((n.material as ShaderMaterial).get_shader_parameter(u))))
		sig.append(s)
	return sig


func test_two_builds_of_the_gallery_are_identical_and_the_kit_uses_no_randomness() -> void:
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


func test_every_crt_overlay_has_its_own_back_buffer_copy_just_before_it() -> void:
	var m := await _mount("desktop")
	var g: Control = m[0]
	var overlays := TmpCrt.find_overlays(g)
	assert_int(overlays.size()).is_equal(2)
	var copies := g.find_children("*", "BackBufferCopy", true, false)
	assert_int(copies.size()).is_equal(overlays.size())
	for o: ColorRect in overlays:
		var parent := o.get_parent()
		var prev := parent.get_child(o.get_index() - 1)
		assert_bool(prev is BackBufferCopy).override_failure_message("no BackBufferCopy before " + str(o.get_path())).is_true()
		assert_int((prev as BackBufferCopy).copy_mode).is_equal(BackBufferCopy.COPY_MODE_VIEWPORT)
	# A second kit user with two regions of its own gets the same structure.
	var box := VBoxContainer.new()
	box.add_child(TmpCrt.wrap(Control.new()))
	box.add_child(TmpCrt.wrap(Control.new()))
	auto_free(box)
	assert_int(TmpCrt.find_overlays(box).size()).is_equal(2)
	assert_int(box.find_children("*", "BackBufferCopy", true, false).size()).is_equal(2)
	# The full-screen variant: a copy before the overlay, and the documented layer index.
	var layer := TmpCrt.layer()
	auto_free(layer)
	assert_int(layer.layer).is_equal(TmpCrt.DEFAULT_LAYER)
	assert_bool(layer.get_child(0) is BackBufferCopy and layer.get_child(1) is ColorRect).is_true()
	(m[1] as SubViewport).queue_free()
	await get_tree().process_frame


func test_the_overlay_follows_the_screen_density_when_the_viewport_changes() -> void:
	var m := await _mount("desktop")
	var vp: SubViewport = m[1]
	var o: ColorRect = (m[0] as TmpKitGallery).crt_overlay()
	var mat := o.material as ShaderMaterial
	assert_float(float(mat.get_shader_parameter("scan_period"))).is_equal_approx(TmpCrt.scan_period_px(), 0.001)
	var before := float(mat.get_shader_parameter("scan_period"))
	UiScale.set_override(2.5, 1.5)
	vp.size = Vector2i(1440, 720)   # emits size_changed on the viewport
	await get_tree().process_frame
	assert_float(TmpCrt.scan_period_px()).is_not_equal(before)
	assert_float(float(mat.get_shader_parameter("scan_period"))).is_equal_approx(TmpCrt.scan_period_px(), 0.001)
	assert_float(float(mat.get_shader_parameter("glow_radius"))).is_equal_approx(TmpCrt.glow_radius_px(), 0.001)
	vp.queue_free()
	await get_tree().process_frame


func test_a_failed_font_load_is_not_cached_and_banner_teeth_are_clipped() -> void:
	assert_object(TmpTokens._load_font("res://ui/themes/tmp/fonts/missing.ttf")).is_null()
	assert_bool(TmpTokens.font() is FontFile).is_true()
	var b := TmpAlertBanner.new()
	auto_free(b)
	assert_bool(b.clip_contents).is_true()
