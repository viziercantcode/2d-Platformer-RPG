extends Control
class_name Healthbar

## Keeps the health fill and its light damage trail synchronized.

const TRAIL_HOLD_TIME := 0.55
const TRAIL_FADE_TIME := 0.45
const DAMAGE_FLASH_DURATION := 0.22

@onready var fill_clip: Control = $FillClip
@onready var fill_texture: TextureRect = $FillClip/Fill
@onready var trail_clip: Control = $TrailClip

var max_health: int = 100
var fill_width: float = 167.5
var current_ratio: float = 1.0
var target_ratio: float = 1.0
var trail_ratio: float = 1.0
var trail_hold_timer: float = 0.0
var trail_fade_elapsed: float = 0.0
var trail_fade_start_ratio: float = 1.0
var trail_fade_started: bool = false
var damage_flash_timer: float = 0.0

func _ready() -> void:
	fill_width = fill_texture.size.x
	_sync_visuals()

func setup(new_max_health: int, current_health: int) -> void:
	max_health = maxi(new_max_health, 1)
	var ratio := _health_ratio(current_health)
	current_ratio = ratio
	target_ratio = ratio
	trail_ratio = ratio
	trail_fade_started = false
	_sync_visuals()

func set_health(current_health: int) -> void:
	var new_ratio := _health_ratio(current_health)
	if is_equal_approx(new_ratio, current_ratio):
		return

	var previous_ratio := current_ratio
	target_ratio = new_ratio
	current_ratio = new_ratio

	if new_ratio < previous_ratio:
		trail_ratio = maxf(trail_ratio, previous_ratio)
		trail_hold_timer = TRAIL_HOLD_TIME
		trail_fade_started = false
	else:
		# On healing, don't leave a false "lost health" segment behind.
		trail_ratio = previous_ratio
		trail_hold_timer = 0.0
		trail_fade_started = false
	_sync_visuals()

func flash_damage() -> void:
	damage_flash_timer = DAMAGE_FLASH_DURATION
	modulate = Color(1.0, 0.45, 0.45, 1.0)

func _process(delta: float) -> void:
	if trail_ratio > target_ratio:
		if trail_hold_timer > 0.0:
			trail_hold_timer = maxf(trail_hold_timer - delta, 0.0)
		else:
			if not trail_fade_started:
				trail_fade_started = true
				trail_fade_elapsed = 0.0
				trail_fade_start_ratio = trail_ratio
			trail_fade_elapsed = minf(trail_fade_elapsed + delta, TRAIL_FADE_TIME)
			var fade_t := trail_fade_elapsed / TRAIL_FADE_TIME
			var eased_fade_t := fade_t * fade_t * (3.0 - 2.0 * fade_t)
			trail_ratio = lerpf(trail_fade_start_ratio, target_ratio, eased_fade_t)
			if trail_fade_elapsed >= TRAIL_FADE_TIME:
				trail_ratio = target_ratio

	if damage_flash_timer > 0.0:
		damage_flash_timer = maxf(damage_flash_timer - delta, 0.0)
		if damage_flash_timer == 0.0:
			modulate = Color.WHITE

	_sync_visuals()

func _health_ratio(health: int) -> float:
	return clampf(float(health) / float(max_health), 0.0, 1.0)

func _sync_visuals() -> void:
	if not is_instance_valid(fill_clip) or not is_instance_valid(trail_clip):
		return
	fill_clip.size.x = fill_width * current_ratio
	# Draw the pale trail only in the gap between current and previous health.
	# This prevents it from showing through the fill texture at full health.
	var current_width := fill_width * current_ratio
	var trail_width := fill_width * maxf(trail_ratio - current_ratio, 0.0)
	trail_clip.position = Vector2(fill_clip.position.x + current_width, fill_clip.position.y)
	trail_clip.size = Vector2(trail_width, fill_clip.size.y)
