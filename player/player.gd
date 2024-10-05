extends CharacterBody3D
class_name Player

const JUMP_VELOCITY = 6.5

const MOUSE_SENSITIVITY = 0.001

@export var player_color: Color = Color.WHITE

@onready var player_raycast = $Head/Camera3D/PlayerHitCast
@onready var decal_raycast = $Head/Camera3D/DecalHitCast


@export var health = 100

@export var decal_instance: PackedScene

var spawn_cooldown = 0

func die_local():
	die.rpc()
	spawn_cooldown = 3

@rpc("any_peer", "reliable", "call_local")
func die():
	visible = false

@rpc("any_peer", "reliable", "call_local")
func spawn():
	var spawn_point = get_tree().get_nodes_in_group("PlayerSpawn").pick_random()
	transform.origin = spawn_point.transform.origin
	visible = true
	health = 100


var peer_id = 0

func _ready():
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id)


	# Set the player's player_color.
	$VisualBody/Pill.material_override = StandardMaterial3D.new()
	$VisualBody/Pill.material_override.albedo_color = player_color

	if (is_multiplayer_authority()):
		# Set the camera to the player's head.
		$Head/Camera3D.current = true
		$VisualBody.visible = false

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# $PlayerHUD.show()
	else:
		# Disable the camera for other players.
		$Head/Camera3D.current = false
		$VisualBody.visible = true
		$Hud.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if health <= 0:
		return
	if event is InputEventMouseMotion:
		if is_multiplayer_authority():
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			$Head.rotation.x = clamp($Head.rotation.x -event.relative.y * MOUSE_SENSITIVITY, -PI / 2, PI / 2)

@onready var shot_sound_player: AudioStreamPlayer3D = $Head/ShotSound

# Function to play sound
@rpc("any_peer", "reliable", "call_local")
func on_shot():
	print("boom")
	shot_sound_player.play()

# spawn decal
# @rpc("any_peer", "reliable", "call_local")
# func spawn_decal(hit_pos: Vector3, hit_normal: Vector3):
# 	var decal: Decal = decal_instance.instantiate()
# 	decal.transform.origin = hit_pos
# 	get_tree().root.add_child(decal)
# 	decal.look_at(hit_pos + hit_normal, Vector3.UP)
# 	print("decal")

@rpc("any_peer", "reliable", "call_local")
func on_hit_me(by_peer_id: int):
	print("I " + str(peer_id) + " was hit " + str(by_peer_id))
	health -= 100
	if health <= 0:
		die_local()

func shoot():
	on_shot.rpc()

	if (player_raycast.is_colliding()):
		print("hit player")
		if decal_raycast.is_colliding() and decal_raycast.get_collision_point().distance_to(transform.origin) + 2 < player_raycast.get_collision_point().distance_to(transform.origin):
			# we hit a wall first
			print("hit wall first")
			print("wall: ", decal_raycast.get_collider())
			pass
		else:
			print("Raycast hit: ", player_raycast.get_collider())
			var hit_collider: Area3D = player_raycast.get_collider()
			var hit_player: Player = hit_collider.get_parent()
			if hit_player:
				print ("I " + str(peer_id) + " hit " + str(hit_player.peer_id))
				hit_player.on_hit_me.rpc_id(hit_player.peer_id, peer_id)
	print("missed")

@onready var head_bobbing_anim_tree = $Head/AnimationTree

func h_vec(v: Vector3):
	var h = v
	h.y = 0
	return h

var target_head_nudge: float = 0.0

func _process(delta):
	$Head.rotation.z = lerp($Head.rotation.z, float(target_head_nudge), 7 * delta)

var cayote_time = 0
var cayote_time_wall = 0
var bhob_window = 0
var bhob_speed = 0
var wall_jump_cooldown = 0

var shoot_cooldown = 0
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if (spawn_cooldown > 0):
		spawn_cooldown -= delta
		$Hud/Stats.text = "Respawning in " + str(snapped(spawn_cooldown, .01))
		if (spawn_cooldown <= 0):
			spawn.rpc()
		return

	shoot_cooldown -= delta
	if (Input.is_action_just_pressed("fire") and shoot_cooldown <= 0):
		shoot()
		shoot_cooldown = 1

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Cayote
	if is_on_floor():
		cayote_time = 0.2
		bhob_window -= delta
		if bhob_window <= 0:
			bhob_speed = 0
		wall_jump_cooldown = 0
	else:
		cayote_time -= delta
		bhob_window = 0.1
		bhob_speed = min(max(h_vec(velocity).length(), bhob_speed), 35)
	var can_jump = cayote_time > 0
	var can_bhop = bhob_window > 0

	if is_on_wall():
		cayote_time_wall = 0.2
	else:
		cayote_time_wall -= delta
		wall_jump_cooldown -= delta
	var can_wall_jump = cayote_time_wall > 0 and wall_jump_cooldown <= 0

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var basis_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_velocity := basis_dir * 5

	# Apply the movement.
	if (is_on_floor()):
		velocity.x = lerp(velocity.x, target_velocity.x, 40 * delta)
		velocity.z = lerp(velocity.z, target_velocity.z, 40 * delta)
	else:
		if (basis_dir.length() > 0.1):
			var target_air_velocity = basis_dir * max(h_vec(velocity).length(), 5)
			velocity.x = lerp(velocity.x, target_air_velocity.x, 40 * delta)
			velocity.z = lerp(velocity.z, target_air_velocity.z, 40 * delta)

	if can_wall_jump and not can_jump:
		# tilt the head slighty along its z axis to make it look like the player is sliding on the wall
		# make sure to use the wall normal to get the correct direction
		var angle = get_wall_normal().angle_to(transform.basis.y) * .07 # this is absolute value
		var side = transform.basis * Vector3(1, 0, 0)
		var intensity = side.normalized().dot(get_wall_normal().normalized())

		target_head_nudge = angle * -intensity
	else:
		target_head_nudge = 0

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if can_jump:
			cayote_time = 0
			velocity.y = JUMP_VELOCITY
			if can_bhop:
				var target_post_jump_velocity = basis_dir * bhob_speed * 1.1
				velocity.x = target_post_jump_velocity.x
				velocity.z = target_post_jump_velocity.z
		elif can_wall_jump:
			wall_jump_cooldown = 0.4
			cayote_time_wall = 0
			var wall_normal = get_wall_normal().normalized()

			var vertical_velocity = Vector3(0, JUMP_VELOCITY * 1.4, 0)

			var wall_push = wall_normal * 15

			var hop_velocity = basis_dir * bhob_speed

			velocity += wall_push + hop_velocity
			velocity.y = vertical_velocity.y

	# head bobbing
	if is_on_floor():
		# get the velocity without the y component
		var h_velocity = velocity
		h_velocity.y = 0
		var speed = h_velocity.length()
		head_bobbing_anim_tree.set("parameters/bob_speed/scale", speed * .35)
		head_bobbing_anim_tree.set("parameters/bob_trans/transition_request", "bob" if speed > 0.1 else "idle")
	else:
		head_bobbing_anim_tree.set("parameters/bob_trans/transition_request", "idle")


	move_and_slide()

	$Hud/Stats.text = "Speed: " + str( snapped(h_vec(velocity).length(), .01)) + "\n" + "Bhob-Speed: " + str(snapped(bhob_speed, .01) if can_bhop else "-") + "\n" + "Health: " + str(health)
