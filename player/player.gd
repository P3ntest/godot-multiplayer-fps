extends CharacterBody3D
class_name Player

const JUMP_VELOCITY = 6.5

const MOUSE_SENSITIVITY = 0.001

@export var player_color: Color = Color.WHITE

@onready var raycast = $Head/Camera3D/RayCast3D

@export var health = 100

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_multiplayer_authority():
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			$Head.rotation.x = clamp($Head.rotation.x -event.relative.y * MOUSE_SENSITIVITY, -PI / 2, PI / 2)

@rpc("any_peer", "reliable", "call_local")
func on_shot():
	print("boom")

@rpc("any_peer", "reliable", "call_local")
func on_hit_me(by_peer_id: int):
	print("I " + str(peer_id) + " was hit " + str(by_peer_id))
	health -= 20

func shoot():
	on_shot.rpc()

	if (raycast.is_colliding()):
		print("Raycast hit: ", raycast.get_collider())
		var hit_collider: Area3D = raycast.get_collider()
		var hit_player: Player = hit_collider.get_parent()
		if hit_player:
			print ("I " + str(peer_id) + " hit " + str(hit_player.peer_id))
			hit_player.on_hit_me.rpc_id(hit_player.peer_id, peer_id)

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
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if (Input.is_action_just_pressed("fire")):
		shoot()

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

	$Stats.text = "Speed: " + str( snapped(h_vec(velocity).length(), .01)) + "\n" + "Bhob-Speed: " + str(snapped(bhob_speed, .01) if can_bhop else "-") + "\n"