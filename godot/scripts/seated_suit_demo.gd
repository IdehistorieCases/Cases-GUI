extends Node3D
## CASES: initial reusable negotiator prototype.
## Press 1 for seated idle, 2 for seated speaking, 3 to toggle pause.

const CHARACTER = preload("res://assets/characters/cases_suited_negotiator.glb")
var _actor: Node3D
var _player: AnimationPlayer
var _state_label: Label
var _current_clip: String = ""

func _ready() -> void:
    _actor = CHARACTER.instantiate() as Node3D
    add_child(_actor)
    _player = _find_animation_player(_actor)
    _setup_environment()
    _setup_gui()
    if _player == null:
        push_error("CASES: Imported GLB has no AnimationPlayer")
        _state_label.text = "ERROR — AnimationPlayer missing"
        return
    print("CASES loaded animations: ", _player.get_animation_list())
    set_animation("SeatedIdle")

func set_animation(name: String) -> void:
    if _player == null:
        return
    if not _player.has_animation(name):
        push_error("CASES: Missing clip " + name)
        return
    if _current_clip == name:
        return
    _player.play(name, 0.3)
    _current_clip = name
    _state_label.text = "CASES  |  " + name + "  |  1 = idle   2 = talk   3 = pause"

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_1:
            set_animation("SeatedIdle")
        elif event.keycode == KEY_2:
            set_animation("SeatedTalking")
        elif event.keycode == KEY_3 and _player != null:
            if _player.is_playing():
                _player.pause()
            else:
                _player.play()

func _find_animation_player(n: Node) -> AnimationPlayer:
    if n is AnimationPlayer:
        return n as AnimationPlayer
    for child in n.get_children():
        var result: AnimationPlayer = _find_animation_player(child)
        if result != null:
            return result
    return null

func _setup_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.18, 0.20, 0.23)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.80, 0.81, 0.86)
    env.ambient_light_energy = 0.65
    world.environment = env
    add_child(world)

    var camera := Camera3D.new()
    camera.position = Vector3(1.8, 1.5, 2.85)
    camera.fov = 43.0
    camera.current = true
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.86, 0.0), Vector3.UP)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-48, 28, 0)
    light.light_color = Color(1.0, 0.92, 0.78)
    light.light_energy = 1.2
    light.shadow_enabled = true
    add_child(light)

    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(10,10)
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color(0.29, 0.31, 0.34)
    floor_material.roughness = 0.9
    floor_mesh.material = floor_material
    var floor_node := MeshInstance3D.new()
    floor_node.mesh = floor_mesh
    floor_node.position.y = -0.05
    add_child(floor_node)

func _setup_gui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    _state_label = Label.new()
    _state_label.text = "Loading CASES character..."
    _state_label.add_theme_font_size_override("font_size", 22)
    _state_label.position = Vector2(18, 16)
    ui.add_child(_state_label)
