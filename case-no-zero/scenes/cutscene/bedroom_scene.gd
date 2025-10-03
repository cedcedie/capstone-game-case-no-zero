extends Node

# References to key nodes
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var dialogue_runner: Node = $RoundedYarnSpinnerCanvasLayer/DialogueRunner
@onready var player: Node = $PlayerM  # Adjust path if needed
@onready var dialogue_runner: Node = $RoundedYarnSpinnerCanvasLayer/DialogueRunner


# --- Player control helpers ---
func disable_control():
	if player:
		player.control_enabled = false

func enable_control():
	if player:
		player.control_enabled = true

# --- Called by AnimationPlayer Call Method Track ---
func start_dialogue():
	# Pause the current cutscene animation
	anim_player.pause()
	
	# Start the dialogue from the Start Node set in DialogueRunner Inspector
	dialogue_runner.start_node("Intro")

# --- DialogueRunner signals ---
func _on_dialogue_runner_on_dialogue_start() -> void:
	print("Dialogue started")
	disable_control()

func _on_dialogue_runner_on_dialogue_complete() -> void:
	print("Dialogue finished")
	enable_control()
	anim_player.play()  # Resume the animation

func _on_dialogue_runner_on_node_start(nodeName: String) -> void:
	print("Dialogue node started:", nodeName)

func _on_dialogue_runner_on_node_complete(nodeName: String) -> void:
	print("Dialogue node completed:", nodeName)

func _on_dialogue_runner_on_unhandled_command(commandText: String) -> void:
	print("Unhandled command:", commandText)

func _ready():
	# Connect DialogueRunner signals to this node
	dialogue_runner.onDialogueStart.connect(_on_dialogue_runner_on_dialogue_start)
	dialogue_runner.onDialogueComplete.connect(_on_dialogue_runner_on_dialogue_complete)
	dialogue_runner.onNodeStart.connect(_on_dialogue_runner_on_node_start)
	dialogue_runner.onNodeComplete.connect(_on_dialogue_runner_on_node_complete)
	dialogue_runner.onUnhandledCommand.connect(_on_dialogue_runner_on_unhandled_command)
	
func _on_dialogue_runner_ready() -> void:
	print("DialogueRunner is ready")
