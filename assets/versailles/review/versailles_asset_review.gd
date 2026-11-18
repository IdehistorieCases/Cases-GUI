extends Node3D

## Temporary comparison gallery for the Versailles room asset shortlist.
## All model inputs are review copies; the final room uses only assets admitted
## to assets/versailles/optimized after the license and style review.

const COLUMNS := 4
const CELL_X := 2.75
const CELL_Z := 2.35
const TARGET_MODEL_SIZE := 1.25

const MODELS := [
	{"name": "Round Wooden Table 01", "source": "Poly Haven", "path": "res://source/polyhaven/round_wooden_table_01/round_wooden_table_01_2k.gltf"},
	{"name": "Green Chair 01", "source": "Poly Haven", "path": "res://source/polyhaven/GreenChair_01/GreenChair_01_2k.gltf"},
	{"name": "Vintage Cabinet 01", "source": "Poly Haven", "path": "res://source/polyhaven/vintage_cabinet_01/vintage_cabinet_01_2k.gltf"},
	{"name": "Lantern Chandelier 01", "source": "Poly Haven", "path": "res://source/polyhaven/lantern_chandelier_01/lantern_chandelier_01_2k.gltf"},
	{"name": "Arm Chair 01", "source": "Poly Haven", "path": "res://source/polyhaven/ArmChair_01/ArmChair_01_2k.gltf"},
	{"name": "Vintage Wooden Drawer 01", "source": "Poly Haven", "path": "res://source/polyhaven/vintage_wooden_drawer_01/vintage_wooden_drawer_01_2k.gltf"},
	{"name": "Fancy Picture Frame 01", "source": "Poly Haven", "path": "res://source/polyhaven/fancy_picture_frame_01/fancy_picture_frame_01_2k.gltf"},
	{"name": "Stationery Supplies", "source": "Poly Haven", "path": "res://source/polyhaven/stationery_supplies/stationery_supplies_2k.gltf"},
	{"name": "Kenney Round Table", "source": "Kenney sample", "path": "res://review/source_samples/kenney/tableRound.glb"},
	{"name": "Kenney Chair", "source": "Kenney sample", "path": "res://review/source_samples/kenney/chair.glb"},
	{"name": "Kenney Rounded Chair", "source": "Kenney sample", "path": "res://review/source_samples/kenney/chairRounded.glb"},
	{"name": "Kenney Lounge Chair", "source": "Kenney sample", "path": "res://review/source_samples/kenney/loungeDesignChair.glb"},
	{"name": "Kenney Doorway", "source": "Kenney sample", "path": "res://review/source_samples/kenney/doorway.glb"},
	{"name": "Kenney Window Wall", "source": "Kenney sample", "path": "res://review/source_samples/kenney/wallWindow.glb"},
	{"name": "Kenney Ceiling Lamp", "source": "Kenney sample", "path": "res://review/source_samples/kenney/lampSquareCeiling.glb"},
	{"name": "Kenney Bookcase", "source": "Kenney sample", "path": "res://review/source_samples/kenney/bookcaseClosedDoors.glb"},
	{"name": "Quaternius Large Round Table", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Table_RoundLarge.fbx"},
	{"name": "Quaternius Chair 1", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Chair_1.fbx"},
	{"name": "Quaternius Chair 2", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Chair_2.fbx"},
	{"name": "Quaternius Chandelier", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Light_Chandelier.fbx"},
	{"name": "Quaternius Curtains", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Curtains_Double.fbx"},
	{"name": "Quaternius Window", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Window_Large1.fbx"},
	{"name": "Quaternius Bookshelf", "source": "Quaternius sample", "path": "res://source/quaternius/fbx/Bookshelf.fbx"},
]

const BLOCKED := [
	{"name": "Classic Modular Walls & Ceiling", "source": "Sketchfab download unavailable through review route"},
	{"name": "3D Flag Pack", "source": "Official page rate limited; modern flags unsuitable for 1919"},
	{"name": "Curtains / Window Drapes", "source": "Sketchfab download unavailable through review route"},
	{"name": "Antique Globe", "source": "Sketchfab download unavailable through review route"},
	{"name": "1800s Book Stands", "source": "Sketchfab download unavailable through review route"},
	{"name": "Quill, Parchment & Inkwell", "source": "Sketchfab download unavailable through review route"},
	{"name": "Victorian Typewriter", "source": "Sketchfab download unavailable through review route"},
]

const MATERIALS := [
	{"name": "Dark Paneled Wood", "path": "res://source/polyhaven/dark_paneled_wood/textures/dark_paneled_wood_diff_2k.jpg"},
	{"name": "Diagonal Parquet", "path": "res://source/polyhaven/diagonal_parquet/textures/diagonal_parquet_diff_2k.jpg"},
]

func _ready() -> void:
	_build_lighting()
	var item_count := MODELS.size() + BLOCKED.size() + MATERIALS.size()
	var rows := int(ceil(float(item_count) / float(COLUMNS)))
	_build_floor(rows)
	for index in range(item_count):
		var cell := _cell_position(index)
		_add_stage(cell)
		if index < MODELS.size():
			_add_model(MODELS[index], cell)
		elif index < MODELS.size() + BLOCKED.size():
			_add_blocked(BLOCKED[index - MODELS.size()], cell)
		else:
			_add_material(MATERIALS[index - MODELS.size() - BLOCKED.size()], cell)
	print("Versailles asset review: %d models, %d blocked candidates, %d surface swatches." % [MODELS.size(), BLOCKED.size(), MATERIALS.size()])

func _cell_position(index: int) -> Vector3:
	var column := index % COLUMNS
	var row := int(index / COLUMNS)
	var rows := int(ceil(float(MODELS.size() + BLOCKED.size() + MATERIALS.size()) / float(COLUMNS)))
	var center_x := (float(COLUMNS - 1) * CELL_X) * 0.5
	var center_z := (float(rows - 1) * CELL_Z) * 0.5
	return Vector3(float(column) * CELL_X - center_x, 0.0, float(row) * CELL_Z - center_z)

func _build_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d8d5cc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d8")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff2d9")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.name = "AssetReviewCamera"
	camera.position = Vector3(0.0, 14.0, 18.5)
	camera.fov = 48.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, -3.1), Vector3.UP)

func _build_floor(rows: int) -> void:
	var floor := MeshInstance3D.new()
	floor.name = "NeutralReviewFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.5, float(rows) * CELL_Z + 2.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e5e0d5")
	material.roughness = 0.95
	plane.material = material
	floor.mesh = plane
	floor.position = Vector3(0.0, -0.05, -3.1)
	add_child(floor)

func _add_stage(cell: Vector3) -> void:
	var stage := MeshInstance3D.new()
	stage.name = "ComparisonStage"
	var box := BoxMesh.new()
	box.size = Vector3(2.35, 0.06, 1.92)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c8c1b5")
	material.roughness = 0.92
	box.material = material
	stage.mesh = box
	stage.position = cell + Vector3(0.0, -0.02, 0.0)
	add_child(stage)

func _add_model(item: Dictionary, cell: Vector3) -> void:
	var packed := load(item.path) as PackedScene
	if packed == null:
		push_error("Asset review could not load: " + item.path)
		_add_label(item.name + "\nIMPORT ERROR", cell + Vector3(0.0, 0.18, 0.82), Color("8b1616"))
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("Asset review root is not Node3D: " + item.path)
		return
	instance.name = item.name.replace(" ", "")
	add_child(instance)
	var info := _measure(instance)
	var scale_factor: float = TARGET_MODEL_SIZE / max(max(info.size.x, info.size.y), info.size.z)
	instance.scale *= scale_factor
	instance.position = Vector3(
		cell.x - info.center.x * scale_factor,
		cell.y - info.minimum.y * scale_factor + 0.01,
		cell.z - info.center.z * scale_factor
	)
	_add_label(item.name + "\n" + item.source, cell + Vector3(0.0, 0.18, 0.82), Color("27231e"))
	print("ASSET_METRIC | %s | bounds=%.3fx%.3fx%.3f m | pivot_to_center=(%.3f,%.3f,%.3f) | mesh_nodes=%d | surfaces=%d | triangles=%d | missing_uv=%d | missing_normals=%d | transparent_surfaces=%d | textures=%s" % [item.name, info.size.x, info.size.y, info.size.z, info.center.x, info.center.y, info.center.z, info.mesh_nodes, info.surfaces, info.triangles, info.missing_uv_surfaces, info.missing_normal_surfaces, info.transparent_surfaces, ",".join(info.texture_sizes)])

func _measure(root: Node3D) -> Dictionary:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var mesh_nodes := 0
	var surfaces := 0
	var triangles := 0
	var missing_uv_surfaces := 0
	var missing_normal_surfaces := 0
	var transparent_surfaces := 0
	var texture_sizes := PackedStringArray()
	var inverse := root.global_transform.affine_inverse()
	var nodes := [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		for child in node.get_children():
			nodes.append(child)
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		mesh_nodes += 1
		var local_to_root := inverse * mesh_node.global_transform
		var bounds := mesh_node.mesh.get_aabb()
		for corner_index in range(8):
			var corner := bounds.get_endpoint(corner_index)
			var point := local_to_root * corner
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		for surface_index in range(mesh_node.mesh.get_surface_count()):
			surfaces += 1
			var arrays := mesh_node.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			if uvs == null or uvs.is_empty():
				missing_uv_surfaces += 1
			if normals == null or normals.is_empty():
				missing_normal_surfaces += 1
			var element_count := indices.size() if not indices.is_empty() else vertices.size()
			triangles += int(element_count / 3)
			var surface_material := mesh_node.get_active_material(surface_index)
			if surface_material is BaseMaterial3D:
				var base := surface_material as BaseMaterial3D
				if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.albedo_color.a < 0.99:
					transparent_surfaces += 1
				for texture in [base.albedo_texture, base.normal_texture, base.roughness_texture, base.metallic_texture, base.ao_texture]:
					if texture is Texture2D:
						var size := "%dx%d" % [texture.get_width(), texture.get_height()]
						if not texture_sizes.has(size):
							texture_sizes.append(size)
	var final_size := maximum - minimum
	return {"minimum": minimum, "center": (maximum + minimum) * 0.5, "size": final_size, "mesh_nodes": mesh_nodes, "surfaces": surfaces, "triangles": triangles, "missing_uv_surfaces": missing_uv_surfaces, "missing_normal_surfaces": missing_normal_surfaces, "transparent_surfaces": transparent_surfaces, "texture_sizes": texture_sizes}

func _add_blocked(item: Dictionary, cell: Vector3) -> void:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.5, 0.65)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("99938b")
	box.material = material
	slab.mesh = box
	slab.position = cell + Vector3(0.0, 0.28, 0.0)
	add_child(slab)
	_add_label(item.name + "\nBLOCKED / REJECTED", cell + Vector3(0.0, 0.18, 0.82), Color("5b1717"))

func _add_material(item: Dictionary, cell: Vector3) -> void:
	var texture := load(item.path) as Texture2D
	var swatch := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.05, 0.09, 1.05)
	var material := StandardMaterial3D.new()
	material.roughness = 0.85
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(2.0, 2.0, 1.0)
	material.albedo_texture = texture
	box.material = material
	swatch.mesh = box
	swatch.position = cell + Vector3(0.0, 0.1, 0.0)
	add_child(swatch)
	_add_label(item.name + "\nPoly Haven texture", cell + Vector3(0.0, 0.18, 0.82), Color("27231e"))
	if texture != null:
		print("ASSET_TEXTURE | %s | %dx%d" % [item.name, texture.get_width(), texture.get_height()])

func _add_label(text_value: String, label_position: Vector3, label_color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = label_position
	label.font_size = 44
	label.pixel_size = 0.004
	label.modulate = label_color
	label.outline_size = 6
	label.outline_modulate = Color("ffffff")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

