extends Control
class_name OptionsMenu

signal closed

@onready var music_slider: HSlider = $Center/Panel/MusicSlider
@onready var sfx_slider: HSlider = $Center/Panel/SFXSlider
@onready var music_value: Label = $Center/Panel/MusicValue
@onready var sfx_value: Label = $Center/Panel/SFXValue
@onready var fullscreen_toggle: CheckButton = $Center/Panel/Fullscreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var music_bus_id := AudioServer.get_bus_index("MainMenu_Bus")
	var sfx_bus_id := AudioServer.get_bus_index("SFX")
	if music_bus_id >= 0:
		music_slider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(music_bus_id)), 0.0, 1.0)
	if sfx_bus_id >= 0:
		sfx_slider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_id)), 0.0, 1.0)
	fullscreen_toggle.set_block_signals(true)
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_toggle.set_block_signals(false)
	_update_volume_labels()

func open() -> void:
	visible = true
	fullscreen_toggle.set_block_signals(true)
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_toggle.set_block_signals(false)

func _on_music_changed(value: float) -> void:
	var volume_db := linear_to_db(value)
	for bus_name in ["MainMenu_Bus", "MainGame"]:
		var bus_id := AudioServer.get_bus_index(bus_name)
		if bus_id >= 0:
			AudioServer.set_bus_volume_db(bus_id, volume_db)
	_update_volume_labels()

func _on_sfx_changed(value: float) -> void:
	var bus_id := AudioServer.get_bus_index("SFX")
	if bus_id >= 0:
		AudioServer.set_bus_volume_db(bus_id, linear_to_db(value))
	_update_volume_labels()

func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _on_reset_pressed() -> void:
	music_slider.value = 0.7
	sfx_slider.value = 0.85
	_on_music_changed(music_slider.value)
	_on_sfx_changed(sfx_slider.value)
	fullscreen_toggle.button_pressed = false
	_on_fullscreen_toggled(false)

func _on_back_pressed() -> void:
	visible = false
	closed.emit()

func _update_volume_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)
