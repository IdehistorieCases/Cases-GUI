extends Node3D

const CHARACTER_PATHS := [
    "res://assets/characters/cases_suited_negotiator.glb",
    "res://assets/characters/cases_suited_negotiator_senior_mediator.glb",
    "res://assets/characters/cases_suited_negotiator_younger_envoy.glb",
    "res://assets/characters/cases_suited_negotiator_scholarly_delegate.glb",
]
const CHARACTER_LABELS := ["LEGACY DEFAULT", "SENIOR MEDIATOR", "YOUNGER ENVOY", "SCHOLARLY DELEGATE"]
const X_POSITIONS := [-1.80, -0.60, 0.60, 1.80]

func _ready() -> void:
    get_window().size = Vector2i(1920, 1080)
    _setup_world()
    for index in range(CHARACTER_PATHS.size()):
        var packed := load(CHARACTER_PATHS[index]) as PackedScene
        if packed == null:
            push_error("Could not load comparison GLB: " + CHARACTER_PATHS[index])
            continue
        var actor := packed.instantiate() as Node3D
        actor.name = CHARACTER_LABELS[index].to_pascal_case()
        actor.position = Vector3(X_POSITIONS[index], 0.0, 0.0)
        actor.scale = Vector3.ONE * 0.88
        add_child(actor)
        var player := _find_player(actor)
        if player == null or not player.has_animation("SeatedIdle"):
            push_error("Godot lineup asset has no SeatedIdle animation: " + CHARACTER_PATHS[index])
        else:
            player.play("SeatedIdle")
        _add_label(CHARACTER_LABELS[index], Vector3(X_POSITIONS[index], 1.82, 0.0))
    _add_ground()

func _setup_world() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.12, 0.15, 0.19)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.68, 0.72, 0.78)
    environment.ambient_light_energy = 0.45
    world.environment = environment
    add_child(world)

    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 1.9, 7.8)
    camera.fov = 22.0
    camera.current = true
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-36.0, 18.0, 0.0)
    key.light_color = Color(1.0, 0.92, 0.82)
    key.light_energy = 0.85
    key.shadow_enabled = true
    add_child(key)


func _add_ground() -> void:
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(14.0, 12.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.22, 0.24, 0.27)
    material.roughness = 0.9
    mesh.material = material
    var ground := MeshInstance3D.new()
    ground.mesh = mesh
    ground.position = Vector3(0.0, -0.06, 0.0)
    add_child(ground)

func _add_label(text: String, position: Vector3) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = position
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 28
    label.pixel_size = 0.0025
    label.outline_size = 6
    label.modulate = Color(1.0, 0.92, 0.76)
    label.no_depth_test = true
    add_child(label)

func _find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_player(child)
        if found != null:
            return found
    return null
