extends Node2D
class_name BossProjectile

@export var damage := 30
@export var knockback_force := 320.0
@export var lifetime := 3.0
var velocity := Vector2.ZERO
var uses_gravity := true
var projectile_gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var can_move := true
var exploded := false
var source_boss: Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $HitBox
@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	hitbox.area_entered.connect(_on_area_entered)
	hitbox.body_entered.connect(_on_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start(lifetime)
	animated_sprite.flip_h = velocity.x < 0.0
	animated_sprite.play("default")

func initialize(start_position: Vector2, start_velocity: Vector2, gravity_enabled: bool, boss: Node2D) -> void:
	global_position = start_position
	velocity = start_velocity
	uses_gravity = gravity_enabled
	source_boss = boss

func _physics_process(delta: float) -> void:
	if not can_move:
		return
	if uses_gravity:
		velocity.y += projectile_gravity * delta
	global_position += velocity * delta

func _on_area_entered(area: Area2D) -> void:
	if exploded:
		return
	if is_instance_valid(source_boss) and area == source_boss.get_node_or_null("EnemyHitbox"):
		return
	if area.name != "PlayerHitbox":
		return
	var player := Global.playerBody
	if is_instance_valid(player) and not player.health.dead:
		_apply_damage(player)
	_explode()

func _on_body_entered(body: Node2D) -> void:
	if exploded:
		return
	var player := Global.playerBody
	if is_instance_valid(player) and body == player and not player.health.dead:
		_apply_damage(player)
	_explode()

func _apply_damage(player: Player) -> void:
	var direction := signf(player.global_position.x - global_position.x)
	if direction == 0.0:
		direction = signf(velocity.x)
	player.health.take_damage(damage, Vector2(direction * knockback_force, 0.0), direction)

func _explode() -> void:
	if exploded:
		return
	exploded = true
	can_move = false
	lifetime_timer.stop()
	hitbox.set_deferred("monitoring", false)
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	animated_sprite.play("explode")

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"explode":
		queue_free()

func _on_lifetime_timeout() -> void:
	if not exploded:
		queue_free()
