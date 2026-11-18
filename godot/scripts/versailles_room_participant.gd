extends Node3D

## Starts the existing seated negotiator's idle animation in the room scene.
func _ready() -> void:
	var player := _find_animation_player(self)
	if player == null:
		push_error("Versailles participant has no AnimationPlayer")
		return
	if not player.has_animation("SeatedIdle"):
		push_error("Versailles participant is missing SeatedIdle")
		return
	player.play("SeatedIdle")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var player := _find_animation_player(child)
		if player != null:
			return player
	return null
