extends CanvasLayer

signal minimap_ready

@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $SubViewportContainer/SubViewport/MinimapCamera
@onready var minimap_tilemap: TileMap = $SubViewportContainer/SubViewport/MinimapTileMap
@onready var minimap_root: Node2D = $SubViewportContainer/SubViewport/MinimapRoot
@onready var player_marker: Sprite2D = $SubViewportContainer/SubViewport/PlayerMarker

var player: Node2D = null
var tilemap_layers: Array = []
var scene_minimap_cache: Dictionary = {}
var pending_scene_path: String = ""
var _build_retry_attempts: int = 0
const _MAX_BUILD_ATTEMPTS: int = 10
const _RETRY_DELAY_SEC: float = 0.1
const EXTERIOR_PATHS := [
	"res://scenes/environments/exterior/apartment_morgue.tscn",
	"res://scenes/environments/exterior/baranggay_court.tscn",
	"res://scenes/environments/exterior/camp.tscn",
	"res://scenes/environments/exterior/hotel_hospital.tscn",
	"res://scenes/environments/exterior/police_station.tscn",
	"res://scenes/environments/exterior/terminal_market.tscn",
]


func _ready() -> void:
	await get_tree().process_frame  # wait one frame so children exist
	viewport_container = $SubViewportContainer
	viewport = $SubViewportContainer/SubViewport
	minimap_camera = $SubViewportContainer/SubViewport/MinimapCamera
	minimap_tilemap = $SubViewportContainer/SubViewport/MinimapTileMap

	if viewport == null or minimap_camera == null or minimap_tilemap == null or minimap_root == null:
		push_error("⚠️ Minimap: Could not find one or more child nodes! Check node paths.")
		return

	print("🗺️ Minimap ready (autoload expected).")

	if viewport.size == Vector2i.ZERO:
		viewport.size = Vector2i(256, 256)

	# Ensure the SubViewport renders every frame and the camera is active
	if viewport.has_method("set_update_mode"):
		# Safety: older API guard; not expected in 4.4
		viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera.has_method("make_current"):
		minimap_camera.make_current()
	elif "enabled" in minimap_camera:
		minimap_camera.enabled = true

	minimap_camera.zoom = Vector2(0.3, 0.3)
	visible = true

	# Offline prebake: prebuild cached minimaps for exterior scenes at startup
	_prebake_minimaps()

	# Fallbacks: try to auto-bind player and tilemap layers if not set externally
	if player == null:
		var found_players := get_tree().get_nodes_in_group("player")
		if not found_players.is_empty():
			var candidate: Node = found_players[0]
			if candidate is Node2D:
				set_player(candidate)
		else:
			# Try common node names
			var root := get_tree().current_scene
			if root != null:
				var maybe_player := root.find_child("Player", true, false)
				if maybe_player != null and maybe_player is Node2D:
					set_player(maybe_player)
				else:
					# Broader heuristic: first Node2D whose name contains "player"
					for n in root.get_children():
						if n is Node2D and String(n.name).to_lower().contains("player"):
							set_player(n)
							break

	if tilemap_layers.is_empty():
		var root2 := get_tree().current_scene
		if root2 != null:
			var found_layers := root2.get_children()
			var collected: Array = []
			# Deep search for TileMapLayer nodes
			for node in root2.find_children("*", "TileMapLayer", true, false):
				collected.append(node)
			if not collected.is_empty():
				set_tilemap_layers(collected)

	# If we have data now, initialize immediately
	if not tilemap_layers.is_empty():
		_copy_tilemap_layers()
	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos

	# React to scene changes so minimap updates when entering new scenes
	var tree := get_tree()
	if tree != null:
		if tree.has_signal("current_scene_changed"):
			tree.connect("current_scene_changed", Callable(self, "_on_current_scene_changed"))
		elif tree.has_signal("scene_changed"):
			tree.connect("scene_changed", Callable(self, "_on_current_scene_changed"))


func _on_current_scene_changed(_new_scene: Node) -> void:
	# Clear immediately so old map is not shown during transitions
	_clear_minimap()
	print("[Minimap] current_scene_changed: cleared minimap")

	# Re-apply viewport/camera settings to avoid stale state across scenes
	if viewport != null:
		if viewport.has_method("set_update_mode"):
			viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera != null:
		if minimap_camera.has_method("make_current"):
			minimap_camera.make_current()
		elif "enabled" in minimap_camera:
			minimap_camera.enabled = true
	visible = true

	# Try to scan and build immediately for instant visual update
	# First, try to use cache for the newly current scene
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root != null:
		var key := _find_cached_scene_key(root)
		if key != "" and scene_minimap_cache.has(key):
			print("[Minimap] Using cached minimap for:", key)
			_use_cached_minimap(key)
			_resolve_player()
			if player != null:
				minimap_camera.global_position = player.global_position
		else:
			print("[Minimap] No cache for:", key, " -> scanning")
			_scan_and_build()
	else:
		_scan_and_build()

	# Also rebuild next frame to capture any late-instanced nodes
	if get_tree() != null:
		await get_tree().process_frame
	_scan_and_build()
	if minimap_root.get_child_count() > 0:
		emit_signal("minimap_ready")


func _on_transition_start() -> void:
	# Public hook: called by scene_transition.gd before changing scenes
	_clear_minimap()


func _on_transition_complete(_target_scene_path: String = "") -> void:
	# Called after scene change has been kicked off; wait for new scene to be current and ready
	pending_scene_path = String(_target_scene_path)
	print("[Minimap] transition_complete: target_path=", pending_scene_path)
	if get_tree() != null:
		await get_tree().process_frame
		await get_tree().process_frame
	# Prefer cache for the known target if available
	var tree2 := get_tree()
	if tree2 == null:
		return
	var root2 := tree2.current_scene
	if root2 != null:
		var key2 := _find_cached_scene_key(root2)
		if key2 != "" and scene_minimap_cache.has(key2):
			print("[Minimap] Using cached minimap after transition for:", key2)
			_use_cached_minimap(key2)
			_resolve_player()
			if player != null:
				minimap_camera.global_position = player.global_position
				if player_marker != null:
					player_marker.global_position = player.global_position
			emit_signal("minimap_ready")
			return
	print("[Minimap] No cache after transition -> scanning/building")
	_scan_and_build()
	if minimap_root.get_child_count() > 0:
		emit_signal("minimap_ready")

	# Kick off retry loop if nothing built
	if minimap_root.get_child_count() == 0:
		_build_retry_attempts = 0
		_retry_build_loop()


func _scan_and_build() -> void:
	# Re-scan for player and layers, then rebuild minimap
	player = null
	var tree := get_tree()
	if tree == null:
		_clear_minimap()
		return
	var root := tree.current_scene

	# If no scene yet, clear and bail
	if root == null:
		_clear_minimap()
		return
	if root != null:
		# If we have a cached minimap for this scene, use it immediately
		var key := _find_cached_scene_key(root)
		if key != "" and scene_minimap_cache.has(key):
			print("[Minimap] scan: using cached minimap for:", key)
			_use_cached_minimap(key)
			# Still try to acquire player for camera centering
			var found_cached_player := tree.get_nodes_in_group("player")
			if not found_cached_player.is_empty() and found_cached_player[0] is Node2D:
				player = found_cached_player[0]
			if player != null:
				minimap_camera.global_position = player.global_position
			return

		var found_players := tree.get_nodes_in_group("player")
		if not found_players.is_empty() and found_players[0] is Node2D:
			player = found_players[0]
		else:
			var maybe_player := root.find_child("Player", true, false)
			if maybe_player != null and maybe_player is Node2D:
				player = maybe_player
			else:
				# Common alternate name in this project
				var maybe_player_m := root.find_child("PlayerM", true, false)
				if maybe_player_m != null and maybe_player_m is Node2D:
					player = maybe_player_m
				else:
					for n in root.get_children():
						if n is Node2D and String(n.name).to_lower().contains("player"):
							player = n
							break

	tilemap_layers.clear()
	if root != null:
		for node in root.find_children("*", "TileMapLayer", true, false):
			if node != null and node is TileMapLayer:
				tilemap_layers.append(node)

	if not tilemap_layers.is_empty():
		_copy_tilemap_layers()
		# Cache the built minimap for this scene for instant reuse later
		var save_key := _get_scene_cache_key(root)
		_cache_current_minimap(save_key)
		print("[Minimap] built and cached minimap for:", save_key)
		# If no player, center camera on map bounds
		if player == null:
			var bounds := _compute_map_bounds()
			if bounds.has_area():
				var center := bounds.get_center()
				minimap_camera.global_position = _clamp_camera_to_bounds(center)
	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos
	if minimap_root.get_child_count() > 0:
		emit_signal("minimap_ready")


func _retry_build_loop() -> void:
	if _build_retry_attempts >= _MAX_BUILD_ATTEMPTS:
		print("[Minimap] retry stopped: max attempts reached")
		return
	_build_retry_attempts += 1
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(_RETRY_DELAY_SEC).timeout.connect(func():
		if not is_instance_valid(self):
			return
		# If already built (children exist), stop
		if minimap_root.get_child_count() > 0:
			print("[Minimap] retry success on attempt", _build_retry_attempts)
			emit_signal("minimap_ready")
			return
		print("[Minimap] retry attempt", _build_retry_attempts)
		_scan_and_build()
		if minimap_root.get_child_count() == 0:
			_retry_build_loop()
	)


func _compute_map_bounds() -> Rect2:
	var has_any := false
	var min_pos := Vector2(1e9, 1e9)
	var max_pos := Vector2(-1e9, -1e9)
	for src_layer in tilemap_layers:
		if src_layer == null:
			continue
		var used_cells := []
		if src_layer.has_method("get_used_cells"):
			used_cells = src_layer.get_used_cells()
		for cell in used_cells:
			if cell is Vector2i:
				var local: Vector2 = src_layer.map_to_local(cell)
				var world: Vector2 = src_layer.to_global(local)
				min_pos.x = min(min_pos.x, world.x)
				min_pos.y = min(min_pos.y, world.y)
				max_pos.x = max(max_pos.x, world.x)
				max_pos.y = max(max_pos.y, world.y)
				has_any = true
	if not has_any:
		return Rect2()
	return Rect2(min_pos, max_pos - min_pos)


func _cache_current_minimap(scene_path: String) -> void:
	if scene_path.is_empty():
		print("[Minimap] cache skipped: empty scene_path")
		return
	# Create a temporary root and duplicate current minimap layers under it
	var temp_root := Node2D.new()
	for c in minimap_root.get_children():
		var dup := c.duplicate()
		if dup != null:
			temp_root.add_child(dup)
			dup.owner = temp_root
	var packed := PackedScene.new()
	var ok := packed.pack(temp_root)
	if ok == OK:
		scene_minimap_cache[scene_path] = packed
		print("[Minimap] cache stored for:", scene_path)
	else:
		print("[Minimap] cache pack FAILED for:", scene_path)
	# Cleanup temp container (its children will be freed with it)
	temp_root.queue_free()
	# Clear pending target once cached
	pending_scene_path = ""


func _use_cached_minimap(scene_path: String) -> void:
	if not scene_minimap_cache.has(scene_path):
		print("[Minimap] use_cache skipped: no entry for:", scene_path)
		return
	_clear_minimap()
	var inst := (scene_minimap_cache[scene_path] as PackedScene).instantiate()
	if inst == null:
		print("[Minimap] use_cache FAILED: instantiate returned null for:", scene_path)
		return
	# Move children from the instantiated container into minimap_root
	for c in inst.get_children():
		inst.remove_child(c)
		minimap_root.add_child(c)
	inst.queue_free()
	# Using cache consumed pending path
	pending_scene_path = ""

	# Ensure viewport/camera and visibility
	if viewport != null:
		if viewport.has_method("set_update_mode"):
			viewport.set_update_mode(SubViewport.UPDATE_ALWAYS)
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if minimap_camera != null:
		if minimap_camera.has_method("make_current"):
			minimap_camera.make_current()
		elif "enabled" in minimap_camera:
			minimap_camera.enabled = true
	visible = true

	# Position camera: follow player if available, else center on bounds (from cached layers)
	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos
		if player_marker != null:
			player_marker.global_position = player.global_position
	else:
		var bounds := _compute_cached_minimap_bounds()
		if bounds.has_area():
			var center := bounds.get_center()
			minimap_camera.global_position = _clamp_camera_to_bounds(center)
		else:
			print("[Minimap] use_cache: empty bounds after instancing for:", scene_path)
	# Signal readiness
	emit_signal("minimap_ready")


func _resolve_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene
	player = null
	var found_players := tree.get_nodes_in_group("player")
	if not found_players.is_empty() and found_players[0] is Node2D:
		player = found_players[0]
		return
	if root != null:
		var maybe_player := root.find_child("Player", true, false)
		if maybe_player != null and maybe_player is Node2D:
			player = maybe_player
			return
		var maybe_player_m := root.find_child("PlayerM", true, false)
		if maybe_player_m != null and maybe_player_m is Node2D:
			player = maybe_player_m
			return
		for n in root.get_children():
			if n is Node2D and String(n.name).to_lower().contains("player"):
				player = n
				return


func _compute_cached_minimap_bounds() -> Rect2:
	# Compute bounds from the duplicated TileMapLayers under minimap_root
	var has_any := false
	var min_pos := Vector2(1e9, 1e9)
	var max_pos := Vector2(-1e9, -1e9)
	for child in minimap_root.get_children():
		if child is TileMapLayer:
			var used := []
			if child.has_method("get_used_cells"):
				used = child.get_used_cells()
			for cell in used:
				if cell is Vector2i:
					var local: Vector2 = child.map_to_local(cell)
					var world: Vector2 = child.to_global(local)
					min_pos.x = min(min_pos.x, world.x)
					min_pos.y = min(min_pos.y, world.y)
					max_pos.x = max(max_pos.x, world.x)
					max_pos.y = max(max_pos.y, world.y)
					has_any = true
	if not has_any:
		return Rect2()
	return Rect2(min_pos, max_pos - min_pos)


func _get_scene_cache_key(root_scene: Node) -> String:
	# Prefer the scene's file path when available (most stable).
	# If not available (e.g., change_scene_to_packed), use the pending transition target.
	# Finally, fall back to the scene's name.
	var path := ""
	if root_scene != null and "scene_file_path" in root_scene:
		path = String(root_scene.scene_file_path)
	if not path.is_empty():
		return path
	if pending_scene_path != null and not String(pending_scene_path).is_empty():
		return String(pending_scene_path)
	return String(root_scene.name)


func _find_cached_scene_key(root_scene: Node) -> String:
	# Try multiple identifiers to find an existing cache entry
	if root_scene == null:
		return ""
	var file_path := ""
	if "scene_file_path" in root_scene:
		file_path = String(root_scene.scene_file_path)
	if not file_path.is_empty():
		var canon := _normalize_exterior_path(file_path)
		if scene_minimap_cache.has(file_path):
			return file_path
		if canon != "" and scene_minimap_cache.has(canon):
			return canon
	if pending_scene_path != null and not String(pending_scene_path).is_empty():
		var pend := String(pending_scene_path)
		var pcanon := _normalize_exterior_path(pend)
		if scene_minimap_cache.has(pend):
			return pend
		if pcanon != "" and scene_minimap_cache.has(pcanon):
			return pcanon
	# Match by scene file basename against known exterior paths
	var base := String(root_scene.name)
	for p in EXTERIOR_PATHS:
		var fname := String(p).get_file().get_basename()
		if fname == base:
			if scene_minimap_cache.has(p):
				return p
	return ""


func _normalize_exterior_path(path: String) -> String:
	# Map any incoming path to its canonical EXTERIOR_PATHS entry by basename
	if path.is_empty():
		return ""
	var basename := String(path).get_file().get_basename()
	for p in EXTERIOR_PATHS:
		if String(p).get_file().get_basename() == basename:
			return p
	return ""


# ----------------------
# Offline Prebake Helpers
# ----------------------
func _prebake_minimaps() -> void:
	for p in EXTERIOR_PATHS:
		if not scene_minimap_cache.has(p):
			_prebuild_minimap_for_scene_path(p)


func _prebuild_minimap_for_scene_path(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var res := ResourceLoader.load(scene_path)
	if res == null or not (res is PackedScene):
		return
	var inst := (res as PackedScene).instantiate()
	if inst == null:
		return
	# Collect TileMapLayer nodes
	var layers: Array = []
	for node in inst.find_children("*", "TileMapLayer", true, false):
		layers.append(node)
	# Build a lightweight minimap subtree
	var temp_root := Node2D.new()
	for src_layer in layers:
		if src_layer == null:
			continue
		var dst_layer := TileMapLayer.new()
		dst_layer.tile_set = src_layer.tile_set
		dst_layer.z_index = src_layer.z_index
		dst_layer.global_transform = src_layer.global_transform
		temp_root.add_child(dst_layer)
		dst_layer.owner = temp_root
		var used_cells := []
		if src_layer.has_method("get_used_cells"):
			used_cells = src_layer.get_used_cells()
		for cell in used_cells:
			if cell is Vector2i:
				var source_id = src_layer.get_cell_source_id(cell)
				var atlas_coords = src_layer.get_cell_atlas_coords(cell)
				dst_layer.set_cell(cell, source_id, atlas_coords)
	var packed := PackedScene.new()
	if packed.pack(temp_root) == OK:
		scene_minimap_cache[scene_path] = packed
	inst.free()
	temp_root.queue_free()

func is_ready() -> bool:
	return minimap_root != null and minimap_root.get_child_count() > 0


func _clear_minimap() -> void:
	# Remove any previously duplicated layers and clear the single TileMap
	for c in minimap_root.get_children():
		minimap_root.remove_child(c)
		c.queue_free()
	if minimap_tilemap != null:
		minimap_tilemap.clear()


func set_player(p: Node2D) -> void:
	if p == null:
		push_warning("Minimap.set_player called with null")
		return
	player = p
	print("🎯 Minimap: tracking player:", player)


func set_tilemap_layers(layers: Array) -> void:
	if layers == null or layers.is_empty():
		push_warning("Minimap.set_tilemap_layers called with empty array")
		return

	tilemap_layers.clear()
	for l in layers:
		if l != null and l is TileMapLayer:
			tilemap_layers.append(l)

	if tilemap_layers.is_empty():
		push_warning("Minimap: no valid TileMapLayer nodes found in provided list")
		return

	_copy_tilemap_layers()


func _copy_tilemap_layers() -> void:
	if tilemap_layers.is_empty():
		return

	# Clear any previous duplicates under minimap_root
	for c in minimap_root.get_children():
		minimap_root.remove_child(c)
		c.queue_free()

	var total_cells := 0

	for src_layer in tilemap_layers:
		if src_layer == null:
			continue

		# Duplicate a lightweight layer for the minimap so we can keep per-layer TileSets
		var dst_layer := TileMapLayer.new()
		dst_layer.tile_set = src_layer.tile_set
		dst_layer.z_index = src_layer.z_index
		minimap_root.add_child(dst_layer)

		# Align transforms to match the world
		dst_layer.global_transform = src_layer.global_transform

		var used_cells: Array = []
		if src_layer.has_method("get_used_cells"):
			used_cells = src_layer.get_used_cells()
		else:
			continue

		for cell in used_cells:
			if cell is Vector2i:
				var source_id = src_layer.get_cell_source_id(cell)
				var atlas_coords = src_layer.get_cell_atlas_coords(cell)
				dst_layer.set_cell(cell, source_id, atlas_coords)
				total_cells += 1

	print("✅ Minimap: copied", tilemap_layers.size(), "layers, total cells:", total_cells)


func _clamp_camera_to_bounds(target_pos: Vector2) -> Vector2:
	if minimap_camera == null or viewport == null:
		return target_pos
	
	# Get map bounds from cached layers or source layers
	var bounds := _compute_cached_minimap_bounds()
	if not bounds.has_area():
		bounds = _compute_map_bounds()
	
	if not bounds.has_area():
		# No bounds available, return target position unchanged
		return target_pos
	
	# Calculate viewport size in world coordinates
	var viewport_size := Vector2(viewport.size)
	var world_viewport_size := viewport_size / minimap_camera.zoom
	
	# Calculate the camera limits (bounds minus half viewport on each side)
	var half_viewport := world_viewport_size / 2.0
	var min_x := bounds.position.x + half_viewport.x
	var max_x := bounds.position.x + bounds.size.x - half_viewport.x
	var min_y := bounds.position.y + half_viewport.y
	var max_y := bounds.position.y + bounds.size.y - half_viewport.y
	
	# Clamp position
	var clamped_x: float = clamp(target_pos.x, min_x, max_x)
	var clamped_y: float = clamp(target_pos.y, min_y, max_y)
	
	return Vector2(clamped_x, clamped_y)


func _process(_delta: float) -> void:
	if player != null and minimap_camera != null:
		var target_pos := player.global_position
		# Clamp camera position to map bounds to avoid showing blank space
		var clamped_pos := _clamp_camera_to_bounds(target_pos)
		minimap_camera.global_position = clamped_pos
		if player_marker != null:
			player_marker.global_position = player.global_position


# 🆕 Implemented Update Method
func update_minimap() -> void:
	"""
	Call this method to refresh the minimap manually.
	It re-copies all the tilemap layers and ensures the minimap camera follows the latest data.
	"""
	if tilemap_layers.is_empty():
		push_warning("⚠️ Minimap.update_minimap() called but no tilemap layers are set.")
		return

	print("🔄 Minimap: updating...")
	_copy_tilemap_layers()

	if player != null:
		var clamped_pos := _clamp_camera_to_bounds(player.global_position)
		minimap_camera.global_position = clamped_pos

	print("✅ Minimap: update complete.")
