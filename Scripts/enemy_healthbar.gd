extends Node2D
class_name EnemyHealthBar

## Displays enemy health and stun, with a delayed health trail after damage.

const HEALTH_TRAIL_HOLD_TIME := 0.55
const HEALTH_TRAIL_FADE_TIME := 0.45
const LEVEL_TEXTURES := [
	preload("res://Assets/Enemy Healthbar/Level1.png"),
	preload("res://Assets/Enemy Healthbar/Level2.png"),
	preload("res://Assets/Enemy Healthbar/Level3.png")
]

@onready var health_delayed: TextureProgressBar = $HealthDelayed
@onready var health_bar: TextureProgressBar = $Health
@onready var stun_bar: TextureProgressBar = $Stun
@onready var level_sprite: Sprite2D = $Level

var health_max: float = 1.0
var stun_max: float = 1.0
var delayed_health_ratio: float = 1.0
var delayed_health_hold_timer: float = 0.0
var delayed_health_fade_elapsed: float = 0.0
var delayed_health_fade_start_ratio: float = 1.0
var delayed_health_fade_started := false

func setup(new_health_max: int, new_stun_max: float, enemy_level: int) -> void:
	health_max = maxf(float(new_health_max), 1.0)
	stun_max = maxf(new_stun_max, 1.0)
	set_level(enemy_level)
	delayed_health_ratio = 1.0
	delayed_health_hold_timer = 0.0
	delayed_health_fade_started = false
	_set_progress(health_bar, 100.0)
	_set_progress(health_delayed, 100.0)
	_set_progress(stun_bar, 0.0)

func set_level(enemy_level: int) -> void:
	if not is_instance_valid(level_sprite):
		return
	var level_index := clampi(enemy_level, 1, LEVEL_TEXTURES.size()) - 1
	level_sprite.texture = LEVEL_TEXTURES[level_index]

func set_health(current_health: int) -> void:
	var new_ratio := clampf(float(current_health) / health_max, 0.0, 1.0)
	var current_ratio := health_bar.value / 100.0
	_set_progress(health_bar, new_ratio * 100.0)

	if new_ratio < current_ratio:
		delayed_health_ratio = maxf(delayed_health_ratio, current_ratio)
		delayed_health_hold_timer = HEALTH_TRAIL_HOLD_TIME
		delayed_health_fade_started = false
	elif new_ratio > current_ratio:
		delayed_health_ratio = new_ratio
		delayed_health_hold_timer = 0.0
		delayed_health_fade_started = false

	_set_progress(health_delayed, delayed_health_ratio * 100.0)

func set_stun(current_stun: float) -> void:
	_set_progress(stun_bar, clampf(current_stun / stun_max, 0.0, 1.0) * 100.0)

func _process(delta: float) -> void:
	var current_ratio := health_bar.value / 100.0
	if delayed_health_ratio > current_ratio:
		if delayed_health_hold_timer > 0.0:
			delayed_health_hold_timer = maxf(delayed_health_hold_timer - delta, 0.0)
		else:
			if not delayed_health_fade_started:
				delayed_health_fade_started = true
				delayed_health_fade_elapsed = 0.0
				delayed_health_fade_start_ratio = delayed_health_ratio
			delayed_health_fade_elapsed = minf(delayed_health_fade_elapsed + delta, HEALTH_TRAIL_FADE_TIME)
			var fade_t := delayed_health_fade_elapsed / HEALTH_TRAIL_FADE_TIME
			var eased_fade_t := fade_t * fade_t * (3.0 - 2.0 * fade_t)
			delayed_health_ratio = lerpf(delayed_health_fade_start_ratio, current_ratio, eased_fade_t)
			if delayed_health_fade_elapsed >= HEALTH_TRAIL_FADE_TIME:
				delayed_health_ratio = current_ratio

		_set_progress(health_delayed, delayed_health_ratio * 100.0)

func _set_progress(bar: TextureProgressBar, percentage: float) -> void:
	if is_instance_valid(bar):
		bar.value = clampf(percentage, 0.0, 100.0)
