# multiplayer.gd
extends Node

@export var player_scene : PackedScene

func _ready():
	# Start paused.
	# get_tree().paused = true
	# You can save bandwidth by disabling server relay and peer notifications.
	# multiplayer.server_relay = false

	# Automatically start the server in headless mode.
	if DisplayServer.get_name() == "headless":
		print("Automatically starting dedicated server.")
		_on_host_pressed.call_deferred()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)



func _on_peer_connected(id):
	print("Peer connected: ", id)
func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)
func _connected_to_server():
	print("Connected to server.")

const PLAYER_COLORS = [
	Color.BLUE,
	Color.RED,
	Color.GREEN,
	Color.YELLOW,
]


func _on_host_pressed():
	# Start as server.
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(int($Control/Net/Host/Port.text))
	# if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
	# 	OS.alert("Failed to start multiplayer server.")
	# 	return
	multiplayer.multiplayer_peer = peer
	print("Server started.")
	get_window().title = "Server"
	start_game()
	multiplayer.peer_connected.connect(_add_player)
	_add_player()

func _add_player(id = 1):
	var player: Player = player_scene.instantiate()
	player.name = str(id)

	print("adding: " + str(multiplayer.get_peers().size()))
	player.player_color = PLAYER_COLORS[multiplayer.get_peers().size()]

	$Node3D/Players.add_child(player)
	player.spawn.rpc()


func _on_connect_pressed():
	# Start as client.
	var txt : String = $Control/Net/Connect/Remote.text
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(txt, int($Control/Net/Host/Port.text))
	multiplayer.multiplayer_peer = peer
	print("Client started.")
	get_window().title = "Client"
	start_game()


func start_game():
	# Hide the UI and unpause to start the game.
	$Control.hide()
	# get_tree().paused = false	
