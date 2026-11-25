@tool
extends Node3D
## Builds one participant place setting around the table for each seat.

const CHAIR_SCENE: PackedScene = preload("res://assets/versailles/optimized/polyhaven/green_chair_01.glb")
const PARTICIPANT_PREFIX := "Participant_"
const LEGACY_CHAIR_PREFIX := "GeneratedChair_"
const MAX_PARTICIPANTS := 12
const MIN_CHAIR_RADIUS := 1.5
const DEFAULT_COUNTRIES := ["France", "United Kingdom", "United States", "Italy", "Japan", "Belgium"]
const TABLE_SURFACE_Y := 0.854
const PAPER_CENTER_RADIUS := 0.78
const PAPER_CENTER_Y := 0.86
const PAPER_SIZE := Vector3(0.30, 0.008, 0.38)
const FLAG_CENTER_RADIUS := 1.07
const FLAG_WIDTH := 0.20
const FLAG_HEIGHT := 0.13
const FLAG_CLOTH_CENTER_Y := 0.245

var _rebuilding := false
var _material_cache: Dictionary = {}

## Backward-compatible storage for scenes that used chair_count before participant_count.
@export_storage var chair_count: int = 6:
	set(value):
		chair_count = clampi(value, 0, MAX_PARTICIPANTS)
		if participant_count != chair_count:
			participant_count = chair_count

## Number of participant places. Every place gets a chair, country flag, and treaty paper.
@export_range(0, 12, 1) var participant_count: int = 6:
	set(value):
		participant_count = clampi(value, 0, MAX_PARTICIPANTS)
		chair_count = participant_count
		_rebuild_if_ready()

## Countries in seat order, starting north and moving clockwise. Supported names include France, United Kingdom/UK, United States/USA, Italy, Japan, Belgium, Poland, Romania, China/China (1912-1928), Portugal (1911), Germany/German Empire (June 1919), and Greece. Unknown names use France.
@export var participant_countries: PackedStringArray = PackedStringArray([
	"France", "United Kingdom", "United States", "Italy", "Japan", "Belgium"
]):
	set(value):
		participant_countries = value
		_rebuild_if_ready()

## Distance from the table center to each participant's chair origin.
@export_range(1.5, 3.5, 0.01) var chair_radius: float = 1.7:
	set(value):
		chair_radius = clampf(value, MIN_CHAIR_RADIUS, 3.5)
		_rebuild_if_ready()


func _ready() -> void:
	_rebuild_participants()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_rebuild_participants()


func _rebuild_participants() -> void:
	if not is_inside_tree() or _rebuilding:
		return

	_rebuilding = true
	for child in get_children():
		var child_name := str(child.name)
		if child_name.begins_with(PARTICIPANT_PREFIX) or child_name.begins_with(LEGACY_CHAIR_PREFIX):
			remove_child(child)
			child.free()

	for index in range(participant_count):
		var angle: float = TAU * float(index) / float(participant_count)
		var participant := Node3D.new()
		participant.name = "%s%02d" % [PARTICIPANT_PREFIX, index + 1]
		participant.position = Vector3(sin(angle) * chair_radius, 0.0, cos(angle) * chair_radius)
		participant.rotation.y = angle + PI
		participant.add_to_group("room_participants")
		add_child(participant)

		var chair := CHAIR_SCENE.instantiate() as Node3D
		if chair == null:
			push_error("NegotiationSeating: the chair scene root must be a Node3D")
			continue
		chair.name = "Chair"
		participant.add_child(chair)

		_add_treaty_paper(participant)
		_add_table_flag(participant, _country_for(index))

	_rebuilding = false


func _country_for(index: int) -> String:
	if index < participant_countries.size():
		var country := participant_countries[index].strip_edges()
		if not country.is_empty():
			return country
	return DEFAULT_COUNTRIES[index % DEFAULT_COUNTRIES.size()]


func _add_treaty_paper(participant: Node3D) -> void:
	var paper := Node3D.new()
	paper.name = "TreatyPaper"
	paper.position = Vector3(0.0, PAPER_CENTER_Y, chair_radius - PAPER_CENTER_RADIUS)
	participant.add_child(paper)

	_add_box(
		paper,
		"Parchment",
		PAPER_SIZE,
		Vector3.ZERO,
		_color_material(Color8(235, 221, 186), 0.96)
	)

	var ink := _color_material(Color8(83, 55, 34), 0.92)
	for line_index in range(5):
		var line_length := 0.20 if line_index < 3 else 0.14
		var line_z := 0.105 - float(line_index) * 0.038
		_add_box(
			paper,
			"InkLine_%02d" % (line_index + 1),
			Vector3(line_length, 0.0015, 0.003),
			Vector3(-0.005, 0.0055, line_z),
			ink
		)

	_add_cylinder(
		paper,
		"WaxSeal",
		0.016,
		0.003,
		Vector3(0.095, 0.007, 0.125),
		_color_material(Color8(124, 37, 39), 0.72),
		16
	)


func _add_table_flag(participant: Node3D, country: String) -> void:
	var flag := Node3D.new()
	flag.name = "TableFlag_%s" % _safe_node_name(country)
	flag.position = Vector3(0.0, TABLE_SURFACE_Y, chair_radius - FLAG_CENTER_RADIUS)
	participant.add_child(flag)

	_add_cylinder(
		flag,
		"BrassFlagBase",
		0.043,
		0.018,
		Vector3(0.0, 0.009, 0.0),
		_color_material(Color8(161, 116, 46), 0.34),
		20,
		0.032
	)
	_add_cylinder(
		flag,
		"FlagPole",
		0.006,
		0.33,
		Vector3(0.0, 0.174, 0.0),
		_color_material(Color8(183, 139, 60), 0.32),
		12
	)
	_add_sphere(
		flag,
		"FlagPoleFinial",
		0.012,
		Vector3(0.0, 0.343, 0.0),
		_color_material(Color8(198, 153, 69), 0.30)
	)

	_add_flag_quad(
		flag,
		"FlagEdge",
		Vector2(FLAG_WIDTH + 0.004, FLAG_HEIGHT + 0.004),
		Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.0),
		Color8(47, 37, 27)
	)
	var style := _flag_style(country)
	match style.get("kind", "stripes"):
		"union_jack":
			_add_union_jack(flag)
		"us48":
			_add_us48_flag(flag)
		"japan":
			_add_striped_flag(flag, "horizontal", [Color8(255, 255, 255)])
			_add_disc(flag, "Hinomaru", Color8(188, 0, 45), 0.030, Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.006))
		"italy":
			_add_striped_flag(flag, "vertical", [Color8(0, 119, 73), Color8(255, 255, 255), Color8(206, 43, 55)])
			_add_savoy_shield(flag)
		"stripes":
			_add_striped_flag(flag, str(style.get("layout", "vertical")), style.get("colors", []))
		_:
			_add_striped_flag(flag, "vertical", [Color8(0, 85, 164), Color8(255, 255, 255), Color8(239, 65, 53)])


func _flag_style(country: String) -> Dictionary:
	match country:
		"France":
			return {"kind": "stripes", "layout": "vertical", "colors": [Color8(0, 85, 164), Color8(255, 255, 255), Color8(239, 65, 53)]}
		"United Kingdom", "UK", "Great Britain":
			return {"kind": "union_jack"}
		"United States", "United States of America", "USA", "US":
			return {"kind": "us48"}
		"Italy":
			return {"kind": "italy"}
		"Japan":
			return {"kind": "japan"}
		"Belgium":
			return {"kind": "stripes", "layout": "vertical", "colors": [Color8(25, 25, 25), Color8(250, 218, 55), Color8(239, 60, 53)]}
		"Poland":
			return {"kind": "stripes", "layout": "horizontal", "colors": [Color8(255, 255, 255), Color8(220, 20, 60)]}
		"Romania":
			return {"kind": "stripes", "layout": "vertical", "colors": [Color8(0, 43, 127), Color8(252, 209, 22), Color8(206, 17, 38)]}
		"China", "China (1912-1928)", "Republic of China":
			return {"kind": "stripes", "layout": "horizontal", "colors": [Color8(222, 41, 16), Color8(255, 222, 0), Color8(0, 62, 126), Color8(255, 255, 255), Color8(0, 0, 0)]}
		"Portugal (1911)":
			return {"kind": "stripes", "layout": "vertical", "colors": [Color8(0, 102, 0), Color8(255, 0, 0)]}
		"Germany", "German Empire", "German Empire (June 1919)":
			return {"kind": "stripes", "layout": "horizontal", "colors": [Color8(0, 0, 0), Color8(255, 255, 255), Color8(221, 0, 0)]}
		"Greece":
			return {"kind": "stripes", "layout": "horizontal", "colors": [Color8(13, 94, 175), Color8(255, 255, 255), Color8(13, 94, 175), Color8(255, 255, 255), Color8(13, 94, 175), Color8(255, 255, 255), Color8(13, 94, 175), Color8(255, 255, 255), Color8(13, 94, 175)]}
		_:
			push_warning("NegotiationSeating: unsupported flag country '%s'; using France." % country)
			return {"kind": "stripes", "layout": "vertical", "colors": [Color8(0, 85, 164), Color8(255, 255, 255), Color8(239, 65, 53)]}


func _add_striped_flag(flag: Node3D, layout: String, colors: Array) -> void:
	if colors.is_empty():
		return
	if layout == "horizontal":
		var stripe_height := FLAG_HEIGHT / float(colors.size())
		for index in range(colors.size()):
			var center_y := FLAG_CLOTH_CENTER_Y + FLAG_HEIGHT * 0.5 - stripe_height * (float(index) + 0.5)
			_add_flag_quad(
				flag,
				"Stripe_%02d" % (index + 1),
				Vector2(FLAG_WIDTH, stripe_height),
				Vector3(FLAG_WIDTH * 0.5, center_y, 0.003),
				colors[index]
			)
	else:
		var stripe_width := FLAG_WIDTH / float(colors.size())
		for index in range(colors.size()):
			_add_flag_quad(
				flag,
				"Stripe_%02d" % (index + 1),
				Vector2(stripe_width, FLAG_HEIGHT),
				Vector3(stripe_width * (float(index) + 0.5), FLAG_CLOTH_CENTER_Y, 0.003),
				colors[index]
			)


func _add_union_jack(flag: Node3D) -> void:
	_add_flag_quad(flag, "UnionBlueField", Vector2(FLAG_WIDTH, FLAG_HEIGHT), Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.003), Color8(1, 33, 105))
	var diagonal_length := sqrt(FLAG_WIDTH * FLAG_WIDTH + FLAG_HEIGHT * FLAG_HEIGHT) - 0.022
	var diagonal_angle := atan2(FLAG_HEIGHT, FLAG_WIDTH)
	_add_flag_bar(flag, "WhiteSaltireA", Vector2(diagonal_length, 0.026), diagonal_angle, 0.005, Color8(255, 255, 255))
	_add_flag_bar(flag, "WhiteSaltireB", Vector2(diagonal_length, 0.026), -diagonal_angle, 0.005, Color8(255, 255, 255))
	_add_flag_bar(flag, "RedSaltireA", Vector2(diagonal_length, 0.011), diagonal_angle, 0.007, Color8(200, 16, 46))
	_add_flag_bar(flag, "RedSaltireB", Vector2(diagonal_length, 0.011), -diagonal_angle, 0.007, Color8(200, 16, 46))
	_add_flag_quad(flag, "WhiteCrossVertical", Vector2(0.038, FLAG_HEIGHT), Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.009), Color8(255, 255, 255))
	_add_flag_quad(flag, "WhiteCrossHorizontal", Vector2(FLAG_WIDTH, 0.036), Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.009), Color8(255, 255, 255))
	_add_flag_quad(flag, "RedCrossVertical", Vector2(0.019, FLAG_HEIGHT), Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.011), Color8(200, 16, 46))
	_add_flag_quad(flag, "RedCrossHorizontal", Vector2(FLAG_WIDTH, 0.017), Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.011), Color8(200, 16, 46))


func _add_us48_flag(flag: Node3D) -> void:
	var stripes: Array = []
	for index in range(13):
		stripes.append(Color8(191, 10, 48) if index % 2 == 0 else Color8(255, 255, 255))
	_add_striped_flag(flag, "horizontal", stripes)
	var canton_width := FLAG_WIDTH * 0.42
	var canton_height := FLAG_HEIGHT * 0.54
	var canton_center_y := FLAG_CLOTH_CENTER_Y + FLAG_HEIGHT * 0.5 - canton_height * 0.5
	_add_flag_quad(flag, "BlueCanton", Vector2(canton_width, canton_height), Vector3(canton_width * 0.5, canton_center_y, 0.005), Color8(0, 40, 104))
	_add_us48_star_field(flag, canton_width, canton_height, canton_center_y)


func _add_us48_star_field(flag: Node3D, canton_width: float, canton_height: float, canton_center_y: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var columns := 8
	var rows := 6
	var star_radius := minf(canton_width / float(columns), canton_height / float(rows)) * 0.36
	for row in range(rows):
		for column in range(columns):
			var center_x := canton_width * (float(column) + 0.5) / float(columns)
			var center_y := canton_center_y + canton_height * 0.5 - canton_height * (float(row) + 0.5) / float(rows)
			var base_index := vertices.size()
			vertices.append(Vector3(center_x, center_y, 0.008))
			normals.append(Vector3(0.0, 0.0, 1.0))
			for point in range(10):
				var point_angle := -PI * 0.5 + float(point) * PI / 5.0
				var point_radius := star_radius if point % 2 == 0 else star_radius * 0.43
				vertices.append(Vector3(center_x + cos(point_angle) * point_radius, center_y + sin(point_angle) * point_radius, 0.008))
				normals.append(Vector3(0.0, 0.0, 1.0))
			for point in range(10):
				indices.append(base_index)
				indices.append(base_index + 1 + point)
				indices.append(base_index + 1 + ((point + 1) % 10))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var star_mesh := ArrayMesh.new()
	star_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var stars := MeshInstance3D.new()
	stars.name = "48Stars"
	stars.mesh = star_mesh
	stars.material_override = _color_material(Color8(255, 255, 255), 0.88)
	flag.add_child(stars)


func _add_savoy_shield(flag: Node3D) -> void:
	var center := Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, 0.006)
	_add_flag_quad(flag, "SavoyShieldBorder", Vector2(0.040, 0.052), center, Color8(205, 168, 88))
	_add_flag_quad(flag, "SavoyShield", Vector2(0.033, 0.045), Vector3(center.x, center.y, 0.008), Color8(196, 24, 38))
	_add_flag_quad(flag, "SavoyCrossVertical", Vector2(0.008, 0.040), Vector3(center.x, center.y, 0.010), Color8(255, 255, 255))
	_add_flag_quad(flag, "SavoyCrossHorizontal", Vector2(0.028, 0.008), Vector3(center.x, center.y, 0.010), Color8(255, 255, 255))


func _add_disc(flag: Node3D, node_name: String, color: Color, radius: float, position: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.002
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _color_material(color, 0.9)
	instance.position = position
	instance.rotation.x = PI * 0.5
	flag.add_child(instance)


func _add_flag_bar(flag: Node3D, node_name: String, size: Vector2, angle: float, z: float, color: Color) -> void:
	var bar := _add_flag_quad(flag, node_name, size, Vector3(FLAG_WIDTH * 0.5, FLAG_CLOTH_CENTER_Y, z), color)
	bar.rotation.z = angle


func _add_flag_quad(flag: Node3D, node_name: String, size: Vector2, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _color_material(color, 0.88)
	instance.position = position
	flag.add_child(instance)
	return instance


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: StandardMaterial3D, radial_segments: int = 16, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _color_material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(false), roughness]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = material
	return material


func _safe_node_name(value: String) -> String:
	var result := value.replace(" ", "_").replace("(", "").replace(")", "").replace("-", "_")
	return result
