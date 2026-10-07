extends Node2D

const MENU_FONT: FontFile = preload("res://Assets/Font/TrajanPro-Regular.ttf")

var button_type: String = ""
var _menu_panel: Control

@onready var options_menu: OptionsMenu = $OptionsLayer/OptionsMenu
@onready var fade_transition: CanvasItem = $Fade_transition
@onready var fade_timer: Timer = $Fade_transition/Fade_timer
@onready var hover_sfx: AudioStreamPlayer = $Hover_sfx
@onready var click_sfx: AudioStreamPlayer = $Click_sfx
@onready var start_button: Button = $MenuLayer/MenuRoot/ButtonCenter/MenuButtons/StartGameButton
@onready var options_button: Button = $MenuLayer/MenuRoot/ButtonCenter/MenuButtons/OptionsButton
@onready var quit_button: Button = $MenuLayer/MenuRoot/ButtonCenter/MenuButtons/QuitGameButton


func _ready() -> void:
	_menu_panel = $MenuLayer/MenuRoot/ButtonCenter/MenuButtons
	options_menu.visible = false
	_configure_menu_button(start_button, _on_start_pressed)
	_configure_menu_button(options_button, _on_options_pressed)
	_configure_menu_button(quit_button, _on_quit_pressed)


func _configure_menu_button(button: Button, action: Callable) -> void:
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color(0.83, 0.87, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(false, false))
	button.add_theme_stylebox_override("hover", _make_button_style(true, false))
	button.add_theme_stylebox_override("focus", _make_button_style(true, false))
	button.add_theme_stylebox_override("pressed", _make_button_style(false, true))
	var left_arrow: TextureRect = button.get_node("HoverArrowLeft")
	var right_arrow: TextureRect = button.get_node("HoverArrowRight")
	var label_width := MENU_FONT.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
	left_arrow.offset_left = -(label_width * 0.5) - 64.0
	left_arrow.offset_right = left_arrow.offset_left + 56.0
	right_arrow.offset_left = label_width * 0.5 + 8.0
	right_arrow.offset_right = right_arrow.offset_left + 56.0
	button.mouse_entered.connect(_on_menu_button_hovered.bind(button, left_arrow, right_arrow))
	button.mouse_exited.connect(_on_menu_button_unhovered.bind(button, left_arrow, right_arrow))
	button.focus_entered.connect(_on_menu_button_hovered.bind(button, left_arrow, right_arrow))
	button.focus_exited.connect(_on_menu_button_unhovered.bind(button, left_arrow, right_arrow))
	button.pressed.connect(action)


func _make_button_style(is_hovered: bool, is_pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	if is_hovered:
		style.shadow_color = Color(0.92, 0.96, 1.0, 0.18)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
	#if is_pressed:
		#style.bg_color = Color(0.58, 0.66, 0.7, 0.24)
	#style.border_color = Color(0.91, 0.82, 0.63, 0.84)
	#style.border_width_left = 3 if is_pressed else 0
	#style.set_corner_radius_all(3)
	#style.content_margin_left = 18.0
	#style.content_margin_right = 12.0
	return style


func _on_menu_button_hovered(button: Button, left_arrow: TextureRect, right_arrow: TextureRect) -> void:
	left_arrow.show()
	right_arrow.show()
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	hover_sfx.play()


func _on_menu_button_unhovered(button: Button, left_arrow: TextureRect, right_arrow: TextureRect) -> void:
	left_arrow.hide()
	right_arrow.hide()
	button.add_theme_color_override("font_color", Color(0.83, 0.87, 0.9))


func _on_start_pressed() -> void:
	button_type = "start"
	click_sfx.play()
	_menu_panel.hide()
	fade_transition.show()
	fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")


func _on_options_pressed() -> void:
	click_sfx.play()
	_menu_panel.hide()
	options_menu.open()


func _on_quit_pressed() -> void:
	click_sfx.play()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_options_closed() -> void:
	click_sfx.play()
	_menu_panel.show()
