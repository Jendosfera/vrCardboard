extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@onready var xr_origin = $XROrigin3D
@onready var vr_camera = $XROrigin3D/XRCamera3D
@onready var interact_ray = $XROrigin3D/XRCamera3D/RayCast3D
@onready var muzzle = $XROrigin3D/XRCamera3D/Muzzle

@export var bullet_scene: PackedScene
@export var magic_scene: PackedScene

# Параметры пулемета и магии
@export var fire_rate: float = 0.1 # Выстрел каждые 0.1 сек (10 в секунду)
@export var max_mana: float = 100.0
@export var mana_cost: float = 25.0
@export var mana_regen: float = 10.0 # Восстановление в секунду

var current_mana: float = 100.0
var fire_cooldown: float = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var vr_enabled = false

func _ready():
	var xr_interface = XRServer.find_interface("Native mobile")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
		vr_enabled = true
		xr_interface.eye_height = 0.0 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if not vr_enabled and event is InputEventMouseMotion:
		xr_origin.rotate_y(-event.relative.x * mouse_sensitivity)
		vr_camera.rotate_x(-event.relative.y * mouse_sensitivity)
		vr_camera.rotation.x = clamp(vr_camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis = vr_camera.global_transform.basis
	var forward = cam_basis.z
	var right = cam_basis.x
	forward.y = 0
	right.y = 0
	
	var direction = (forward.normalized() * input_dir.y + right.normalized() * input_dir.x).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func _process(delta):
	# Таймер скорострельности и регенерация маны
	if fire_cooldown > 0:
		fire_cooldown -= delta
	if current_mana < max_mana:
		current_mana = min(max_mana, current_mana + mana_regen * delta)

	# Пулемет: стреляет пока ЗАЖАТА кнопка (is_action_pressed)
	if Input.is_action_pressed("shoot") and fire_cooldown <= 0:
		cast_projectile(bullet_scene)
		fire_cooldown = fire_rate
		
	# Магия: одиночный залп по нажатию, если хватает маны
	if Input.is_action_just_pressed("cast_magic"):
		if current_mana >= mana_cost:
			current_mana -= mana_cost
			cast_projectile(magic_scene)
			print("Каст магии! Осталось маны: ", int(current_mana))
		else:
			print("Недостаточно маны!")
		
	if Input.is_action_just_pressed("interact"):
		check_interaction()

func cast_projectile(projectile_scene: PackedScene):
	if projectile_scene == null:
		return
	var proj = projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_transform = muzzle.global_transform
	
	# Разворачиваем снаряд точно в точку, куда смотрит прицел в центре экрана
	var target_point = vr_camera.global_position - vr_camera.global_transform.basis.z * 30.0
	if interact_ray.is_colliding():
		target_point = interact_ray.get_collision_point()
	proj.look_at(target_point, Vector3.UP)

func check_interaction():
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target.has_method("pick_up"):
			target.pick_up(self)
