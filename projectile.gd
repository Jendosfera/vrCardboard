extends Area3D

@export var speed: float = 30.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

func _ready():
	# Подключаем сигнал столкновения с телами (стенами, врагами)
	body_entered.connect(_on_body_entered)
	# Удаляем снаряд через lifetime секунд, чтобы не засорять память
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Летим вперед по локальной оси -Z
	position -= transform.basis.z * speed * delta

func _on_body_entered(body):
	# Игнорируем самого игрока
	if body.name == "Player":
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
