extends Control
class_name OptionsMenu

signal closed

const OPTIONS_FONT: FontFile = preload("res://Assets/Font/TrajanPro-Regular.ttf")
const DEFAULT_MUSIC := 1
const DEFAULT_SFX := 1
const DEFAULT_RESOLUTION := Vector2i(1152, 648)

var _active_section := "game"
var _selected_resolution: Vector2i = DEFAULT_RESOLUTION
var _nav_buttons: Dictionary
var _pages: Dictionary
var _nav_arrows: Dictionary
var _volume_sliders: Dictionary = {}
var _volume_labels: Dictionary = {}

@onready var _settings_panel: PanelContainer = $Center/SettingsPanel
@onready var _language_selector: OptionButton = $Center/SettingsPanel/Margins/Columns/Right/Pages/GamePage/LanguageRow/LanguageSelector
@onready var _resolution_selector: OptionButton = $Center/SettingsPanel/Margins/Columns/Right/Pages/VideoPage/ResolutionRow/ResolutionSelector
@onready var _fullscreen_toggle: CheckButton = $Center/SettingsPanel/Margins/Columns/Right/Pages/VideoPage/FullscreenToggle
@onready var _back_button: Button = $Center/SettingsPanel/Margins/Columns/Navigation/BackButton
@onready var _nav_heading: Label = $Center/SettingsPanel/Margins/Columns/Navigation/NavHeading


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_nav_buttons = {
		"game": $Center/SettingsPanel/Margins/Columns/Navigation/GameButton,
		"audio": $Center/SettingsPanel/Margins/Columns/Navigation/AudioButton,
		"video": $Center/SettingsPanel/Margins/Columns/Navigation/VideoButton,
		"controller": $Center/SettingsPanel/Margins/Columns/Navigation/ControllerButton,
		"keyboard": $Center/SettingsPanel/Margins/Columns/Navigation/KeyboardButton,
	}
	_pages = {
		"game": $Center/SettingsPanel/Margins/Columns/Right/Pages/GamePage,
		"audio": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage,
		"video": $Center/SettingsPanel/Margins/Columns/Right/Pages/VideoPage,
		"controller": $Center/SettingsPanel/Margins/Columns/Right/Pages/ControllerPage,
		"keyboard": $Center/SettingsPanel/Margins/Columns/Right/Pages/KeyboardPage,
	}
	_nav_arrows = {
		"game": [_nav_buttons["game"].get_node("HoverLeft"), _nav_buttons["game"].get_node("HoverRight")],
		"audio": [_nav_buttons["audio"].get_node("HoverLeft"), _nav_buttons["audio"].get_node("HoverRight")],
		"video": [_nav_buttons["video"].get_node("HoverLeft"), _nav_buttons["video"].get_node("HoverRight")],
		"controller": [_nav_buttons["controller"].get_node("HoverLeft"), _nav_buttons["controller"].get_node("HoverRight")],
		"keyboard": [_nav_buttons["keyboard"].get_node("HoverLeft"), _nav_buttons["keyboard"].get_node("HoverRight")],
		"back": [_back_button.get_node("HoverLeft"), _back_button.get_node("HoverRight")],
	}
	_volume_sliders = {
		"master": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage/MasterRow/Slider,
		"music": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage/MusicRow/Slider,
		"sfx": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage/SfxRow/Slider,
	}
	_volume_labels = {
		"master": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage/MasterRow/Percentage,
		"music": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage/MusicRow/Percentage,
		"sfx": $Center/SettingsPanel/Margins/Columns/Right/Pages/AudioPage/SfxRow/Percentage,
	}
	_apply_visual_styles()
	_connect_controls()
	_load_current_settings()
	_show_page("game")


func open() -> void:
	_show_page("game")
	visible = true


func _connect_controls() -> void:
	_nav_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for section in _nav_buttons:
		var button: Button = _nav_buttons[section]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.pressed.connect(_show_page.bind(section))
		_configure_sidebar_hover(button, _nav_arrows[section])
	_back_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_button.pressed.connect(_on_close_pressed)
	_configure_sidebar_hover(_back_button, _nav_arrows["back"])
	for section in ["game", "audio", "video"]:
		var reset_button: Button = _pages[section].get_node("Footer/ResetButton")
		reset_button.pressed.connect(_on_reset_pressed.bind(section))
	_language_selector.select(0)
	for key in _volume_sliders:
		_volume_sliders[key].value_changed.connect(_on_volume_changed.bind(_bus_names_for(key), _volume_labels[key]))
	_resolution_selector.item_selected.connect(_on_resolution_selected)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)


func _load_current_settings() -> void:
	for key in _volume_sliders:
		var value := _get_bus_linear_volume(_bus_names_for(key), _default_for(key))
		_volume_sliders[key].set_value_no_signal(value)
		_volume_labels[key].text = "%d%%" % roundi(value * 100.0)
	for resolution in [Vector2i(3840, 2160), Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1024, 600), Vector2i(800, 600), DEFAULT_RESOLUTION]:
		_resolution_selector.add_item("%d × %d" % [resolution.x, resolution.y])
		_resolution_selector.set_item_metadata(_resolution_selector.item_count - 1, resolution)
	_selected_resolution = get_window().size
	_select_current_resolution(_selected_resolution)
	var window_mode := DisplayServer.window_get_mode()
	_fullscreen_toggle.set_pressed_no_signal(window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _show_page(section: String) -> void:
	_active_section = section
	for key in _pages:
		_pages[key].visible = key == section
		var selected: bool = key == section
		var button: Button = _nav_buttons[key]
		button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0) if selected else Color(0.82, 0.87, 0.9))
		_set_text_glow(button, selected)
		button.add_theme_stylebox_override("normal", _make_button_style(selected, false))


func _on_reset_pressed(section: String) -> void:
	match section:
		"game":
			_language_selector.select(0)
		"audio":
			_set_volume("master", 1.0)
			_set_volume("music", DEFAULT_MUSIC)
			_set_volume("sfx", DEFAULT_SFX)
		"video":
			_selected_resolution = DEFAULT_RESOLUTION
			_select_current_resolution(DEFAULT_RESOLUTION)
			_fullscreen_toggle.set_pressed_no_signal(false)
			_on_fullscreen_toggled(false)


func _select_current_resolution(requested: Vector2i = Vector2i.ZERO) -> void:
	var current_size := requested if requested != Vector2i.ZERO else _selected_resolution
	for index in range(_resolution_selector.item_count):
		if _resolution_selector.get_item_metadata(index) == current_size:
			_resolution_selector.select(index)
			return
	_resolution_selector.select(0)


func _on_resolution_selected(index: int) -> void:
	_selected_resolution = _resolution_selector.get_item_metadata(index)
	var window_mode := DisplayServer.window_get_mode()
	var fullscreen := window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if not fullscreen:
		get_window().size = _selected_resolution


func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	if not enabled:
		call_deferred("_apply_selected_windowed_resolution")


func _apply_selected_windowed_resolution() -> void:
	get_window().size = _selected_resolution


func _on_volume_changed(value: float, buses: Array, percentage: Label) -> void:
	var volume_db := -80.0 if value <= 0.0001 else linear_to_db(value)
	for bus_name in buses:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, volume_db)
	percentage.text = "%d%%" % roundi(value * 100.0)


func _set_volume(key: String, value: float) -> void:
	var volume_db := -80.0 if value <= 0.0001 else linear_to_db(value)
	for bus_name in _bus_names_for(key):
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, volume_db)
	_volume_sliders[key].set_value_no_signal(value)
	_volume_labels[key].text = "%d%%" % roundi(value * 100.0)


func _get_bus_linear_volume(bus_names: Array, fallback: float) -> float:
	for bus_name in bus_names:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.0, 1.0)
	return fallback


func _bus_names_for(key: String) -> Array:
	match key:
		"master": return ["Master"]
		"music": return ["MainMenu_Bus", "MainGame"]
		"sfx": return ["SFX"]
	return []


func _default_for(key: String) -> float:
	match key:
		"master": return 1.0
		"music": return DEFAULT_MUSIC
		"sfx": return DEFAULT_SFX
	return 1.0


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _apply_visual_styles() -> void:
	_settings_panel.add_theme_stylebox_override("panel", _make_panel_style())
	for button in find_children("*", "Button", true, false):
		button.add_theme_font_override("font", OPTIONS_FONT)
		button.add_theme_color_override("font_color", Color(0.82, 0.87, 0.9))
		button.add_theme_color_override("font_hover_color", Color(0.94, 0.97, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.94, 0.97, 1.0))
		button.add_theme_stylebox_override("normal", _make_button_style(false, false))
		button.add_theme_stylebox_override("hover", _make_hover_glow_style())
		button.add_theme_stylebox_override("focus", _make_hover_glow_style())
		button.add_theme_stylebox_override("pressed", _make_button_style(false, true))
	for control in [_language_selector, _resolution_selector]:
		_style_input(control)
	for slider in find_children("*", "HSlider", true, false):
		_style_slider(slider)


func _configure_sidebar_hover(button: Button, arrows: Array) -> void:
	var label_width := OPTIONS_FONT.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var left_arrow: TextureRect = arrows[0]
	var right_arrow: TextureRect = arrows[1]
	left_arrow.offset_left = -(label_width * 0.5) - 56.0
	left_arrow.offset_right = left_arrow.offset_left + 48.0
	right_arrow.offset_left = label_width * 0.5 + 8.0
	right_arrow.offset_right = right_arrow.offset_left + 48.0
	button.mouse_entered.connect(_set_sidebar_hover.bind(button, arrows, true))
	button.mouse_exited.connect(_set_sidebar_hover.bind(button, arrows, false))
	button.focus_entered.connect(_set_sidebar_hover.bind(button, arrows, true))
	button.focus_exited.connect(_set_sidebar_hover.bind(button, arrows, false))


func _set_sidebar_hover(button: Button, arrows: Array, hovered: bool) -> void:
	for arrow in arrows:
		arrow.visible = hovered
	var selected: bool = _nav_buttons.get(_active_section) == button
	button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0) if selected or hovered else Color(0.82, 0.87, 0.9))
	_set_text_glow(button, selected or hovered)
	if hovered:
		button.add_theme_stylebox_override("hover", _make_hover_glow_style())
		button.add_theme_stylebox_override("focus", _make_hover_glow_style())
	else:
		button.add_theme_stylebox_override("normal", _make_button_style(selected, false))

func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxLine.new()
	track.color = Color(0.38, 0.44, 0.48, 0.9)
	track.thickness = 3.0
	slider.add_theme_stylebox_override("slider", track)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.86, 0.92, 0.97)
	grabber.set_corner_radius_all(20)
	grabber.set_content_margin_all(5)
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)


func _style_input(control: Control) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.065, 0.082, 0.8)
	normal.border_color = Color(0.62, 0.7, 0.75, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	control.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.17, 0.19, 0.95)
	hover.border_color = Color(0.86, 0.92, 0.97, 0.8)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_color_override("font_color", Color(0.87, 0.9, 0.91))
	control.add_theme_color_override("font_hover_color", Color(0.94, 0.97, 1.0))


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.032, 0.047, 0.94)
	style.border_color = Color(0.64, 0.72, 0.77, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 18
	return style


func _make_button_style(is_selected: bool, is_pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.19, 0.44) if is_selected else Color(0.02, 0.04, 0.06, 0.08)
	if is_pressed:
		style.bg_color = Color(0.58, 0.66, 0.7, 0.24)
	style.border_color = Color(0.86, 0.92, 0.97, 0.5)
	style.border_width_left = 0
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 10.0
	return style

func _set_text_glow(button: Button, enabled: bool) -> void:
	var glow_color := Color(1.0, 1.0, 1.0, 0.72) if enabled else Color(1.0, 1.0, 1.0, 0.0)
	button.add_theme_color_override("font_shadow_color", glow_color)
	button.add_theme_constant_override("shadow_outline_size", 5 if enabled else 0)
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)

func _make_hover_glow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_color = Color(0.92, 0.96, 1.0, 0.16)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 10.0
	return style
