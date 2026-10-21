extends CharacterBody3D

# --- Movement Parameters ---
@export var walk_speed = 5.0
@export var gravity = 9.8

# --- Look & Feel Parameters ---
@export var mouse_sensitivity = 0.002

# --- Node References ---
@onready var head = $Head

# This function runs once when the game starts.
func _ready():
	# This hides our mouse cursor and keeps it locked to the game window.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
