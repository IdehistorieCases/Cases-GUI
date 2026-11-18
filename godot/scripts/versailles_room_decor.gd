@tool
extends Node3D
## Adds authored decorative detail to the otherwise reusable Versailles room.

const DECOR_ROOT_NAME := "Generated_RoomDecor"
const FLOOR_TOP := 0.065
const RUG_TOP := 0.078
const WALL_PLANE := 3.96

var _rebuilding := false
var _materials: Dictionary = {}


func _ready() -> void:
	_rebuild_decor()


func _rebuild_decor() -> void:
	if not is_inside_tree() or _rebuilding:
		return

	_rebuilding = true
	for child in get_children():
		if child.name == DECOR_ROOT_NAME:
			remove_child(child)
			child.free()

	var decor := Node3D.new()
	decor.name = DECOR_ROOT_NAME
	add_child(decor)
	_add_rug(decor)
	_add_gallery(decor)
	_add_wall_sconces(decor)
	_add_palms(decor)
	_add_archive_books(decor)
	_rebuilding = false


func _add_rug(parent: Node3D) -> void:
	var rug := Node3D.new()
	rug.name = "BurgundyRoomRug"
	parent.add_child(rug)

	var claret := _material("rug_claret", Color8(87, 25, 33), 0.96)
	var wine := _material("rug_wine", Color8(111, 37, 42), 0.96)
	var gold := _material("rug_gold", Color8(181, 137, 66), 0.78, 0.30)
	var faded_gold := _material("rug_faded_gold", Color8(151, 110, 59), 0.90, 0.12)
	var cream := _material("rug_cream", Color8(205, 179, 130), 0.94)

	_add_box(rug, "WovenCarpet", Vector3(6.25, 0.013, 6.25), Vector3(0.0, FLOOR_TOP + 0.0065, 0.0), claret)
	_add_box(rug, "OuterBorderNorth", Vector3(6.02, 0.004, 0.035), Vector3(0.0, RUG_TOP + 0.002, -2.98), gold)
	_add_box(rug, "OuterBorderSouth", Vector3(6.02, 0.004, 0.035), Vector3(0.0, RUG_TOP + 0.002, 2.98), gold)
	_add_box(rug, "OuterBorderEast", Vector3(0.035, 0.004, 6.02), Vector3(2.98, RUG_TOP + 0.002, 0.0), gold)
	_add_box(rug, "OuterBorderWest", Vector3(0.035, 0.004, 6.02), Vector3(-2.98, RUG_TOP + 0.002, 0.0), gold)
	_add_box(rug, "InnerBorderNorth", Vector3(5.72, 0.004, 0.018), Vector3(0.0, RUG_TOP + 0.003, -2.84), faded_gold)
	_add_box(rug, "InnerBorderSouth", Vector3(5.72, 0.004, 0.018), Vector3(0.0, RUG_TOP + 0.003, 2.84), faded_gold)
	_add_box(rug, "InnerBorderEast", Vector3(0.018, 0.004, 5.72), Vector3(2.84, RUG_TOP + 0.003, 0.0), faded_gold)
	_add_box(rug, "InnerBorderWest", Vector3(0.018, 0.004, 5.72), Vector3(-2.84, RUG_TOP + 0.003, 0.0), faded_gold)

	for index in range(13):
		var offset := -2.58 + float(index) * 0.43
		for side in [-1.0, 1.0]:
			var diamond_north := _add_box(
				rug,
				"BorderDiamond_N_%02d_%s" % [index, str(side)],
				Vector3(0.075, 0.005, 0.075),
				Vector3(offset, RUG_TOP + 0.004, side * 2.91),
				cream if index % 2 == 0 else gold
			)
			diamond_north.rotation.y = PI * 0.25
			var diamond_east := _add_box(
				rug,
				"BorderDiamond_E_%02d_%s" % [index, str(side)],
				Vector3(0.075, 0.005, 0.075),
				Vector3(side * 2.91, RUG_TOP + 0.004, offset),
				cream if index % 2 == 0 else gold
			)
			diamond_east.rotation.y = PI * 0.25

	for corner_x in [-2.37, 2.37]:
		for corner_z in [-2.37, 2.37]:
			var corner := _add_box(
				rug,
				"RugCornerMedallion",
				Vector3(0.34, 0.005, 0.34),
				Vector3(corner_x, RUG_TOP + 0.004, corner_z),
				wine
			)
			corner.rotation.y = PI * 0.25
			_add_box(rug, "RugCornerCenter", Vector3(0.11, 0.006, 0.11), Vector3(corner_x, RUG_TOP + 0.007, corner_z), gold)

	for diagonal in [-1.0, 1.0]:
		var center_ornament := _add_box(
				rug,
			"RugCenterScroll",
			Vector3(0.82, 0.004, 0.035),
			Vector3(0.0, RUG_TOP + 0.003, diagonal * 2.15),
			faded_gold
		)
		center_ornament.rotation.y = PI * 0.25


func _add_gallery(parent: Node3D) -> void:
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		var yaw := PI * 0.5 if side < 0.0 else -PI * 0.5
		for frame_index in range(2):
			var along_wall := -1.65 if frame_index == 0 else 1.65
			var frame := Node3D.new()
			frame.name = "LandscapeFrame_%02d_%02d" % [side_index + 1, frame_index + 1]
			frame.position = Vector3(side * WALL_PLANE, 2.76, along_wall)
			frame.rotation.y = yaw
			parent.add_child(frame)
			_add_landscape_frame(frame, side_index * 2 + frame_index)


func _add_landscape_frame(parent: Node3D, variant: int) -> void:
	var frame_width := 0.92
	var frame_height := 1.18
	var rail := 0.065
	var dark_wood := _material("art_wood", Color8(53, 34, 26), 0.43)
	var gold := _material("art_gold", Color8(177, 132, 59), 0.33, 0.46)
	var bright_gold := _material("art_highlight", Color8(213, 177, 102), 0.30, 0.52)

	_add_box(parent, "FrameShadowBacking", Vector3(frame_width, frame_height, 0.065), Vector3(0.0, 0.0, 0.035), dark_wood)
	_add_box(parent, "FrameTop", Vector3(frame_width, rail, 0.085), Vector3(0.0, frame_height * 0.5 - rail * 0.5, 0.065), gold)
	_add_box(parent, "FrameBottom", Vector3(frame_width, rail, 0.085), Vector3(0.0, -frame_height * 0.5 + rail * 0.5, 0.065), gold)
	_add_box(parent, "FrameLeft", Vector3(rail, frame_height - rail * 2.0, 0.085), Vector3(-frame_width * 0.5 + rail * 0.5, 0.0, 0.065), gold)
	_add_box(parent, "FrameRight", Vector3(rail, frame_height - rail * 2.0, 0.085), Vector3(frame_width * 0.5 - rail * 0.5, 0.0, 0.065), gold)
	_add_box(parent, "FrameInnerTop", Vector3(frame_width - rail * 2.2, 0.014, 0.016), Vector3(0.0, frame_height * 0.5 - rail - 0.018, 0.11), bright_gold)
	_add_box(parent, "FrameInnerBottom", Vector3(frame_width - rail * 2.2, 0.014, 0.016), Vector3(0.0, -frame_height * 0.5 + rail + 0.018, 0.11), bright_gold)
	_add_box(parent, "FrameInnerLeft", Vector3(0.014, frame_height - rail * 2.25, 0.016), Vector3(-frame_width * 0.5 + rail + 0.018, 0.0, 0.11), bright_gold)
	_add_box(parent, "FrameInnerRight", Vector3(0.014, frame_height - rail * 2.25, 0.016), Vector3(frame_width * 0.5 - rail - 0.018, 0.0, 0.11), bright_gold)

	var canvas_mesh := QuadMesh.new()
	canvas_mesh.size = Vector2(frame_width - rail * 2.45, frame_height - rail * 2.45)
	var canvas := MeshInstance3D.new()
	canvas.name = "PastoralLandscape_%02d" % variant
	canvas.mesh = canvas_mesh
	canvas.position = Vector3(0.0, 0.0, 0.091)
	canvas.material_override = _landscape_material(variant)
	parent.add_child(canvas)

	for corner_x in [-1.0, 1.0]:
		for corner_y in [-1.0, 1.0]:
			_add_sphere(
				parent,
				"GiltCornerRose",
				0.022,
				Vector3(corner_x * (frame_width * 0.5 - rail * 0.5), corner_y * (frame_height * 0.5 - rail * 0.5), 0.114),
				bright_gold
			)


func _landscape_material(variant: int) -> StandardMaterial3D:
	var image_width := 192
	var image_height := 288
	var image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	var palettes := [
		[Color8(113, 137, 148), Color8(215, 184, 137), Color8(88, 104, 82), Color8(44, 65, 53)],
		[Color8(121, 142, 149), Color8(227, 190, 145), Color8(112, 113, 77), Color8(52, 75, 54)],
		[Color8(106, 128, 144), Color8(207, 176, 135), Color8(83, 101, 89), Color8(35, 57, 55)],
		[Color8(137, 139, 135), Color8(223, 187, 137), Color8(105, 105, 73), Color8(50, 65, 49)]
	]
	var palette: Array = palettes[variant % palettes.size()]
	var sky_top: Color = palette[0]
	var sky_bottom: Color = palette[1]
	var distant_land: Color = palette[2]
	var foreground: Color = palette[3]
	var phase := float(variant) * 1.73

	for y in range(image_height):
		var v := float(y) / float(image_height - 1)
		for x in range(image_width):
			var u := float(x) / float(image_width - 1)
			var ridge := 0.40 + 0.035 * sin(u * TAU * 1.7 + phase) + 0.024 * sin(u * TAU * 4.1 + phase * 0.7)
			var hill := 0.55 + 0.045 * sin(u * TAU * 1.15 + phase * 0.8) + 0.022 * sin(u * TAU * 3.7 + phase)
			var field := 0.74 + 0.035 * sin(u * TAU * 1.35 + phase * 1.1)
			var color := sky_top.lerp(sky_bottom, clampf(v / 0.54, 0.0, 1.0))
			if v >= ridge and v < hill:
				color = distant_land.lightened(0.12)
			elif v >= hill and v < field:
				color = distant_land.lerp(foreground.lightened(0.14), 0.45)
			elif v >= field:
				color = foreground

			var tree_a := absf(u - 0.14)
			var tree_b := absf(u - 0.86)
			if (tree_a < 0.11 and v > 0.43 + tree_a * 0.8 and v < 0.70) or (tree_b < 0.10 and v > 0.45 + tree_b * 0.7 and v < 0.72):
				color = foreground.darkened(0.12)
			if ((tree_a < 0.018 and v > 0.55 and v < 0.77) or (tree_b < 0.016 and v > 0.56 and v < 0.78)):
				color = Color8(75, 55, 42)

			var house_center := 0.40 if variant % 2 == 0 else 0.61
			var house_dx := absf(u - house_center)
			if house_dx < 0.105 and v > 0.56 and v < 0.75:
				color = Color8(150, 105, 67)
			var roof_limit := 0.50 + house_dx * 0.75
			if house_dx < 0.12 and v > roof_limit and v < 0.60:
				color = Color8(76, 61, 49)
			if house_dx < 0.018 and v > 0.62 and v < 0.73:
				color = Color8(221, 189, 130)

			var river_center := 0.75 + 0.05 * sin(u * TAU * 1.2 + phase)
			if v > river_center - 0.018 and v < river_center + 0.018:
				color = Color8(104, 128, 129)
			var grain := sin(float(x) * 0.47 + float(y) * 0.31 + phase * 12.0) * 0.018
			color = Color(clampf(color.r + grain, 0.0, 1.0), clampf(color.g + grain, 0.0, 1.0), clampf(color.b + grain, 0.0, 1.0), 1.0)
			image.set_pixel(x, y, color)

	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return material


func _add_wall_sconces(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var side_yaw := PI * 0.5 if side < 0.0 else -PI * 0.5
		_add_wall_sconce(parent, "SideSconce_%s" % str(side), Vector3(side * WALL_PLANE, 2.43, 0.0), side_yaw)
		_add_wall_sconce(parent, "RearSconce_%s" % str(side), Vector3(side * 3.2, 2.43, -WALL_PLANE), 0.0)
		_add_wall_sconce(parent, "EntrySconce_%s" % str(side), Vector3(side * 1.55, 2.43, WALL_PLANE), PI)


func _add_wall_sconce(parent: Node3D, node_name: String, position: Vector3, wall_yaw: float) -> void:
	var sconce := Node3D.new()
	sconce.name = node_name
	sconce.position = position
	sconce.rotation.y = wall_yaw
	parent.add_child(sconce)

	var brass := _material("sconce_brass", Color8(173, 126, 51), 0.31, 0.52)
	var pale_brass := _material("sconce_highlight", Color8(211, 170, 91), 0.27, 0.48)
	var ivory := _material("sconce_ivory", Color8(235, 219, 178), 0.46)
	var flame_color := _material("sconce_flame", Color8(247, 184, 88), 0.36)
	_add_box(sconce, "WallPlate", Vector3(0.18, 0.28, 0.055), Vector3(0.0, 0.0, 0.035), brass)
	_add_box(sconce, "CurvedArmBase", Vector3(0.055, 0.055, 0.18), Vector3(0.0, -0.045, 0.13), pale_brass)
	_add_box(sconce, "CandleCup", Vector3(0.11, 0.035, 0.09), Vector3(0.0, 0.025, 0.235), brass)
	_add_cylinder(sconce, "IvoryCandle", 0.025, 0.12, Vector3(0.0, 0.10, 0.235), ivory, 12)
	_add_sphere(sconce, "WarmFlame", 0.024, Vector3(0.0, 0.173, 0.235), flame_color)

	var light := OmniLight3D.new()
	light.name = "SconceGlow"
	light.position = Vector3(0.0, 0.17, 0.26)
	light.light_color = Color8(255, 215, 158)
	light.light_energy = 0.12
	light.omni_range = 2.8
	light.shadow_enabled = false
	sconce.add_child(light)


func _add_palms(parent: Node3D) -> void:
	_add_palm(parent, "RearWestKentiaPalm", Vector3(-3.2, FLOOR_TOP, -3.22), 0)
	_add_palm(parent, "RearEastKentiaPalm", Vector3(3.2, FLOOR_TOP, -3.22), 1)


func _add_palm(parent: Node3D, node_name: String, position: Vector3, variant: int) -> void:
	var plant := Node3D.new()
	plant.name = node_name
	plant.position = position
	parent.add_child(plant)

	var pot_body := _material("palm_pot_body", Color8(38, 58, 54), 0.26, 0.14)
	var pot_glaze := _material("palm_pot_glaze", Color8(54, 80, 73), 0.22, 0.20)
	var gold := _material("palm_pot_gold", Color8(174, 129, 53), 0.32, 0.45)
	var soil := _material("palm_soil", Color8(62, 46, 32), 1.0)
	_add_cylinder(plant, "PlanterBody", 0.19, 0.40, Vector3(0.0, 0.20, 0.0), pot_body, 20, 0.27)
	_add_cylinder(plant, "PlanterFoot", 0.18, 0.045, Vector3(0.0, 0.035, 0.0), gold, 20, 0.18)
	_add_cylinder(plant, "PlanterLip", 0.27, 0.055, Vector3(0.0, 0.405, 0.0), gold, 20, 0.25)
	_add_cylinder(plant, "PlanterGlazeBand", 0.257, 0.035, Vector3(0.0, 0.30, 0.0), pot_glaze, 20, 0.246)
	_add_cylinder(plant, "VisibleSoil", 0.235, 0.018, Vector3(0.0, 0.432, 0.0), soil, 20)
	_add_cylinder(plant, "PalmStem", 0.035, 0.76, Vector3(0.0, 0.81, 0.0), _material("palm_stem", Color8(91, 67, 43), 0.82), 10, 0.025)

	var leaves := [
		_material("palm_leaf_1", Color8(41, 89, 58), 0.92),
		_material("palm_leaf_2", Color8(52, 105, 65), 0.90),
		_material("palm_leaf_3", Color8(61, 112, 71), 0.90)
	]
	var angle_offset := float(variant) * 0.34
	for leaf_index in range(11):
		var angle := TAU * float(leaf_index) / 11.0 + angle_offset
		var length := 0.78 + float((leaf_index + variant) % 3) * 0.075
		var leaf_instance := MeshInstance3D.new()
		leaf_instance.name = "PalmFrond_%02d" % leaf_index
		leaf_instance.mesh = _palm_leaf_mesh(angle, length, 0.15)
		leaf_instance.material_override = leaves[leaf_index % leaves.size()]
		plant.add_child(leaf_instance)

	for leaf_index in range(5):
		var angle := TAU * float(leaf_index) / 5.0 + angle_offset + 0.25
		var shoot := MeshInstance3D.new()
		shoot.name = "YoungFrond_%02d" % leaf_index
		shoot.mesh = _palm_leaf_mesh(angle, 0.60, 0.09)
		shoot.material_override = leaves[(leaf_index + 1) % leaves.size()]
		plant.add_child(shoot)


func _palm_leaf_mesh(angle: float, length: float, width: float) -> ArrayMesh:
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	var across := Vector3(-direction.z, 0.0, direction.x)
	var start := Vector3(0.0, 1.04, 0.0)
	var middle := direction * (length * 0.52) + Vector3(0.0, 0.10, 0.0)
	var tip := direction * length + Vector3(0.0, -0.28, 0.0)
	var left := middle - across * width * 0.5
	var right := middle + across * width * 0.5
	var normal := (left - start).cross(tip - start).normalized()
	var vertices := PackedVector3Array([start, left, tip, start, tip, right])
	var normals := PackedVector3Array([normal, normal, normal, normal, normal, normal])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_archive_books(parent: Node3D) -> void:
	var books := Node3D.new()
	books.name = "DrawerTopBoundVolumes"
	books.position = Vector3(-3.55, 1.20, -0.26)
	books.rotation.y = -PI * 0.5
	parent.add_child(books)

	var leather_a := _material("book_oxblood", Color8(73, 29, 33), 0.72)
	var leather_b := _material("book_green", Color8(35, 61, 49), 0.76)
	var leather_c := _material("book_navy", Color8(34, 47, 59), 0.75)
	var pages := _material("book_pages", Color8(210, 190, 151), 0.93)
	var gilt := _material("book_gilt", Color8(184, 141, 66), 0.38, 0.38)
	var book_colors := [leather_a, leather_b, leather_c]
	for index in range(3):
		var height := 0.055 + float(index % 2) * 0.008
		var book := _add_box(
			books,
			"LeatherVolume_%02d" % index,
			Vector3(0.38 - float(index) * 0.025, height, 0.26 - float(index) * 0.012),
			Vector3(float(index % 2) * 0.025, 0.035 + float(index) * 0.057, -float(index % 2) * 0.018),
			book_colors[index]
		)
		_add_box(books, "PageBlock_%02d" % index, Vector3(0.34 - float(index) * 0.025, height * 0.55, 0.225 - float(index) * 0.01), Vector3(float(index % 2) * 0.025, 0.035 + float(index) * 0.057, 0.0), pages)
		for gilt_line in [-1.0, 1.0]:
			_add_box(books, "GiltSpine_%02d_%s" % [index, str(gilt_line)], Vector3(0.012, height * 0.70, 0.005), Vector3(gilt_line * (0.16 - float(index) * 0.01), 0.035 + float(index) * 0.057, -0.133 + float(index) * 0.006), gilt)
		book.rotation.z = PI * 0.004 * float(index % 2)

	var inkwell := _material("inkwell_ebony", Color8(34, 38, 34), 0.23, 0.26)
	var brass := _material("inkwell_brass", Color8(165, 122, 53), 0.27, 0.48)
	_add_cylinder(books, "InkBottle", 0.042, 0.075, Vector3(0.27, 0.04, 0.105), inkwell, 14, 0.032)
	_add_cylinder(books, "InkBottleLip", 0.026, 0.018, Vector3(0.27, 0.086, 0.105), brass, 14)
	_add_box(books, "FoldedDocument", Vector3(0.34, 0.012, 0.24), Vector3(-0.23, 0.018, 0.16), _material("drawer_paper", Color8(216, 199, 158), 0.92))


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, bottom_radius: float, height: float, position: Vector3, material: StandardMaterial3D, radial_segments: int = 16, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = bottom_radius if top_radius < 0.0 else top_radius
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


func _material(key: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = material
	return material
